# SessionManager.gd
extends Node

var auth_token: String = ""
var user_name: String = ""
var email: String = ""
var profile_image: String = ""
var user_id: String = ""

signal user_changed
signal login_successful
signal logout_successful
signal profile_updated

# Função para fazer login
func login(token: String, username: String, user_email: String, uid: String = "") -> void:
	auth_token = token
	user_name = username
	email = user_email
	user_id = uid
	
	print("=== SESSION MANAGER LOGIN ===")
	print("User ID: ", user_id)
	print("Username: ", user_name)
	print("Email: ", email)
	print("Token length: ", auth_token.length())
	
	# Salvar dados localmente para persistência entre sessões
	_save_session_data()
	
	# Emitir sinais
	user_changed.emit()
	login_successful.emit()

# Função para definir dados do usuário (usada após registro/login)
func set_user_data(user_data: Dictionary) -> void:
	print("=== SESSION MANAGER - DEFININDO DADOS DO USUÁRIO ===")
	print("Dados recebidos: ", user_data)
	
	# CORREÇÃO: Tratar valores null/nil antes da atribuição
	auth_token = _safe_get_string(user_data, "access_token", auth_token)
	user_name = _safe_get_string(user_data, "username", user_name)
	email = _safe_get_string(user_data, "email", email)
	user_id = _safe_get_string(user_data, "id", user_id)
	profile_image = _safe_get_string(user_data, "profile_image", profile_image)
	
	print("Dados processados:")
	print("User ID: ", user_id)
	print("Username: ", user_name)
	print("Email: ", email)
	print("Token: ", "[PRESENTE]" if auth_token != "" else "[AUSENTE]")
	print("Profile Image: ", "[PRESENTE]" if profile_image != "" else "[AUSENTE]")
	
	# Salvar dados localmente
	_save_session_data()
	
	# Emitir sinais
	user_changed.emit()
	login_successful.emit()

# Função para atualizar a imagem de perfil
func update_profile_image(image_base64: String) -> void:
	profile_image = image_base64
	print("Imagem de perfil atualizada no SessionManager")
	
	# Atualizar dados salvos
	_save_session_data()
	
	profile_updated.emit()

# Função para atualizar dados do perfil
func update_profile(username: String, user_email: String) -> void:
	user_name = username
	email = user_email
	
	print("=== SESSION MANAGER - PERFIL ATUALIZADO ===")
	print("Novo username: ", user_name)
	print("Novo email: ", email)
	
	# Atualizar dados salvos
	_save_session_data()
	
	user_changed.emit()
	profile_updated.emit()

# Função para logout


# Verificar se usuário está autenticado
func is_authenticated() -> bool:
	return auth_token != "" and user_id != ""

# Carregar sessão salva ao iniciar o jogo - CORREÇÃO: SEMPRE retornar false para não fazer login automático
func load_saved_session() -> bool:
	var config = ConfigFile.new()
	var error = config.load("user://session_data.cfg")
	
	if error != OK:
		print("ℹ️  Nenhuma sessão anterior encontrada")
		return false
	
	if config.has_section_key("session", "auth_token") and config.has_section_key("session", "user_id"):
		auth_token = config.get_value("session", "auth_token")
		user_id = config.get_value("session", "user_id")
		user_name = config.get_value("session", "user_name", "")
		email = config.get_value("session", "email", "")
		profile_image = config.get_value("session", "profile_image", "")
		
		print("=== SESSION MANAGER - SESSÃO CARREGADA (APENAS PARA REFERÊNCIA) ===")
		print("User ID: ", user_id)
		print("Username: ", user_name)
		print("Token carregado: ", auth_token.length() > 0)
		
		# CORREÇÃO CRÍTICA: NUNCA retornar true para evitar login automático
		# Apenas carregamos os dados para referência, mas não consideramos autenticado
		print("⚠️  Sessão carregada apenas para referência - login automático DESABILITADO")
		return false
	
	print("❌ Sessão inválida ou expirada")
	return false

# CORREÇÃO: Nova função para obter email salvo (para preencher campo de email)
func get_saved_email() -> String:
	var config = ConfigFile.new()
	var error = config.load("user://session_data.cfg")
	
	if error != OK:
		return ""
	
	return config.get_value("session", "email", "")

# CORREÇÃO: Nova função para verificar se existe sessão salva (sem autenticar)
func has_saved_session() -> bool:
	var config = ConfigFile.new()
	var error = config.load("user://session_data.cfg")
	
	if error != OK:
		return false
	
	return config.has_section_key("session", "auth_token") and config.has_section_key("session", "user_id")

# Salvar dados da sessão localmente
func _save_session_data() -> void:
	var config = ConfigFile.new()
	
	config.set_value("session", "auth_token", auth_token)
	config.set_value("session", "user_id", user_id)
	config.set_value("session", "user_name", user_name)
	config.set_value("session", "email", email)
	config.set_value("session", "profile_image", profile_image)
	
	var error = config.save("user://session_data.cfg")
	if error == OK:
		print("💾 Dados da sessão salvos localmente")
	else:
		print("❌ Erro ao salvar dados da sessão: ", error)

# Limpar dados da sessão salvos
func _clear_session_data() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		if dir.file_exists("user://session_data.cfg"):
			var error = dir.remove("user://session_data.cfg")
			if error == OK:
				print("🧹 Dados da sessão removidos")
			else:
				print("❌ Erro ao remover dados da sessão: ", error)

# Obter cabeçalhos de autenticação para requisições HTTP
func get_auth_headers() -> PackedStringArray:
	if auth_token == "":
		return ["Content-Type: application/json"]
	else:
		return ["Content-Type: application/json", "Authorization: Bearer " + auth_token]

# Verificar token de autenticação com o servidor
func verify_token() -> bool:
	if not is_authenticated():
		return false
	
	var http_request = HTTPRequest.new()
	get_tree().root.add_child(http_request)
	
	var token_valid = false
	
	http_request.request_completed.connect(func(result, response_code, headers, body):
		token_valid = (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		http_request.queue_free()
		
		if not token_valid:
			print("❌ Token inválido ou expirado")
			# Se o token é inválido, fazer logout automático
			call_deferred("logout")
		else:
			print("✅ Token verificado com sucesso")
	)
	
	var headers = get_auth_headers()
	var error = http_request.request("http://127.0.0.1:5000/me", headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		http_request.queue_free()
		return false
	
	return true

# Função chamada quando o nó é adicionado à cena - CORREÇÃO: Não fazer nada automaticamente
func _ready():
	print("🚀 SessionManager inicializado como autoload")
	
	# CORREÇÃO: NÃO carregar sessão automaticamente
	# Apenas inicializar vazio para forçar login manual
	auth_token = ""
	user_name = ""
	email = ""
	profile_image = ""
	user_id = ""
	
	print("🔐 Login automático DESABILITADO - usuário deve fazer login manualmente")

# Obter dados do usuário em formato de dicionário
func get_user_data() -> Dictionary:
	return {
		"id": user_id,
		"username": user_name,
		"email": email,
		"profile_image": profile_image,
		"auth_token": auth_token
	}

# Debug: imprimir status atual da sessão
func print_session_status() -> void:
	print("=== SESSION MANAGER STATUS ===")
	print("Autenticado: ", is_authenticated())
	print("User ID: ", user_id)
	print("Username: ", user_name)
	print("Email: ", email)
	print("Token: ", "[PRESENT]" if auth_token != "" else "[MISSING]")
	print("Profile Image: ", "[PRESENT]" if profile_image != "" else "[MISSING]")
	print("==============================")

func _safe_get_string(data: Dictionary, key: String, default: String = "") -> String:
	if not data.has(key):
		return default
	
	var value = data[key]
	
	# Verificar se o valor é null, nil ou vazio
	if value == null:
		return default
	if typeof(value) == TYPE_NIL:
		return default
	if str(value) == "Null" or str(value) == "null":
		return default
	
	return str(value)

func logout() -> void:
	print("=== SESSION MANAGER LOGOUT ===")
	print("Fazendo logout do usuário: ", user_name)
	
	# Limpar dados da sessão atual
	auth_token = ""
	user_name = ""
	email = ""
	profile_image = ""
	user_id = ""
	
	# Limpar dados salvos localmente
	_clear_session_data()
	
	# CORREÇÃO: Forçar emissão do sinal user_changed ANTES de logout_successful
	user_changed.emit()
	
	# Pequeno delay para garantir que os outros sistemas processem a mudança
	await get_tree().process_frame
	
	# Emitir sinal de logout
	logout_successful.emit()
	
	print("Logout concluído - sessão limpa")

# CORREÇÃO: Nova função para limpar completamente (útil para troca de usuário)
func clear_completely():
	print("🧹 SESSION MANAGER - Limpeza completa forçada")
	logout()
