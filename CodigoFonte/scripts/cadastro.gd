extends Node2D

# Referências de interface
@onready var line_edit_nome: LineEdit = $VBoxContainer/HBoxContainer/LineEditNome
@onready var line_edit_email: LineEdit = $VBoxContainer/HBoxContainer2/LineEditEmail
@onready var line_edit_senha1: LineEdit = $VBoxContainer/HBoxContainer3/LineEditInsiraSenha1
@onready var line_edit_senha2: LineEdit = $VBoxContainer/HBoxContainer4/LineEditInsiraSenha2
@onready var label_mensagem: Label = $LabelMensagem

@onready var btn_ver_senha1: Button = $VBoxContainer/HBoxContainer3/ButtonVerSenha1
@onready var btn_ver_senha2: Button = $VBoxContainer/HBoxContainer4/ButtonVerSenha2
@onready var btn_criar_conta: Button = $UI/ButtonCriarConta
@onready var arrow_back: TextureButton = $ArrowBack
@onready var http: HTTPRequest = HTTPRequest.new()
var button_hover_script: GDScript

const API_BASE: String = "http://127.0.0.1:5000"  # backend Flask


func _ready() -> void:
	add_child(http)
	http.request_completed.connect(_on_request_completed)

	# Conexões dos botões
	btn_criar_conta.pressed.connect(_ao_criar_conta)
	btn_ver_senha1.pressed.connect(_toggle_senha1)
	btn_ver_senha2.pressed.connect(_toggle_senha2)
	arrow_back.pressed.connect(_on_arrow_back_pressed)

	# Configuração dos campos de senha
	line_edit_senha1.secret = true
	line_edit_senha2.secret = true
	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# Aplicar efeito hover após um pequeno delay para garantir que todos os botões estejam carregados
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()



func _toggle_senha1() -> void:
	line_edit_senha1.secret = not line_edit_senha1.secret


func _toggle_senha2() -> void:
	line_edit_senha2.secret = not line_edit_senha2.secret


func _validar_email(email: String) -> bool:
	return email.match("*@*.*")


func _ao_criar_conta() -> void:
	var nome: String = line_edit_nome.text.strip_edges()
	var email: String = line_edit_email.text.strip_edges()
	var senha1: String = line_edit_senha1.text
	var senha2: String = line_edit_senha2.text

	# Validações locais
	if nome.is_empty() or email.is_empty() or senha1.is_empty() or senha2.is_empty():
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

	label_mensagem.text = "Enviando dados..."

	# Monta payload para o backend Flask
	var payload: Dictionary = {
		"username": nome,
		"email": email,
		"password": senha1
	}

	var body: String = JSON.stringify(payload)
	var headers: PackedStringArray = ["Content-Type: application/json"]

	var err := http.request(API_BASE + "/register", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		label_mensagem.text = "Erro ao enviar dados: %s" % err


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var resposta_texto: String = body.get_string_from_utf8()
	var json := JSON.new()
	var parsed := json.parse(resposta_texto)

	if parsed != OK:
		label_mensagem.text = "Erro ao processar resposta do servidor."
		return

	var data: Dictionary = json.data

	if response_code >= 200 and response_code < 300:
		label_mensagem.text = data.get("msg", "Cadastro realizado com sucesso!")
		await get_tree().create_timer(1.2).timeout
		get_tree().change_scene_to_file("res://Login.tscn")
	else:
		label_mensagem.text = data.get("msg", "Erro no cadastro.")


func _on_arrow_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Login.tscn")


func aplicar_efeito_hover_todos_botoes():
	var botoes = _buscar_todos_botoes(self)
	
	for botao in botoes:
		if not botao.has_node("ButtonHoverEffect"):
			var effect_node = Node.new()
			effect_node.set_script(button_hover_script)
			botao.add_child(effect_node)
			effect_node.name = "ButtonHoverEffect"

func _buscar_todos_botoes(node: Node) -> Array:
	var botoes = []
	
	if node is BaseButton and node.visible:
		botoes.append(node)
	
	for child in node.get_children():
		botoes.append_array(_buscar_todos_botoes(child))
	
	return botoes
