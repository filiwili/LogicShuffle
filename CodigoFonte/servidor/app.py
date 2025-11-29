import os
from datetime import datetime, timedelta, timezone
import secrets
import hashlib
import uuid
import traceback

from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from passlib.hash import sha256_crypt
from dotenv import load_dotenv
from pathlib import Path
from sqlalchemy import text

from models import db, User
from email_utils import send_password_reset_email

# --- Carregar .env ---
dotenv_path = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=dotenv_path)

# --- Flask App ---
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv("DATABASE_URL")
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = os.getenv("SECRET_KEY", "devsecret")
app.config['JWT_SECRET_KEY'] = os.getenv("JWT_SECRET_KEY", "devjwtsecret")
app.config['RESET_TOKEN_EXPIRATION_MINUTES'] = int(os.getenv("RESET_TOKEN_EXPIRATION_MINUTES", "60"))

db.init_app(app)
jwt = JWTManager(app)

# --- Helpers ---
def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()

def init_database():
    """Inicializa o banco com dados padrão se não existirem"""
    with app.app_context():
        # Criar tabelas se não existirem
        db.create_all()
        
        # Verificar se já existem jogos cadastrados
        existing_games = db.session.execute(
            text("SELECT COUNT(*) FROM games")
        ).fetchone()[0]
        
        if existing_games == 0:
            print("Inicializando dados do banco...")
            
            # Inserir jogo principal (Jogo 1)
            db.session.execute(
                text("""
                    INSERT INTO games (id, name, description) VALUES 
                    ('1', 'Jogo das Estruturas de Dados', 'Jogo educativo sobre filas, pilhas e deques'),
                    ('2', 'Jogo das Árvores Binárias', 'Jogo educativo sobre árvores binárias e BST')
                """)
            )
            
            # Inserir níveis do jogo 1 e jogo 2
            db.session.execute(
                text("""
                    INSERT INTO game_levels (id, game_id, name, order_number, difficulty) VALUES 
                    ('1', '1', 'nivel1', 1, 'Fácil'),
                    ('2', '1', 'nivel2', 2, 'Médio'),
                    ('3', '1', 'nivel3', 3, 'Difícil'),
                    ('4', '1', 'nivel4', 4, 'Fácil'),
                    ('5', '1', 'nivel5', 5, 'Médio'),
                    ('6', '1', 'nivel6', 6, 'Difícil'),
                    ('7', '1', 'nivel7', 7, 'Fácil'),
                    ('8', '1', 'nivel8', 8, 'Médio'),
                    ('9', '1', 'nivel9', 9, 'Difícil'),
                    ('10', '1', 'nivel10', 10, 'Fácil'),
                    ('11', '2', 'arvore_binaria_nivel1', 1, 'Fácil'),
                    ('12', '2', 'arvore_binaria_nivel2', 2, 'Médio'),
                    ('13', '2', 'arvore_binaria_nivel3', 3, 'Difícil'),
                    ('14', '2', 'arvore_binaria_nivel4', 4, 'Fácil'),
                    ('15', '2', 'arvore_binaria_nivel5', 5, 'Médio'),
                    ('16', '2', 'arvore_binaria_nivel6', 6, 'Difícil'),
                    ('17', '2', 'arvore_binaria_nivel7', 7, 'Fácil'),
                    ('18', '2', 'arvore_binaria_nivel8', 8, 'Médio'),
                    ('19', '2', 'arvore_binaria_nivel9', 9, 'Difícil'),
                    ('20', '2', 'arvore_binaria_nivel10', 10, 'Fácil')
                     ON CONFLICT (id) DO UPDATE SET
                     name = EXCLUDED.name,
                     order_number = EXCLUDED.order_number,
                      difficulty = EXCLUDED.difficulty
                """)
            )
            
            db.session.commit()
            print("Dados iniciais inseridos com sucesso!")
        else:
            # Verificar se o jogo 2 existe, se não, adicionar
            game2_exists = db.session.execute(
                text("SELECT COUNT(*) FROM games WHERE id = '2'")
            ).fetchone()[0]
            
            if not game2_exists:
                print("Adicionando Jogo 2 (Árvores Binárias)...")
                db.session.execute(
                    text("""
                        INSERT INTO games (id, name, description) VALUES 
                        ('2', 'Jogo das Árvores Binárias', 'Jogo educativo sobre árvores binárias e BST')
                    """)
                )
                
                # Adicionar níveis do jogo 2
                db.session.execute(
                    text("""
                        INSERT INTO game_levels (id, game_id, name, order_number, difficulty) VALUES 
                        ('11', '2', 'arvore_binaria_nivel1', 1, 'Fácil'),
                        ('12', '2', 'arvore_binaria_nivel2', 2, 'Médio'),
                        ('13', '2', 'arvore_binaria_nivel3', 3, 'Difícil'),
                        ('14', '2', 'arvore_binaria_nivel4', 4, 'Fácil'),
                        ('15', '2', 'arvore_binaria_nivel5', 5, 'Médio'),
                        ('16', '2', 'arvore_binaria_nivel6', 6, 'Difícil'),
                        ('17', '2', 'arvore_binaria_nivel7', 7, 'Fácil'),
                        ('18', '2', 'arvore_binaria_nivel8', 8, 'Médio'),
                        ('19', '2', 'arvore_binaria_nivel9', 9, 'Difícil'),
                        ('20', '2', 'arvore_binaria_nivel10', 10, 'Fácil')
                    """)
                )
                
                db.session.commit()
                print("Jogo 2 adicionado com sucesso!")

# --- Rotas de Autenticação ---
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(force=True)
    username = (data.get('username') or "").strip()
    email = (data.get('email') or "").strip().lower()
    password = data.get('password') or ""

    if not username or not email or not password:
        return jsonify({"msg": "username, email e password são obrigatórios"}), 400
    if User.query.filter_by(email=email).first():
        return jsonify({"msg": "Email já cadastrado"}), 400

    password_hash = sha256_crypt.hash(password)
    user = User(username=username, email=email, password_hash=password_hash)
    db.session.add(user)
    db.session.commit()

    access_token = create_access_token(identity=user.id)
    return jsonify({"msg": "Usuário criado", "user": user.to_dict(), "access_token": access_token}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json(force=True)
    email = (data.get('email') or "").strip().lower()
    password = data.get('password') or ""

    if not email or not password:
        return jsonify({"msg":"email e senha são obrigatórios"}), 400

    user = User.query.filter_by(email=email).first()
    if not user or not sha256_crypt.verify(password, user.password_hash):
        return jsonify({"msg":"Credenciais inválidas"}), 401

    access_token = create_access_token(identity=user.id)
    return jsonify({"msg":"Login bem sucedido","user":user.to_dict(),"access_token":access_token})

@app.route('/forgot-password', methods=['POST'])
def forgot_password():
    data = request.get_json(force=True)
    email = (data.get('email') or "").strip().lower()
    if not email:
        return jsonify({"msg":"email é obrigatório"}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({"msg":"Se o email existir, um link de recuperação será enviado"}), 200

    raw_token = secrets.token_urlsafe(48)
    token_hash = hash_token(raw_token)
    expiry = datetime.now(timezone.utc) + timedelta(minutes=app.config['RESET_TOKEN_EXPIRATION_MINUTES'])
    user.reset_token_hash = token_hash
    user.reset_token_expires_at = expiry
    db.session.commit()

    frontend_base = os.getenv("FRONTEND_BASE_URL", "http://localhost:8000")
    reset_link = f"{frontend_base}/reset-password?token={raw_token}&email={user.email}"

    try:
        status = send_password_reset_email(user.email, reset_link)
        print(f"E-mail enviado, status: {status}")
    except Exception as e:
        app.logger.exception("Erro ao enviar email de reset")
        return jsonify({"msg":"Erro interno ao enviar email"}), 500

    return jsonify({"msg":"Se o email existir, um link de recuperação será enviado"}), 200

@app.route('/reset-password', methods=['POST'])
def reset_password():
    data = request.get_json(force=True)
    token = data.get('token')
    email = (data.get('email') or "").strip().lower()
    new_password = data.get('new_password')

    if not token or not email or not new_password:
        return jsonify({"msg":"token, email e new_password são obrigatórios"}), 400

    user = User.query.filter_by(email=email).first()
    if not user or not user.reset_token_hash or not user.reset_token_expires_at:
        return jsonify({"msg":"token inválido ou expirado"}), 400

    if user.reset_token_expires_at < datetime.now(timezone.utc):
        user.reset_token_hash = None
        user.reset_token_expires_at = None
        db.session.commit()
        return jsonify({"msg":"token expirado"}), 400

    if hash_token(token) != user.reset_token_hash:
        return jsonify({"msg":"token inválido"}), 400

    user.password_hash = sha256_crypt.hash(new_password)
    user.reset_token_hash = None
    user.reset_token_expires_at = None
    db.session.commit()
    return jsonify({"msg":"Senha redefinida com sucesso"}), 200

# --- Rotas de Perfil ---
@app.route('/me', methods=['GET'])
@jwt_required()
def me():
    uid = get_jwt_identity()
    user = User.query.get(uid)
    if not user:
        return jsonify({"msg": "Usuário não encontrado"}), 404
    return jsonify({"user": user.to_dict()}), 200

@app.route('/update-profile', methods=['POST'])
@jwt_required()
def update_profile():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user:
        return jsonify({"msg": "Usuário não encontrado"}), 404

    data = request.get_json(force=True)
    new_username = (data.get("username") or "").strip()
    new_password = (data.get("password") or "").strip()
    new_image_base64 = data.get("profile_image")

    # Atualiza apenas os campos fornecidos
    if new_username:
        user.username = new_username
    if new_password:
        user.password_hash = sha256_crypt.hash(new_password)
    if new_image_base64:
        user.profile_image = new_image_base64

    db.session.commit()
    return jsonify({"msg": "Perfil atualizado com sucesso", "user": user.to_dict()}), 200

# --- Rotas de Ranking e Pontuação ---
@app.route('/save-score', methods=['POST'])
@jwt_required()
def save_score():
    try:
        data = request.get_json()
        user_id = get_jwt_identity()
        level = data.get('level')
        score = data.get('score')
        
        print(f"📥 Salvando pontuação: user_id={user_id}, level={level}, score={score}")
        
        # Buscar usuário
        user = User.query.get(user_id)
        if not user:
            print(" Usuário não encontrado")
            return jsonify({"msg": "Usuário não encontrado"}), 404
        
        # Determinar qual jogo baseado no nome do level
        game_id = '1'  # Jogo padrão (Jogo1)
        if 'arvore_binaria' in level:
            game_id = '2'  # Jogo das Árvores Binárias
            print(f" Identificado como Jogo 2 (Árvores Binárias)")
        else:
            print(f" Identificado como Jogo 1 (Estruturas de Dados)")
        
        # Verificar se o nível existe
        level_data = db.session.execute(
            text("SELECT id FROM game_levels WHERE name = :name AND game_id = :game_id"),
            {"name": level, "game_id": game_id}
        ).fetchone()
        
        if not level_data:
            print(f" Nível {level} não encontrado para o jogo {game_id}")
            return jsonify({"msg": f"Nível {level} não encontrado"}), 400
        
        level_id = level_data[0]
        print(f" Nível encontrado: {level} -> ID: {level_id} para jogo {game_id}")
        
        # Verificar se já existe uma pontuação
        existing_score = db.session.execute(
            text("""
                SELECT ugl.id FROM user_game_levels ugl
                JOIN user_games ug ON ugl.user_game_id = ug.id
                JOIN game_levels gl ON ugl.level_id = gl.id
                WHERE ug.user_id = :user_id AND gl.name = :level_name AND ug.game_id = :game_id
            """),
            {"user_id": user_id, "level_name": level, "game_id": game_id}
        ).fetchone()
        
        if existing_score:
            print(f"  Pontuação já existe para nível {level} do jogo {game_id}")
            return jsonify({"msg": "Pontuação da primeira conclusão já existe"}), 200
        
        print(" Primeira conclusão - processando...")
        
        # Buscar ou criar user_games
        user_game = db.session.execute(
            text("SELECT id FROM user_games WHERE user_id = :user_id AND game_id = :game_id"),
            {"user_id": user_id, "game_id": game_id}
        ).fetchone()
        
        if not user_game:
            user_game_id = str(uuid.uuid4())
            print(f" Criando novo user_games: {user_game_id} para jogo {game_id}")
            db.session.execute(
                text("""
                    INSERT INTO user_games (id, user_id, game_id, progress)
                    VALUES (:id, :user_id, :game_id, 1)
                """),
                {"id": user_game_id, "user_id": user_id, "game_id": game_id}
            )
        else:
            user_game_id = user_game[0]
            print(f" User_games encontrado: {user_game_id} para jogo {game_id}")
            # Atualizar progresso
            db.session.execute(
                text("UPDATE user_games SET progress = progress + 1 WHERE id = :user_game_id"),
                {"user_game_id": user_game_id}
            )
        
        # Inserir pontuação
        print(f" Inserindo pontuação no user_game_levels para jogo {game_id}")
        db.session.execute(
            text("""
                INSERT INTO user_game_levels (id, user_game_id, level_id, score)
                VALUES (:id, :user_game_id, :level_id, :score)
            """),
            {
                "id": str(uuid.uuid4()),
                "user_game_id": user_game_id,
                "level_id": level_id,
                "score": score
            }
        )
        
        # Atualizar score total do usuário
        total_score_result = db.session.execute(
            text("""
                SELECT COALESCE(SUM(ugl.score), 0) 
                FROM user_game_levels ugl
                JOIN user_games ug ON ugl.user_game_id = ug.id
                WHERE ug.user_id = :user_id
            """),
            {"user_id": user_id}
        ).fetchone()
        
        user.score = total_score_result[0] or 0
        print(f" Score total atualizado: {user.score}")
        
        db.session.commit()
        print(" Pontuação salva com sucesso no banco de dados!")
        return jsonify({"msg": "Pontuação salva com sucesso", "total_score": user.score}), 200
        
    except Exception as e:
        print(f" ERRO CRÍTICO ao salvar pontuação: {str(e)}")
        print(f"🔍 Traceback completo:")
        traceback.print_exc()
        db.session.rollback()
        return jsonify({"msg": "Erro interno ao salvar pontuação", "error": str(e)}), 500

@app.route('/submit-score', methods=['POST'])
@jwt_required()
def submit_score():
    try:
        current_user_id = get_jwt_identity()
        data = request.get_json()
        
        total_score = data.get('total_score', 0)
        levels_completed = data.get('levels_completed', 0)
        game_id = data.get('game_id', '1')
        
        user = User.query.get(current_user_id)
        if not user:
            return jsonify({'message': 'Usuário não encontrado'}), 404
        
        user.score = total_score
        
        user_game = db.session.execute(
            text("SELECT id FROM user_games WHERE user_id = :user_id AND game_id = :game_id"),
            {"user_id": current_user_id, "game_id": game_id}
        ).fetchone()
        
        if not user_game:
            user_game_id = str(uuid.uuid4())
            db.session.execute(
                text("""
                    INSERT INTO user_games (id, user_id, game_id, progress)
                    VALUES (:id, :user_id, :game_id, :progress)
                """),
                {
                    "id": user_game_id,
                    "user_id": current_user_id,
                    "game_id": game_id,
                    "progress": levels_completed
                }
            )
        else:
            user_game_id = user_game[0]
            db.session.execute(
                text("UPDATE user_games SET progress = :progress WHERE id = :id"),
                {"progress": levels_completed, "id": user_game_id}
            )
        
        db.session.commit()
        return jsonify({
            'message': 'Pontuação salva com sucesso!',
            'total_score': total_score,
            'levels_completed': levels_completed
        }), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"Erro em submit-score: {str(e)}")
        return jsonify({'message': f'Erro ao salvar pontuação: {str(e)}'}), 500

@app.route('/global-ranking', methods=['GET'])
@jwt_required()
def get_global_ranking():
    try:
        user_id = get_jwt_identity()
        
        print(f"📊 Carregando ranking global para usuário: {user_id}")
        
        # Buscar top 5 do ranking + INCLUINDO FOTOS DE PERFIL
        top_ranking = db.session.execute(
            text("""
                SELECT 
                    u.username,
                    u.profile_image,
                    COALESCE(u.score, 0) as total_score,
                    (SELECT COUNT(*) FROM user_game_levels ugl 
                     JOIN user_games ug ON ugl.user_game_id = ug.id 
                     WHERE ug.user_id = u.id) as levels_completed,
                    ROW_NUMBER() OVER (ORDER BY COALESCE(u.score, 0) DESC) as position
                FROM users u
                WHERE COALESCE(u.score, 0) > 0
                ORDER BY total_score DESC
                LIMIT 5
            """)
        ).fetchall()
        
        # Formatar resposta com fotos
        ranking_data = []
        for row in top_ranking:
            player_data = {
                "username": row[0],
                "profile_image": row[1],
                "total_score": float(row[2]) if row[2] else 0,
                "levels_completed": int(row[3]) if row[3] else 0,
                "position": int(row[4])
            }
            ranking_data.append(player_data)
        
        print(f"📊 Top ranking encontrado: {len(ranking_data)} jogadores")
        
        # Buscar posição do usuário atual + FOTO
        user_ranking = db.session.execute(
            text("""
                WITH ranked_users AS (
                    SELECT 
                        u.id,
                        u.username,
                        u.profile_image,
                        COALESCE(u.score, 0) as total_score,
                        (SELECT COUNT(*) FROM user_game_levels ugl 
                         JOIN user_games ug ON ugl.user_game_id = ug.id 
                         WHERE ug.user_id = u.id) as levels_completed,
                        ROW_NUMBER() OVER (ORDER BY COALESCE(u.score, 0) DESC) as position
                    FROM users u
                    WHERE COALESCE(u.score, 0) > 0
                )
                SELECT * FROM ranked_users WHERE id = :user_id
            """),
            {"user_id": user_id}
        ).fetchone()
        
        # Total de jogadores com pontuação
        total_players = db.session.execute(
            text("SELECT COUNT(*) FROM users WHERE COALESCE(score, 0) > 0")
        ).fetchone()[0] or 0
        
        user_data = None
        if user_ranking:
            user_data = {
                "username": user_ranking[1],
                "profile_image": user_ranking[2],
                "total_score": float(user_ranking[3]) if user_ranking[3] else 0,
                "levels_completed": int(user_ranking[4]) if user_ranking[4] else 0,
                "position": int(user_ranking[5]) if user_ranking[5] else 0,
                "total_players": int(total_players)
            }
            print(f" Usuário no ranking: posição {user_ranking[5]}")
        else:
            print("  Usuário não encontrado no ranking")
            # Se usuário não está no ranking, buscar dados básicos
            user = User.query.get(user_id)
            if user:
                user_data = {
                    "username": user.username,
                    "profile_image": user.profile_image,
                    "total_score": float(user.score) if user.score else 0,
                    "levels_completed": 0,
                    "position": int(total_players) + 1,
                    "total_players": int(total_players)
                }
                print(f" Usuário sem pontuação: posição {total_players + 1}")
        
        return jsonify({
            "top_ranking": ranking_data,
            "user_ranking": user_data
        }), 200
        
    except Exception as e:
        print(f" Erro ao carregar ranking global: {str(e)}")
        traceback.print_exc()
        return jsonify({"msg": "Erro ao carregar ranking global"}), 500

@app.route('/ranking', methods=['GET'])
@jwt_required()
def get_ranking():
    try:
        level = request.args.get('level', 'nivel1')
        user_id = get_jwt_identity()
        
        print(f"Carregando ranking para nível: {level}, usuário: {user_id}")
        
        top_ranking = db.session.execute(
            text("""
                SELECT 
                    u.username,
                    ugl.score,
                    ROW_NUMBER() OVER (ORDER BY ugl.score DESC) as position
                FROM user_game_levels ugl
                JOIN user_games ug ON ugl.user_game_id = ug.id
                JOIN users u ON ug.user_id = u.id
                JOIN game_levels gl ON ugl.level_id = gl.id
                WHERE gl.name = :level_name
                ORDER BY ugl.score DESC
                LIMIT 10
            """),
            {"level_name": level}
        ).fetchall()
        
        user_ranking = db.session.execute(
            text("""
                WITH ranked_scores AS (
                    SELECT 
                        u.id,
                        u.username,
                        ugl.score,
                        ROW_NUMBER() OVER (ORDER BY ugl.score DESC) as position
                    FROM user_game_levels ugl
                    JOIN user_games ug ON ugl.user_game_id = ug.id
                    JOIN users u ON ug.user_id = u.id
                    JOIN game_levels gl ON ugl.level_id = gl.id
                    WHERE gl.name = :level_name
                )
                SELECT * FROM ranked_scores WHERE id = :user_id
            """),
            {"level_name": level, "user_id": user_id}
        ).fetchone()
        
        total_players = db.session.execute(
            text("""
                SELECT COUNT(DISTINCT ug.user_id)
                FROM user_game_levels ugl
                JOIN user_games ug ON ugl.user_game_id = ug.id
                JOIN game_levels gl ON ugl.level_id = gl.id
                WHERE gl.name = :level_name
            """),
            {"level_name": level}
        ).fetchone()[0] or 0
        
        ranking_data = []
        for row in top_ranking:
            ranking_data.append({
                "username": row[0],
                "score": row[1],
                "position": row[2]
            })
        
        user_data = None
        if user_ranking:
            user_data = {
                "username": user_ranking[1],
                "score": user_ranking[2],
                "position": user_ranking[3],
                "total_players": total_players
            }
        
        return jsonify({
            "top_ranking": ranking_data,
            "user_ranking": user_data
        }), 200
        
    except Exception as e:
        print(f"Erro ao carregar ranking: {str(e)}")
        return jsonify({"msg": "Erro ao carregar ranking"}), 500

# --- Rotas de Progresso e Desbloqueio ---
@app.route('/user-progress', methods=['GET'])
@jwt_required()
def get_user_progress():
    try:
        user_id = get_jwt_identity()
        game_id = request.args.get('game_id', '1')
        
        print(f"🔍 DEBUG USER-PROGRESS - Usuário solicitante: {user_id}")
        print(f"🔍 DEBUG USER-PROGRESS - Jogo solicitado: {game_id}")
        
        # VERIFICAR SE O USUÁRIO EXISTE
        user = User.query.get(user_id)
        if not user:
            print(f" DEBUG: Usuário {user_id} NÃO ENCONTRADO na tabela users!")
            return jsonify({"msg": "Usuário não encontrado"}), 404
        
        print(f" DEBUG: Usuário encontrado: {user.username} (ID: {user.id})")
        
        # VERIFICAR QUANTOS NÍVEIS EXISTEM NO BANCO
        total_levels_in_db = db.session.execute(
            text("SELECT COUNT(*) FROM game_levels WHERE game_id = :game_id"),
            {"game_id": game_id}
        ).fetchone()[0]
        print(f"🔍Níveis no banco para jogo {game_id}: {total_levels_in_db}")
        
        # VERIFICAR SE EXISTEM user_games PARA ESTE USUÁRIO
        user_games_count = db.session.execute(
            text("SELECT COUNT(*) FROM user_games WHERE user_id = :user_id AND game_id = :game_id"),
            {"user_id": user_id, "game_id": game_id}
        ).fetchone()[0]
        
        print(f" DEBUG: User_games encontrados para usuário {user_id} no jogo {game_id}: {user_games_count}")
        
        # VERIFICAR SE EXISTEM user_game_levels PARA ESTE USUÁRIO
        user_levels_count = db.session.execute(
            text("""
                SELECT COUNT(*) FROM user_game_levels ugl
                JOIN user_games ug ON ugl.user_game_id = ug.id
                WHERE ug.user_id = :user_id AND ug.game_id = :game_id
            """),
            {"user_id": user_id, "game_id": game_id}
        ).fetchone()[0]
        
        print(f" DEBUG: User_game_levels encontrados para usuário {user_id} no jogo {game_id}: {user_levels_count}")
        
        # Buscar todos os níveis do jogo
        levels = db.session.execute(
            text("""
                SELECT id, name, order_number, difficulty 
                FROM game_levels 
                WHERE game_id = :game_id 
                ORDER BY order_number
            """),
            {"game_id": game_id}
        ).fetchall()
        
        print(f" Níveis encontrados na query: {len(levels)} para jogo {game_id}")
        
        if total_levels_in_db != len(levels):
            print(f" INCONSISTÊNCIA: Banco tem {total_levels_in_db} níveis, mas query retornou {len(levels)}")
        
        # CORREÇÃO CRÍTICA: Buscar apenas níveis concluídos por ESTE usuário específico
        completed_levels = db.session.execute(
            text("""
                SELECT gl.name, gl.order_number, COALESCE(ugl.score, 0) as score
                FROM game_levels gl
                JOIN user_game_levels ugl ON gl.id = ugl.level_id
                JOIN user_games ug ON ugl.user_game_id = ug.id 
                WHERE ug.user_id = :user_id 
                  AND ug.game_id = :game_id
                  AND gl.game_id = :game_id
                ORDER BY gl.order_number
            """),
            {"user_id": user_id, "game_id": game_id}
        ).fetchall()
        
        print(f" Níveis concluídos encontrados para usuário {user_id}: {len(completed_levels)}")
        
        # Se for um novo usuário (sem user_games), garantir que retornamos progresso vazio
        if user_games_count == 0:
            print(f"🆕 USUÁRIO NOVO: Nenhum user_games encontrado - retornando progresso vazio")
            # Criar estrutura vazia para novo usuário
            levels_data = []
            for level in levels:
                level_name = level[1]
                # Apenas o primeiro nível deve estar desbloqueado
                is_unlocked = level[2] == 1
                
                levels_data.append({
                    "id": level[0],
                    "name": level_name,
                    "order": level[2],
                    "difficulty": level[3],
                    "completed": False,  # Novo usuário, nenhum nível concluído
                    "unlocked": is_unlocked,
                    "score": 0
                })
            
            progress_data = {
                "game_id": game_id,
                "total_levels": len(levels),
                "completed_levels": 0,  # ZERO níveis concluídos
                "next_level": levels[0][1] if levels else None,  # Primeiro nível
                "levels": levels_data
            }
            
            print(f" Progresso para NOVO usuário: 0/{len(levels)} níveis concluídos")
            print(f" Níveis desbloqueados: {[level['name'] for level in levels_data if level['unlocked']]}")
            return jsonify(progress_data), 200
        
        # Criar mapa de níveis concluídos
        completed_map = {}
        for level in completed_levels:
            completed_map[level[0]] = {"score": level[2], "order": level[1]}
        
        # CORREÇÃO: Determinar qual é o próximo nível disponível
        next_level = None
        max_completed_order = 0
        
        for level in completed_levels:
            if level[1] > max_completed_order:
                max_completed_order = level[1]
        
        print(f" Ordem máxima concluída: {max_completed_order}")
        
        if max_completed_order == 0:
            # Nenhum nível concluído - próximo é o primeiro
            next_level = levels[0][1] if levels else None
            print(f"🔍 Nenhum nível concluído - próximo: {next_level}")
        elif max_completed_order < len(levels):
            # Há próximo nível disponível
            next_level = levels[max_completed_order][1]  # Índice começa em 0, order_number em 1
            print(f"🔍 Próximo nível disponível: {next_level} (ordem: {max_completed_order + 1})")
        else:
            # Todos os níveis concluídos
            next_level = levels[-1][1] if levels else None
            print(f"🔍 Todos os níveis concluídos - próximo: {next_level}")

        # Formatar resposta
        levels_data = []
        for level in levels:
            level_name = level[1]
            is_completed = level_name in completed_map
            

            # Um nível está desbloqueado se:
            # 1. É o primeiro nível (order_number == 1)
            # 2. Já foi concluído
            # 3. É qualquer nível até o próximo disponível (para permitir progressão linear)
            is_unlocked = (level[2] == 1 or 
                          is_completed or 
                          level[2] <= max_completed_order + 1)
            
            levels_data.append({
                "id": level[0],
                "name": level_name,
                "order": level[2],
                "difficulty": level[3],
                "completed": is_completed,
                "unlocked": is_unlocked,
                "score": completed_map[level_name]["score"] if is_completed else 0
            })
        
        progress_data = {
            "game_id": game_id,
            "total_levels": len(levels),
            "completed_levels": len(completed_levels),
            "next_level": next_level,
            "levels": levels_data
        }
        
        print(f" Progresso final para usuário {user_id}:")
        print(f"   - Total de níveis: {len(levels)}")
        print(f"   - Níveis concluídos: {len(completed_levels)}")
        print(f"   - Próximo nível: {next_level}")
        print(f"   - Ordem máxima concluída: {max_completed_order}")
        print(f"   - Níveis desbloqueados: {[level['name'] for level in levels_data if level['unlocked']]}")
        
        return jsonify(progress_data), 200
        
    except Exception as e:
        print(f" ERRO CRÍTICO ao buscar progresso: {str(e)}")
        traceback.print_exc()
        return jsonify({"msg": "Erro interno ao buscar progresso", "error": str(e)}), 500
    
@app.route('/check-level-access', methods=['GET'])
@jwt_required()
def check_level_access():
    try:
        user_id = get_jwt_identity()
        level_name = request.args.get('level_name')
        game_id = request.args.get('game_id', '2')
        
        if not level_name:
            return jsonify({"msg": "level_name é obrigatório"}), 400
        
        print(f" Verificando acesso ao nível {level_name} para usuário {user_id}")
        
        # Buscar informações do nível solicitado
        target_level = db.session.execute(
            text("SELECT id, order_number FROM game_levels WHERE name = :name AND game_id = :game_id"),
            {"name": level_name, "game_id": game_id}
        ).fetchone()
        
        if not target_level:
            return jsonify({"msg": "Nível não encontrado"}), 404
        
        target_order = target_level[1]
        
        # Se for o primeiro nível, sempre permitir
        if target_order == 1:
            return jsonify({
                "access_granted": True,
                "reason": "Primeiro nível sempre disponível"
            }), 200
        
        # Buscar o nível anterior
        previous_level = db.session.execute(
            text("""
                SELECT name FROM game_levels 
                WHERE game_id = :game_id AND order_number = :prev_order
            """),
            {"game_id": game_id, "prev_order": target_order - 1}
        ).fetchone()
        
        if not previous_level:
            return jsonify({"msg": "Nível anterior não encontrado"}), 404
        
        # Verificar se o nível anterior foi concluído
        previous_completed = db.session.execute(
            text("""
                SELECT 1 FROM user_game_levels ugl
                JOIN user_games ug ON ugl.user_game_id = ug.id
                JOIN game_levels gl ON ugl.level_id = gl.id
                WHERE ug.user_id = :user_id AND ug.game_id = :game_id AND gl.name = :level_name
            """),
            {
                "user_id": user_id, 
                "game_id": game_id, 
                "level_name": previous_level[0]
            }
        ).fetchone()
        
        access_granted = previous_completed is not None
        
        response_data = {
            "access_granted": access_granted,
            "target_level": level_name,
            "required_level": previous_level[0],
            "required_completed": access_granted
        }
        
        if not access_granted:
            response_data["reason"] = f"Complete o nível {previous_level[0]} primeiro"
        
        print(f" Acesso ao nível {level_name}: {access_granted}")
        return jsonify(response_data), 200
        
    except Exception as e:
        print(f" Erro ao verificar acesso: {str(e)}")
        return jsonify({"msg": "Erro ao verificar acesso"}), 500

# --- Health Check ---
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()}), 200

# --- Run ---
if __name__ == '__main__':
    init_database()
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5000)), debug=(os.getenv("FLASK_ENV")!="production"))


    # --- Rotas de Configurações do Usuário ---
@app.route('/user-settings', methods=['GET'])
@jwt_required()
def get_user_settings():
    try:
        user_id = get_jwt_identity()
        
        print(f"📥 Buscando configurações do usuário: {user_id}")
        
        # Buscar configurações do usuário
        user_settings = db.session.execute(
            text("""
                SELECT master_volume, fx_volume, fullscreen 
                FROM user_settings 
                WHERE user_id = :user_id
            """),
            {"user_id": user_id}
        ).fetchone()
        
        if user_settings:
            settings_data = {
                "master_volume": float(user_settings[0]) if user_settings[0] is not None else 1.0,
                "fx_volume": float(user_settings[1]) if user_settings[1] is not None else 1.0,
                "fullscreen": bool(user_settings[2]) if user_settings[2] is not None else True
            }
            print(f" Configurações encontradas: {settings_data}")
            return jsonify(settings_data), 200
        else:
            # Retornar configurações padrão se não existirem
            default_settings = {
                "master_volume": 1.0,
                "fx_volume": 1.0,
                "fullscreen": True
            }
            print(f"  Nenhuma configuração encontrada, usando padrão: {default_settings}")
            return jsonify(default_settings), 200
            
    except Exception as e:
        print(f" Erro ao buscar configurações: {str(e)}")
        return jsonify({"msg": "Erro ao buscar configurações"}), 500

@app.route('/user-settings', methods=['POST'])
@jwt_required()
def save_user_settings():
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        print(f" Salvando configurações para usuário: {user_id}")
        print(f" Dados recebidos: {data}")
        
        master_volume = data.get('master_volume', 1.0)
        fx_volume = data.get('fx_volume', 1.0)
        fullscreen = data.get('fullscreen', True)
        
        # Verificar se já existem configurações
        existing_settings = db.session.execute(
            text("SELECT id FROM user_settings WHERE user_id = :user_id"),
            {"user_id": user_id}
        ).fetchone()
        
        if existing_settings:
            # Atualizar configurações existentes
            db.session.execute(
                text("""
                    UPDATE user_settings 
                    SET master_volume = :master_volume, 
                        fx_volume = :fx_volume, 
                        fullscreen = :fullscreen
                    WHERE user_id = :user_id
                """),
                {
                    "master_volume": master_volume,
                    "fx_volume": fx_volume,
                    "fullscreen": fullscreen,
                    "user_id": user_id
                }
            )
            print(" Configurações atualizadas")
        else:
            # Inserir novas configurações
            db.session.execute(
                text("""
                    INSERT INTO user_settings (id, user_id, master_volume, fx_volume, fullscreen)
                    VALUES (:id, :user_id, :master_volume, :fx_volume, :fullscreen)
                """),
                {
                    "id": str(uuid.uuid4()),
                    "user_id": user_id,
                    "master_volume": master_volume,
                    "fx_volume": fx_volume,
                    "fullscreen": fullscreen
                }
            )
            print(" Configurações inseridas")
        
        db.session.commit()
        return jsonify({"msg": "Configurações salvas com sucesso"}), 200
        
    except Exception as e:
        print(f" Erro ao salvar configurações: {str(e)}")
        db.session.rollback()
        return jsonify({"msg": "Erro ao salvar configurações"}), 500

@app.route('/reset-user-settings', methods=['POST'])
@jwt_required()
def reset_user_settings():
    try:
        user_id = get_jwt_identity()
        
        print(f"🔄 Resetando configurações para usuário: {user_id}")
        
        # Deletar configurações existentes
        db.session.execute(
            text("DELETE FROM user_settings WHERE user_id = :user_id"),
            {"user_id": user_id}
        )
        
        db.session.commit()
        
        # Retornar configurações padrão
        default_settings = {
            "master_volume": 1.0,
            "fx_volume": 1.0,
            "fullscreen": True
        }
        
        print(" Configurações resetadas para padrão")
        return jsonify({
            "msg": "Configurações resetadas para padrão",
            "default_settings": default_settings
        }), 200
        
    except Exception as e:
        print(f" Erro ao resetar configurações: {str(e)}")
        db.session.rollback()
        return jsonify({"msg": "Erro ao resetar configurações"}), 500
