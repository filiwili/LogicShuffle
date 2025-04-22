extends Node2D

var line_edit_nome
var line_edit_email
var line_edit_senha1
var line_edit_senha2
var label_mensagem

var btn_ver_senha1
var btn_ver_senha2
var btn_criar_conta

var arrow_back

func _ready():
	line_edit_nome = $VBoxContainer/HBoxContainer/LineEditNome
	line_edit_email = $VBoxContainer/HBoxContainer2/LineEditEmail
	line_edit_senha1 = $VBoxContainer/HBoxContainer3/LineEditInsiraSenha1
	line_edit_senha2 = $VBoxContainer/HBoxContainer4/LineEditInsiraSenha2
	label_mensagem = $LabelMensagem

	btn_ver_senha1 = $VBoxContainer/HBoxContainer3/ButtonVerSenha1
	btn_ver_senha2 = $VBoxContainer/HBoxContainer4/ButtonVerSenha2
	btn_criar_conta = $UI/ButtonCriarConta
	arrow_back = $ArrowBack

	if btn_criar_conta:
		btn_criar_conta.pressed.connect(_ao_criar_conta)
	if btn_ver_senha1:
		btn_ver_senha1.pressed.connect(_toggle_senha1)
	if btn_ver_senha2:
		btn_ver_senha2.pressed.connect(_toggle_senha2)

	if line_edit_senha1:
		line_edit_senha1.secret = true
	if line_edit_senha2:
		line_edit_senha2.secret = true

func _toggle_senha1():
	if line_edit_senha1:
		line_edit_senha1.secret = not line_edit_senha1.secret

func _toggle_senha2():
	if line_edit_senha2:
		line_edit_senha2.secret = not line_edit_senha2.secret

func _validar_email(email: String) -> bool:
	return email.match("*@*.*")

func _validar_nome(nome: String) -> bool:
	var requisicao = HTTPRequest.new()
	add_child(requisicao)
	requisicao.request_completed.connect(_ao_receber_resposta_nome)
	var json = '{"nome": "%s"}' % nome
	var headers = ["Content-Type: application/json"]
	var err = requisicao.request("http://127.0.0.1:3000/validar_nome", headers, HTTPClient.METHOD_POST, json)

	if err != OK:
		label_mensagem.text = "Erro ao verificar nome de usuário: %s" % err
		return false

	return true

func _ao_receber_resposta_nome(result, response_code, headers, body):
	var resposta = JSON.parse_string(body.get_string_from_utf8())
	if resposta:
		if resposta.has("success") and resposta["success"]:
			label_mensagem.text = "Nome de usuário disponível."
		else:
			label_mensagem.text = "Nome de usuário já existe."
	else:
		label_mensagem.text = "Resposta inválida do servidor."

func _ao_criar_conta():
	var nome = line_edit_nome.text.strip_edges()
	var email = line_edit_email.text.strip_edges()
	var senha1 = line_edit_senha1.text
	var senha2 = line_edit_senha2.text

	if nome == "" or email == "" or senha1 == "" or senha2 == "":
		label_mensagem.text = "Preencha todos os campos!"
		return

	if not _validar_email(email):
		label_mensagem.text = "E-mail inválido!"
		return

	if senha1.length() < 6:
		label_mensagem.text = "Senha deve ter pelo menos 6 caracteres!"
		return

	if senha1 != senha2:
		label_mensagem.text = "As senhas não coincidem!"
		return

	if not _validar_nome(nome):
		label_mensagem.text = "Nome de usuário já existe!"
		return

	var dados = {
		"nome": nome,
		"email": email,
		"senha": senha1
	}

	var requisicao = HTTPRequest.new()
	add_child(requisicao)
	requisicao.request_completed.connect(_ao_receber_resposta)
	var json = JSON.stringify(dados)
	var headers = ["Content-Type: application/json"]
	var err = requisicao.request("http://127.0.0.1:3000/cadastro", headers, HTTPClient.METHOD_POST, json)

	if err != OK:
		label_mensagem.text = "Erro ao enviar dados: %s" % err

func _ao_receber_resposta(result, response_code, headers, body):
	var resposta = JSON.parse_string(body.get_string_from_utf8())
	if resposta:
		if resposta.has("success") and resposta["success"]:
			label_mensagem.text = "Cadastro realizado com sucesso!"
			await get_tree().create_timer(1.2).timeout
			get_tree().change_scene_to_file("res://Login.tscn")
		else:
			label_mensagem.text = resposta.get("message", "Erro no cadastro.")
	else:
		label_mensagem.text = "Resposta inválida do servidor."

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if arrow_back.get_rect().has_point(to_local(event.position)):
			get_tree().change_scene_to_file("res://Login.tscn")
