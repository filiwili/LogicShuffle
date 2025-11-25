extends Control

@onready var button_login: Button = $ButtonLogin
@onready var button_fazer_cadastro: Button = $ButtonCadastro
@onready var button_esqueci_senha: Button = $ButtonEsqueciSenha
@onready var button_ver_senha: Button = $UI/VBoxContainer/HBoxContainer2/ButtonVerSenha
@onready var line_edit_email: LineEdit = $UI/VBoxContainer/HBoxContainer/LineEditEmail
@onready var line_edit_senha: LineEdit = $UI/VBoxContainer/HBoxContainer2/LineEditSenha
@onready var label_mensagem: Label = $LabelMensagem
@onready var http_request: HTTPRequest = $HTTPRequest
var button_hover_script: GDScript


const API_BASE: String = "http://localhost:5000"

func _ready() -> void:
	
	if not SettingsManager.is_background_music_playing:
		SettingsManager.play_background_music("res://sounds/test_music.wav", true)
	# CORREÇÃO: Verificar se o nó está na árvore antes de acessar get_tree()
	if not is_inside_tree():
		await tree_entered
	
	line_edit_senha.secret = true

	button_login.pressed.connect(_on_ButtonLogin_pressed)
	button_fazer_cadastro.pressed.connect(_on_ButtonFazerCadastro_pressed)
	button_esqueci_senha.pressed.connect(_on_ButtonEsqueciSenha_pressed)
	button_ver_senha.pressed.connect(_on_ButtonVerSenha_pressed)

	http_request.request_completed.connect(_on_request_completed)

	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# CORREÇÃO: Preencher email salvo se existir, mas NÃO fazer login automático
	var saved_email = SessionManager.get_saved_email()
	if saved_email != "":
		line_edit_email.text = saved_email
		_set_message("Email salvo preenchido. Digite sua senha.", Color.YELLOW)
	else:
		_set_message("Faça login para continuar", Color.WHITE)
	
	# Aplicar efeito hover após um pequeno delay para garantir que todos os botões estejam carregados
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()

# --- LOGIN ---
func _on_ButtonLogin_pressed() -> void:
	var email: String = line_edit_email.text.strip_edges()
	var senha: String = line_edit_senha.text

	if email.is_empty() or senha.is_empty():
		_set_message("E-mail e senha são obrigatórios.", Color.RED)
		return
	if not _is_valid_email(email):
		_set_message("Por favor, insira um e-mail válido.", Color.RED)
		return

	var payload: Dictionary = {
		"email": email,
		"password": senha
	}
	var body: String = JSON.stringify(payload)

	_set_message("Verificando login...", Color.WHITE)
	button_login.disabled = true

	var err = http_request.request(
		API_BASE + "/login",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		_set_message("Erro ao conectar com o servidor.", Color.RED)
		button_login.disabled = false

# --- CADASTRO ---
func _on_ButtonFazerCadastro_pressed() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file("res://Cadastro.tscn")
		

# --- RECUPERAR SENHA ---
func _on_ButtonEsqueciSenha_pressed() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file("res://Recuperar.tscn")

# --- VER/ESCONDER SENHA ---
func _on_ButtonVerSenha_pressed() -> void:
	line_edit_senha.secret = not line_edit_senha.secret
	if line_edit_senha.secret:
		button_ver_senha.text = "👁"
	else:
		button_ver_senha.text = "👁‍🗨"

# --- RESPONSE ---
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	button_login.disabled = false
	
	var response_text: String = body.get_string_from_utf8()
	print("Resposta do login: ", response_text)
	
	var json := JSON.new()
	var parse_result = json.parse(response_text)

	if parse_result != OK:
		_set_message("Erro ao processar resposta do servidor.", Color.RED)
		return

	var data: Dictionary = json.data

	if response_code >= 200 and response_code < 300:
		_set_message(data.get("msg", "Login realizado com sucesso!"), Color.GREEN)
		
		# CORREÇÃO CRÍTICA: Forçar limpeza do ProgressManager ANTES de fazer login
		if ProgressManager:
			print("🧹 Forçando limpeza do ProgressManager antes do login...")
			ProgressManager.force_clear_cache()
		
		# CORREÇÃO: Tratamento seguro dos dados recebidos
		if data.has("access_token") and data.has("user"):
			var user_data = data["user"]
			
			# CORREÇÃO: Garantir que todos os campos existem e não são null
			var session_data = {
				"access_token": data["access_token"] if data.has("access_token") else "",
				"username": user_data.get("username", "") if user_data.has("username") else "",
				"email": user_data.get("email", line_edit_email.text.strip_edges()) if user_data.has("email") else line_edit_email.text.strip_edges(),
				"id": str(user_data.get("id", "")) if user_data.has("id") else "",
				"profile_image": user_data.get("profile_image", "") if user_data.has("profile_image") else ""
			}
			
			print("Dados da sessão preparados: ", session_data)
			
			# CORREÇÃO: Pequeno delay para garantir que a limpeza foi processada
			await get_tree().create_timer(0.1).timeout
			
			# Usar set_user_data em vez de login
			SessionManager.set_user_data(session_data)
			
			print("=== LOGIN BEM SUCEDIDO ===")
			print("User ID: ", SessionManager.user_id)
			print("Username: ", SessionManager.user_name)
			print("Email: ", SessionManager.email)
			print("Token: ", SessionManager.auth_token != "")
			print("Profile Image: ", SessionManager.profile_image != "")
			
			# Limpar campos sensíveis
			line_edit_senha.text = ""
			
			# CORREÇÃO: Redirecionar de forma segura após delay
			call_deferred("_delayed_redirect_to_main")
		else:
			_set_message("Erro: Dados incompletos recebidos do servidor", Color.RED)
	elif response_code == 401:
		_set_message(data.get("msg", "E-mail ou senha incorretos."), Color.RED)
	elif response_code == 400:
		_set_message(data.get("msg", "Dados inválidos."), Color.RED)
	else:
		_set_message(data.get("msg", "Erro de comunicação. Código: %d" % response_code), Color.RED)

# CORREÇÃO: Função para redirecionar após delay
func _delayed_redirect_to_main():
	if is_inside_tree():
		# Criar timer de forma segura
		var timer = Timer.new()
		add_child(timer)
		timer.wait_time = 1.5
		timer.one_shot = true
		timer.timeout.connect(_on_redirect_timer_timeout)
		timer.start()

func _on_redirect_timer_timeout():
	if is_inside_tree():
		get_tree().change_scene_to_file("res://Main.tscn")

# --- HELPERS ---
func _set_message(texto: String, cor: Color) -> void:
	label_mensagem.text = texto
	label_mensagem.modulate = cor

func _is_valid_email(email: String) -> bool:
	var email_regex = RegEx.new()
	email_regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	return email_regex.search(email) != null

func aplicar_efeito_hover_todos_botoes():
	# CORREÇÃO: Verificar se ainda estamos na árvore
	if not is_inside_tree():
		return
	
	var botoes = _buscar_todos_botoes(self)
	
	for botao in botoes:
		if is_instance_valid(botao) and botao.is_inside_tree() and not botao.has_node("ButtonHoverEffect"):
			var effect_node = Node.new()
			effect_node.set_script(button_hover_script)
			botao.add_child(effect_node)
			effect_node.name = "ButtonHoverEffect"

func _buscar_todos_botoes(node: Node) -> Array:
	var botoes = []
	
	# CORREÇÃO: Verificar se o nó é válido e está na árvore
	if not is_instance_valid(node) or not node.is_inside_tree():
		return botoes
	
	if node is BaseButton and node.visible:
		botoes.append(node)
	
	for child in node.get_children():
		botoes.append_array(_buscar_todos_botoes(child))
	
	return botoes

# Limpar mensagem quando o usuário começar a digitar
func _on_line_edit_email_text_changed(new_text: String):
	if label_mensagem.text != "":
		_set_message("", Color.WHITE)

func _on_line_edit_senha_text_changed(new_text: String):
	if label_mensagem.text != "":
		_set_message("", Color.WHITE)

# CORREÇÃO: Limpar timers e conexões quando a cena for removida
func _exit_tree():
	# Limpar todos os timers pendentes
	for child in get_children():
		if child is Timer:
			child.stop()
			child.queue_free()
