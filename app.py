from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
import json
import os

app = Flask(__name__)
CORS(app)

ARQUIVO_USUARIOS = "usuarios.json"

def carregar_usuarios():
    if os.path.exists(ARQUIVO_USUARIOS):
        with open(ARQUIVO_USUARIOS, "r") as f:
            return json.load(f)
    return {}

def salvar_usuarios(dados):
    with open(ARQUIVO_USUARIOS, "w") as f:
        json.dump(dados, f, indent=4)

@app.route('/cadastro', methods=['POST'])
def cadastro():
    dados = request.get_json()
    nome = dados.get("nome")
    email = dados.get("email")
    senha = dados.get("senha")

    if not nome or not email or not senha:
        return jsonify({"success": False, "message": "Todos os campos são obrigatórios."}), 400

    if len(nome) < 3 or len(nome) > 20:
        return jsonify({"success": False, "message": "Nome de usuário inválido (3 a 20 caracteres)."}), 400

    if len(senha) < 6 or len(senha) > 20:
        return jsonify({"success": False, "message": "Senha deve ter entre 6 e 20 caracteres!"}), 400

    usuarios = carregar_usuarios()

    if email in usuarios:
        return jsonify({"success": False, "message": "E-mail já cadastrado."}), 409

    for user in usuarios.values():
        if user["nome"].lower() == nome.lower():
            return jsonify({"success": False, "message": "Nome de usuário já existe!"}), 409

    senha_hash = generate_password_hash(senha)

    usuarios[email] = {
        "nome": nome,
        "senha_hash": senha_hash
    }

    salvar_usuarios(usuarios)

    return jsonify({"success": True, "message": "Cadastro realizado com sucesso!"}), 200

@app.route('/login', methods=['POST'])
def login():
    dados = request.get_json()
    email = dados.get('email')
    senha = dados.get('senha')

    if not email or not senha:
        return jsonify({"success": False, "message": "Campos obrigatórios."}), 400

    usuarios = carregar_usuarios()
    user = usuarios.get(email)

    if user and check_password_hash(user.get("senha_hash", ""), senha):
        return jsonify({"success": True, "message": "Login autorizado!"}), 200
    else:
        return jsonify({"success": False, "message": "E-mail ou senha inválidos."}), 401

if __name__ == '__main__':
    app.run(debug=True, port=3000)


@app.route('/recuperar', methods=['POST'])
def recuperar():
    dados = request.get_json()
    email = dados.get('email')

    if not email:
        return jsonify({"success": False, "message": "E-mail é obrigatório."}), 400

    usuarios = carregar_usuarios()

    if email not in usuarios:
        return jsonify({"success": False, "message": "E-mail não cadastrado."}), 404

    # testando, mas nao sei real
    codigo = "123456" 

    return jsonify({
        "success": True,
        "message": f"Código de recuperação enviado para {email}.",
        "codigo": codigo
    }), 200

