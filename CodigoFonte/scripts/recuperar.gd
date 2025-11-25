extends Node2D

# --- Nós da cena ---
@onready var email_input: LineEdit = $VBoxContainer/HBoxContainer/LineEditInsiraEmail
@onready var label_msg: Label = $LabelMensagem
@onready var button_enviar: Button = $UI/ButtonRecuperarSenha
@onready var button_voltar: TextureButton = $ArrowBack
var button_hover_script: GDScript

var http: HTTPRequest  # HTTPRequest dinâmico
var http_busy: bool = false  # evita múltiplas requisições simultâneas

const API_BASE: String = "http://localhost:5000"  # seu backend Flask
const LOGIN_SCENE: String = "res://Login.tscn"    # caminho correto da cena de login


func _ready() -> void:
	# Cria HTTPRequest dinamicamente
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)

	# Conecta botões
	button_enviar.pressed.connect(_on_ButtonEnviar_pressed)
	button_voltar.pressed.connect(_on_ButtonVoltar_pressed)
	
	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# Aplicar efeito hover após um pequeno delay para garantir que todos os botões estejam carregados
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()


# --- Botão Enviar ---
func _on_ButtonEnviar_pressed() -> void:
	if http_busy:
		_set_message("Aguarde a requisição anterior terminar...", Color.YELLOW)
		return

	var email: String = email_input.text.strip_edges()

	if email.is_empty():
		_set_message("Digite seu e-mail.", Color.RED)
		return
	if not _validar_email(email):
		_set_message("E-mail inválido.", Color.RED)
		return

	# prepara requisição
	var payload: Dictionary = {"email": email}
	var body: String = JSON.stringify(payload)

	var err = http.request(
		API_BASE + "/forgot-password",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		_set_message("Erro ao enviar requisição.", Color.RED)
		return

	http_busy = true  # marca que a requisição está em andamento


# --- Botão Voltar ---
func _on_ButtonVoltar_pressed() -> void:
	var err = get_tree().change_scene_to_file(LOGIN_SCENE)
	if err != OK:
		_set_message("Erro ao carregar cena de login.", Color.RED)


# --- Callback HTTPRequest ---
func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	http_busy = false  # libera para próxima requisição

	var response_text: String = body.get_string_from_utf8()
	var json := JSON.new()
	var parse_result = json.parse(response_text)

	if parse_result != OK:
		_set_message("Erro ao processar resposta do servidor.", Color.RED)
		return

	var data: Dictionary = json.data

	if response_code >= 200 and response_code < 300:
		_set_message(data.get("msg", "Verifique seu e-mail para instruções."), Color.GREEN)
	else:
		_set_message(data.get("msg", "Erro: código %d" % response_code), Color.RED)


# --- Helpers ---
func _set_message(texto: String, cor: Color) -> void:
	label_msg.text = texto
	label_msg.modulate = cor


func _validar_email(email: String) -> bool:
	return email.find("@") != -1 and email.find(".") != -1 and email.length() >= 5


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
