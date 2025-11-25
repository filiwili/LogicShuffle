extends Node2D

@onready var line_nome = $VBoxContainer/HBoxContainer/LineEditNome
@onready var line_senha = $VBoxContainer/HBoxContainer2/LineEditSenha
@onready var button_ver_senha = $VBoxContainer/HBoxContainer2/ButtonVerSenha
@onready var button_salvar = $ButtonSalvar
@onready var button_imagem = $UI/ButtonEditarImagem
@onready var profile_picture = $ProfilePicture
@onready var arrow_back = $ArrowBack
@onready var label_status = $LabelMensagem
var button_hover_script: GDScript

var http: HTTPRequest
var token: String = ""
var imagem_base64: String = ""
var backend_url: String = "http://127.0.0.1:5000"
var current_profile_image: String = ""
var default_profile_texture = preload("res://cat.png")

const PROFILE_IMAGE_SIZE = 256

func _ready():
	print("=== PERFIL - Carregando ===")
	

	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# Aplicar efeito hover após um pequeno delay para garantir que todos os botões estejam carregados
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_http_request_completed)
	
	token = SessionManager.auth_token
	
	if token == "":
		label_status.text = "ERRO: Token vazio! Faça login novamente."
		return
	
	if SessionManager.user_name != "":
		line_nome.text = SessionManager.user_name
		line_nome.placeholder_text = ""
	else:
		line_nome.placeholder_text = "Insira seu nome"
	
	# Tenta carregar do SessionManager primeiro
	if SessionManager.profile_image != "":
		_load_profile_image(SessionManager.profile_image)
	else:
		_set_default_profile_image()
	
	button_salvar.pressed.connect(_on_salvar_pressed)
	button_ver_senha.pressed.connect(_on_ver_senha_pressed)
	button_imagem.pressed.connect(_on_editar_imagem_pressed)
	arrow_back.pressed.connect(_on_voltar_pressed)
	
	load_user_data()
	

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		label_status.text = "Erro de conexão: " + str(result)
		return
	
	var response = body.get_string_from_utf8()
	# DEBUG REDUZIDO - não imprime a resposta completa
	print("Resposta do servidor (", response_code, ")")
	
	var json = JSON.new()
	var parse_error = json.parse(response)
	
	if parse_error != OK:
		label_status.text = "Erro ao interpretar resposta"
		return
		
	var data = json.get_data()
	
	if response_code == 200:
		if data != null and "user" in data:
			var user = data.user
			
			if user.has("username") and user.username != null and user.username != "":
				line_nome.text = user.username
				line_nome.placeholder_text = ""
				SessionManager.user_name = user.username
			else:
				line_nome.placeholder_text = "Insira seu nome"
			
			if user.has("profile_image") and user.profile_image != null and user.profile_image != "":
				current_profile_image = user.profile_image
				_load_profile_image(user.profile_image)
			else:
				_set_default_profile_image()
		else:
			label_status.text = "Formato de resposta inválido"
	elif response_code == 401 or response_code == 422:
		label_status.text = "Erro de autenticação. Faça login novamente."
	else:
		label_status.text = "Erro: " + str(response_code)

func load_user_data() -> void:
	var headers = ["Authorization: Bearer " + token, "Content-Type: application/json"]
	var error = http.request(backend_url + "/me", headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		label_status.text = "Erro ao enviar requisição: " + str(error)

func _load_profile_image(base64_string: String) -> void:
	if base64_string == "" or base64_string == null:
		_set_default_profile_image()
		return
		
	var image_data = Marshalls.base64_to_raw(base64_string)
	var image = Image.new()
	var error = image.load_png_from_buffer(image_data)
	
	if error == OK:
		image.resize(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE, Image.INTERPOLATE_LANCZOS)
		var texture = ImageTexture.create_from_image(image)
		profile_picture.texture_normal = texture
		profile_picture.custom_minimum_size = Vector2(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE)
		
		# SALVAR NO SESSIONMANAGER
		SessionManager.profile_image = base64_string
		current_profile_image = base64_string
		print("Imagem carregada e salva no SessionManager")
	else:
		print("Erro ao carregar imagem do perfil")
		_set_default_profile_image()

func _set_default_profile_image():
	if default_profile_texture:
		var default_image = default_profile_texture.get_image()
		default_image.resize(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE, Image.INTERPOLATE_LANCZOS)
		var resized_texture = ImageTexture.create_from_image(default_image)
		profile_picture.texture_normal = resized_texture
		profile_picture.custom_minimum_size = Vector2(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE)
		
		# Limpar imagem do SessionManager se for padrão
		SessionManager.profile_image = ""
		print("Imagem padrão configurada")
	else:
		print("Erro: Imagem padrão não encontrada")

func _on_editar_imagem_pressed() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.png ; Imagens PNG", "*.jpg ; Imagens JPG", "*.jpeg ; Imagens JPEG"]
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.size = Vector2(600, 400)
	
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.close_requested.connect(file_dialog.queue_free)
	file_dialog.canceled.connect(file_dialog.queue_free)
	
	add_child(file_dialog)
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	var image = Image.new()
	var error = image.load(path)
	
	if error == OK:
		image.resize(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE, Image.INTERPOLATE_LANCZOS)
		var texture = ImageTexture.create_from_image(image)
		profile_picture.texture_normal = texture
		profile_picture.custom_minimum_size = Vector2(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE)
		
		var bytes = image.save_png_to_buffer()
		imagem_base64 = Marshalls.raw_to_base64(bytes)
		
		# SALVAR NO SESSIONMANAGER IMEDIATAMENTE
		SessionManager.profile_image = imagem_base64
		print("Nova imagem carregada e salva no SessionManager")
		
		label_status.text = "Imagem carregada com sucesso!"
	else:
		label_status.text = "Erro ao carregar imagem: " + str(error)

func _on_ver_senha_pressed() -> void:
	line_senha.secret = not line_senha.secret

func _on_salvar_pressed() -> void:
	var novo_nome = line_nome.text.strip_edges()
	if novo_nome.is_empty():
		label_status.text = "Nome não pode estar vazio!"
		return
	
	var request_data = {"username": novo_nome}
	
	if not line_senha.text.is_empty():
		request_data["password"] = line_senha.text
	
	if not imagem_base64.is_empty():
		request_data["profile_image"] = imagem_base64
	elif current_profile_image != "":
		request_data["profile_image"] = current_profile_image
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + token]
	var body = JSON.stringify(request_data)
	
	print("Enviando atualização de perfil")
	
	var update_http = HTTPRequest.new()
	add_child(update_http)
	update_http.request_completed.connect(_on_http_update_completed.bind(update_http))
	
	var error = update_http.request(backend_url + "/update-profile", headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		label_status.text = "Erro ao enviar requisição: " + str(error)
		update_http.queue_free()
	else:
		label_status.text = "Salvando..."
		button_salvar.disabled = true

func _on_http_update_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, update_http: HTTPRequest):
	button_salvar.disabled = false
	
	var response = body.get_string_from_utf8()
	print("Resposta da atualização (", response_code, ")")
	
	var json = JSON.new()
	var parse_error = json.parse(response)
	var data = json.get_data() if parse_error == OK else null
	
	update_http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		label_status.text = "Erro de conexão: " + str(result)
		return
	
	if response_code == 200:
		label_status.text = data.msg if data and data.has("msg") else "Perfil atualizado com sucesso!"
		SessionManager.user_name = line_nome.text.strip_edges()
		
		if not imagem_base64.is_empty():
			current_profile_image = imagem_base64
			SessionManager.profile_image = imagem_base64
			imagem_base64 = ""
			print("Imagem atualizada no SessionManager após salvar")
		
		line_senha.text = ""
	elif response_code == 401 or response_code == 422:
		label_status.text = "Erro de autenticação ao salvar. Faça login novamente."
	else:
		label_status.text = "Erro ao atualizar: " + str(response_code)

func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")
	
	



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
