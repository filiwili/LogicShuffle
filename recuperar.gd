extends Node2D

var line_edit_email
var button_recuperar
var label_titulo
var arrow_back

func _ready():
	line_edit_email = $VBoxContainer/HBoxContainer/LineEditInsiraEmail
	button_recuperar = $UI/ButtonRecuperarSenha
	label_titulo = $UI/Label
	arrow_back = $ArrowBack

	if button_recuperar:
		button_recuperar.pressed.connect(_ao_recuperar_senha)

func _validar_email(email: String) -> bool:
	return email.match("*@*.*")

func _ao_recuperar_senha():
	var email = line_edit_email.text.strip_edges()

	if email == "":
		label_titulo.text = "Digite seu e-mail!"
		return

	if not _validar_email(email):
		label_titulo.text = "E-mail inválido!"
		return

	var dados = {
		"email": email
	}

	var requisicao = HTTPRequest.new()
	add_child(requisicao)

	requisicao.request_completed.connect(_ao_receber_resposta)
	var json = JSON.stringify(dados)
	var headers = ["Content-Type: application/json"]
	var err = requisicao.request("http://127.0.0.1:3000/recuperar", headers, HTTPClient.METHOD_POST, json)

	if err != OK:
		label_titulo.text = "Erro ao enviar requisição."

func _ao_receber_resposta(result, response_code, headers, body):
	var resposta = JSON.parse_string(body.get_string_from_utf8())
	if resposta:
		if resposta.has("success") and resposta["success"]:
			label_titulo.text = "Verifique seu e-mail!"
		else:
			label_titulo.text = resposta.get("message", "Erro na recuperação.")
	else:
		label_titulo.text = "Resposta inválida do servidor."

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if arrow_back.get_rect().has_point(to_local(event.position)):
			get_tree().change_scene_to_file("res://Login.tscn")
