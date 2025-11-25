extends Control

@onready var button_login = $ButtonLogin
@onready var button_fazer_cadastro = $ButtonCadastro
@onready var button_esqueci_senha = $ButtonEsqueciSenha
@onready var line_edit_email = $UI/VBoxContainer/HBoxContainer/LineEditEmail
@onready var line_edit_senha = $UI/VBoxContainer/HBoxContainer2/LineEditSenha
@onready var button_ver_senha = $UI/VBoxContainer/HBoxContainer2/ButtonVerSenha
@onready var label_mensagem = $LabelMensagem
@onready var http_request = $HTTPRequest

func _ready():
	if button_login:
		button_login.pressed.connect(_on_ButtonLogin_pressed)
	else:
		print("Botão de login não encontrado!")

	if button_fazer_cadastro:
		button_fazer_cadastro.pressed.connect(_on_ButtonFazerCadastro_pressed)
	else:
		print("Botão de cadastro não encontrado!")

	if button_esqueci_senha:
		button_esqueci_senha.pressed.connect(_on_ButtonEsqueciSenha_pressed)
	else:
		print("Botão de esqueci senha não encontrado!")

	if button_ver_senha:
		button_ver_senha.pressed.connect(_on_ButtonVerSenha_pressed)
	else:
		print("Botão de ver senha não encontrado!")

	if line_edit_senha:
		line_edit_senha.secret = true
	else:
		print("LineEditSenha não encontrado!")

func _on_ButtonLogin_pressed():
	var email = line_edit_email.text.strip_edges()
	var senha = line_edit_senha.text.strip_edges()

	if email == "" or senha == "":
		_set_message("E-mail e senha são obrigatórios.", Color.RED)
		return

	if not _is_valid_email(email):
		_set_message("Por favor, insira um e-mail válido.", Color.RED)
		return

	var url = "http://localhost:3000/login"
	var headers = ["Content-Type: application/json"]
	var request_data = {"email": email, "senha": senha}
	var json_data = JSON.stringify(request_data)

	_set_message("Verificando login...", Color.WHITE)

	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_data)

	if error != OK:
		_set_message("Erro ao enviar requisição: %s" % str(error), Color.RED)

func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray):
	print("Resposta do servidor:", response_code)
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		if parse_result == OK:
			var response = json.data
			if response.has("success") and response["success"] == true:
				_set_message("Login bem-sucedido!", Color.GREEN)
				await get_tree().create_timer(1.0).timeout
				get_tree().change_scene_to_file("res://Main.tscn")
			else:
				var erro = response.get("message", "Credenciais incorretas. Verifique seu e-mail e senha.")
				_set_message("Erro: " + erro, Color.RED)
		else:
			_set_message("Erro ao interpretar resposta do servidor.", Color.RED)
	elif response_code == 401:
		_set_message("E-mail ou senha incorretos.", Color.RED)
	elif response_code == 500:
		_set_message("Erro interno no servidor. Tente novamente mais tarde.", Color.RED)
	else:
		_set_message("Erro de comunicação com o servidor. Código: %d" % response_code, Color.RED)

func _on_ButtonFazerCadastro_pressed():
	get_tree().change_scene_to_file("res://Cadastro.tscn")

func _on_ButtonEsqueciSenha_pressed():
	get_tree().change_scene_to_file("res://Recuperar.tscn")

func _on_ButtonVerSenha_pressed():
	line_edit_senha.secret = not line_edit_senha.secret

func _set_message(texto: String, cor: Color):
	label_mensagem.text = texto
	label_mensagem.modulate = cor

func _is_valid_email(email: String) -> bool:
	return email.find("@") != -1 and email.find(".") != -1 and email.length() >= 5
