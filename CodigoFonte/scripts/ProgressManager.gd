# ProgressManager.gd
extends Node

var user_progress: Dictionary = {}
var levels_unlocked: Dictionary = {}
var server_available: bool = true
var current_user_id: String = ""

# NOVO: Sistema de prevenção de salvamento duplicado
var save_in_progress: Dictionary = {}  # game_id -> bool
var pending_saves: Array = []

signal progress_loaded(game_id: String)
signal level_access_checked(level_name: String, access_granted: bool)
signal server_status_changed(available: bool)
signal progress_saved(level_name: String, score: int)

func _ready():
	print("🚀 ProgressManager inicializado como autoload")
	
	# CORREÇÃO: Esperar o SessionManager estar pronto antes de conectar
	call_deferred("_initialize")

func _initialize():
	# Conectar ao gerenciador de sessão para detectar mudanças de usuário
	if SessionManager:
		SessionManager.user_changed.connect(_on_user_changed)
		SessionManager.login_successful.connect(_on_user_logged_in)
		SessionManager.logout_successful.connect(_on_user_logged_out)
		print("✅ Conectado ao SessionManager")
	else:
		print("❌ SessionManager não encontrado")
	
	# CORREÇÃO: Forçar limpeza inicial
	force_clear_cache()
	_check_server_status()

# CORREÇÃO: Nova função para quando usuário faz login
func _on_user_logged_in():
	print("🔑 Usuário fez login - carregando progresso")
	current_user_id = SessionManager.user_id
	# Carregar progresso para ambos os jogos
	load_user_progress("1")
	load_user_progress("2")

# Quando o usuário muda, limpar todo o cache
func _on_user_changed():
	print("🔄 Usuário mudou - LIMPEZA COMPLETA de cache de progresso")
	print("📊 Cache antes da limpeza:")
	print("   - user_progress: ", user_progress.size())
	print("   - levels_unlocked: ", levels_unlocked.size())
	print("   - current_user_id: ", current_user_id)
	
	# CORREÇÃO: Limpar profundamente
	user_progress.clear()
	levels_unlocked.clear()
	current_user_id = SessionManager.user_id if SessionManager else ""
	
	# CORREÇÃO: Forçar coleta de lixo se disponível
	if Engine.has_method("get_memory_info"):
		print("🗑️  Forçando coleta de lixo...")
		# Em Godot 4, podemos tentar liberar memória
		OS.low_processor_usage_mode = true
	
	print("🧹 Cache limpo para novo usuário: ", current_user_id)
	print("📊 Cache após limpeza:")
	print("   - user_progress: ", user_progress.size())
	print("   - levels_unlocked: ", levels_unlocked.size())

# Verificar status do servidor
func _check_server_status():
	var http_request = HTTPRequest.new()
	get_tree().root.add_child(http_request)
	
	var request_completed = false
	var server_was_available = server_available
	
	http_request.request_completed.connect(func(result, response_code, headers, body):
		server_available = (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		request_completed = true
		http_request.queue_free()
		
		if server_available != server_was_available:
			server_status_changed.emit(server_available)
			print("🔧 Status do servidor: ", "✅ Disponível" if server_available else "❌ Indisponível")
	)
	
	var error = http_request.request("http://127.0.0.1:5000/health", [], HTTPClient.METHOD_GET)
	if error != OK:
		server_available = false
		http_request.queue_free()
		if server_available != server_was_available:
			server_status_changed.emit(server_available)
			print("🔧 Status do servidor: ❌ Indisponível (erro na requisição)")

# Carregar progresso do usuário para um jogo específico
func load_user_progress(game_id: String = "1"):
	print("📥 Carregando progresso do usuário para jogo: ", game_id)
	
	# CORREÇÃO: Verificar se o usuário está autenticado
	if not SessionManager or not SessionManager.is_authenticated():
		print("❌ Usuário não autenticado - não é possível carregar progresso")
		_ensure_basic_progress(game_id)
		return
	
	# Atualizar ID do usuário atual
	current_user_id = SessionManager.user_id
	
	# Se servidor não está disponível, usar fallback básico
	if not server_available:
		print("⚠️  Servidor indisponível, usando progresso básico")
		_ensure_basic_progress(game_id)
		return
	
	var http_request = HTTPRequest.new()
	get_tree().root.add_child(http_request)
	http_request.request_completed.connect(_on_progress_loaded.bind(http_request, game_id))
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + SessionManager.auth_token]
	var url = "http://127.0.0.1:5000/user-progress?game_id=" + game_id
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("❌ Erro ao solicitar progresso do usuário")
		http_request.queue_free()
		_ensure_basic_progress(game_id)

func _on_progress_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest, game_id: String):
	http_request.queue_free()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		
		if parse_result == OK:
			var response = json.get_data()
			
			# ✅ CORREÇÃO CRÍTICA: Debug detalhado da resposta
			print("📥 RESPOSTA CRUA DO BACKEND PARA JOGO ", game_id, ":")
			print("   - total_levels: ", response.get("total_levels", "NÃO ENCONTRADO"))
			print("   - completed_levels: ", response.get("completed_levels", "NÃO ENCONTRADO"))
			print("   - next_level: ", response.get("next_level", "NÃO ENCONTRADO"))
			
			user_progress[game_id] = response
			levels_unlocked[game_id] = []
			
			# ✅ CORREÇÃO CRÍTICA: Coletar níveis desbloqueados de forma mais robusta
			var levels_array = response.get("levels", [])
			print("   - Níveis recebidos do backend: ", levels_array.size())
			
			# Debug de cada nível
			for i in range(levels_array.size()):
				var level_data = levels_array[i]
				print("      [", i, "] ", level_data.get("name", "sem_nome"), 
					" - unlocked: ", level_data.get("unlocked", false),
					" - completed: ", level_data.get("completed", false))
			
			# ✅ CORREÇÃO CRÍTICA: Se o backend retornou menos de 10 níveis, completar com os faltantes
			if levels_array.size() < 10:
				print("⚠️  BACKEND RETORNOU APENAS ", levels_array.size(), " NÍVEIS! COMPLETANDO COM NÍVEIS FALTANTES...")
				_completar_niveis_faltantes(game_id, levels_array, response)
			
			# Coletar níveis desbloqueados para este jogo
			for level_data in levels_array:
				if level_data.get("unlocked", false) or level_data.get("completed", false):
					var level_name = level_data.get("name")
					if level_name and not level_name in levels_unlocked[game_id]:
						levels_unlocked[game_id].append(level_name)
			
			# ✅ CORREÇÃO CRÍTICA: Garantir que o próximo nível após o último concluído esteja desbloqueado
			_desbloquear_proximo_nivel_automaticamente(game_id)
			
			print("✅ Progresso carregado para jogo ", game_id)
			print("🎯 Níveis desbloqueados: ", levels_unlocked[game_id])
			print("📊 Níveis concluídos: ", response.get("completed_levels", 0), "/10")  # ✅ SEMPRE 10 níveis
			
			progress_loaded.emit(game_id)
		else:
			print("❌ Erro ao fazer parse do JSON de progresso")
			print("   Body: ", body.get_string_from_utf8())
			_setup_empty_progress(game_id)
	else:
		print("❌ Falha ao carregar progresso - Código: ", response_code)
		print("   Body: ", body.get_string_from_utf8())
		_setup_empty_progress(game_id)

# CORREÇÃO: Nova função para configurar progresso vazio sem dados falsos
func _setup_empty_progress(game_id: String):
	print("🔄 Configurando progresso vazio para jogo: ", game_id)
	
	# Apenas garantir que as estruturas existem, mas vazias
	if not user_progress.has(game_id):
		user_progress[game_id] = {
			"game_id": game_id,
			"total_levels": 10,  # ✅ CORREÇÃO: Sempre 10 níveis
			"completed_levels": 0,
			"next_level": "nivel1" if game_id == "1" else "arvore_binaria_nivel1",
			"levels": []  # ← Lista vazia de níveis
		}
	
	if not levels_unlocked.has(game_id):
		levels_unlocked[game_id] = []
	
	# ✅ CORREÇÃO: Apenas o primeiro nível deve estar desbloqueado
	var first_level = "nivel1" if game_id == "1" else "arvore_binaria_nivel1"
	if not first_level in levels_unlocked[game_id]:
		levels_unlocked[game_id].append(first_level)
		print("🔓 Primeiro nível disponível: ", first_level)
	
	progress_loaded.emit(game_id)

# Garantir progresso básico quando não há dados
func _ensure_basic_progress(game_id: String):
	print("🛡️  Configurando progresso básico para jogo: ", game_id)
	
	if not user_progress.has(game_id):
		user_progress[game_id] = {
			"game_id": game_id,
			"total_levels": 10,  # ✅ CORREÇÃO: Sempre 10 níveis
			"completed_levels": 0,
			"next_level": "nivel1" if game_id == "1" else "arvore_binaria_nivel1",
			"levels": []
		}
	
	if not levels_unlocked.has(game_id):
		levels_unlocked[game_id] = []
	
	# Garantir que pelo menos o primeiro nível está desbloqueado
	var first_level = "nivel1" if game_id == "1" else "arvore_binaria_nivel1"
	if not first_level in levels_unlocked[game_id]:
		levels_unlocked[game_id].append(first_level)
		print("✅ Primeiro nível garantido: ", first_level)
	
	progress_loaded.emit(game_id)

# Verificação de acesso ao nível
func has_access_to_level(level_name: String, game_id: String) -> bool:
	print("🔍 Verificando acesso para: ", level_name, " no jogo: ", game_id)
	
	# Primeiro nível sempre disponível
	if level_name == "nivel1" or level_name == "arvore_binaria_nivel1":
		print("✅ Primeiro nível sempre disponível: ", level_name)
		return true
	
	# Se não temos dados para este jogo, tentar carregar
	if not user_progress.has(game_id) or not levels_unlocked.has(game_id):
		print("⚠️  Dados do jogo não carregados para: ", game_id)
		load_user_progress(game_id)
		return false
	
	# ✅ CORREÇÃO: Verificar se está na lista de desbloqueados
	if level_name in levels_unlocked[game_id]:
		print("✅ Acesso concedido (nível desbloqueado): ", level_name)
		return true
	
	# ✅ CORREÇÃO: Verificar lógica de progressão linear
	var level_prefix = "nivel" if game_id == "1" else "arvore_binaria_nivel"
	var current_level_num = level_name.replace(level_prefix, "").to_int()
	
	if current_level_num > 1:
		var previous_level_name = level_prefix + str(current_level_num - 1)
		var previous_level_data = get_level_data(previous_level_name, game_id)
		
		if previous_level_data and previous_level_data.get("completed", false):
			print("✅ Acesso concedido (nível anterior concluído): ", level_name)
			# Adicionar automaticamente aos desbloqueados
			if not level_name in levels_unlocked[game_id]:
				levels_unlocked[game_id].append(level_name)
			return true
	
	print("❌ Acesso negado: ", level_name)
	return false

# Verificação se nível está desbloqueado (compatibilidade)
func is_level_unlocked(level_name: String) -> bool:
	var game_id = "2" if "arvore_binaria" in level_name else "1"
	return has_access_to_level(level_name, game_id)

# Obter dados de um nível específico
func get_level_data(level_name: String, game_id: String) -> Dictionary:
	if user_progress.has(game_id):
		for level_data in user_progress[game_id].get("levels", []):
			if level_data.get("name") == level_name:
				return level_data
	return {}

# Verificação assíncrona para UI
func check_level_access(level_name: String, game_id: String = ""):
	if game_id == "":
		game_id = "2" if "arvore_binaria" in level_name else "1"
	
	print("🔍 Verificando acesso assíncrono para: ", level_name, " no jogo: ", game_id)
	
	# Verificação local primeiro
	if has_access_to_level(level_name, game_id):
		print("✅ Acesso concedido (verificação local)")
		level_access_checked.emit(level_name, true)
		return
	
	# Se não tem acesso local, verificar com servidor
	if not SessionManager or SessionManager.auth_token == "":
		print("❌ Usuário não autenticado")
		level_access_checked.emit(level_name, false)
		return
	
	# Se servidor não está disponível, negar acesso
	if not server_available:
		print("❌ Servidor indisponível")
		level_access_checked.emit(level_name, false)
		return
	
	var http_request = HTTPRequest.new()
	get_tree().root.add_child(http_request)
	http_request.request_completed.connect(_on_level_access_checked.bind(http_request, level_name, game_id))
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + SessionManager.auth_token]
	var url = "http://127.0.0.1:5000/check-level-access?level_name=" + level_name + "&game_id=" + game_id
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("❌ Erro ao verificar acesso ao nível")
		level_access_checked.emit(level_name, false)
		http_request.queue_free()

func _on_level_access_checked(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest, level_name: String, game_id: String):
	http_request.queue_free()
	
	var access_granted = false
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		
		if parse_result == OK:
			var response = json.get_data()
			access_granted = response.get("access_granted", false)
			
			if access_granted:
				if not levels_unlocked.has(game_id):
					levels_unlocked[game_id] = []
				if not level_name in levels_unlocked[game_id]:
					levels_unlocked[game_id].append(level_name)
				print("✅ Acesso concedido pelo servidor: ", level_name)
			else:
				print("❌ Acesso negado: ", response.get("reason", "Nível anterior não concluído"))
		else:
			print("❌ Erro ao fazer parse do JSON de verificação de acesso")
	else:
		print("❌ Erro na verificação de acesso - Código: ", response_code)
	
	level_access_checked.emit(level_name, access_granted)

# CORREÇÃO CRÍTICA: Sistema de salvamento com prevenção de duplicação
func mark_level_completed(level_name: String, score: int):
	var game_id = "2" if "arvore_binaria" in level_name else "1"
	print("🎉 Marcando nível como concluído: ", level_name, " no jogo: ", game_id, " com score: ", score)
	
	# CORREÇÃO CRÍTICA: Verificar se já está salvando
	if save_in_progress.get(game_id, false):
		print("⚠️  Salvamento já em andamento para jogo ", game_id, " - Adicionando à fila")
		pending_saves.push_back({"level": level_name, "score": score, "game_id": game_id})
		return
	
	# Marcar como salvamento em andamento
	save_in_progress[game_id] = true
	
	# CORREÇÃO: Primeiro enviar para o servidor, depois atualizar localmente
	_save_score_to_server(level_name, score, game_id)

# CORREÇÃO: Nova função para salvar pontuação no servidor
func _save_score_to_server(level_name: String, score: int, game_id: String):
	if not SessionManager or not SessionManager.is_authenticated():
		print("❌ Usuário não autenticado - não é possível salvar progresso")
		save_in_progress[game_id] = false
		_process_pending_saves()
		return
	
	if not server_available:
		print("❌ Servidor indisponível - não é possível salvar progresso")
		save_in_progress[game_id] = false
		_process_pending_saves()
		return
	
	var http_request = HTTPRequest.new()
	get_tree().root.add_child(http_request)
	
	# CORREÇÃO: Conectar o sinal ANTES de fazer a requisição
	http_request.request_completed.connect(_on_score_saved.bind(http_request, level_name, score, game_id))
	
	var payload = {
		"level": level_name,
		"score": score
	}
	
	var body = JSON.stringify(payload)
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + SessionManager.auth_token]
	
	print("📤 ENVIANDO PONTUAÇÃO ÚNICA: ", level_name, " - Score: ", score)
	
	var error = http_request.request("http://127.0.0.1:5000/save-score", headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("❌ Erro ao enviar pontuação para o servidor")
		save_in_progress[game_id] = false
		_process_pending_saves()
		http_request.queue_free()

func _on_score_saved(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest, level_name: String, score: int, game_id: String):
	http_request.queue_free()
	
	# Liberar o bloqueio de salvamento
	save_in_progress[game_id] = false
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("✅ Pontuação salva no servidor com sucesso - LEVEL: ", level_name, " SCORE: ", score)
		
		# CORREÇÃO: Atualizar cache local apenas após confirmação do servidor
		_update_local_progress(level_name, score, game_id)
		
		# CORREÇÃO CRÍTICA: Emitir sinal APENAS UMA VEZ
		progress_saved.emit(level_name, score)
		
		# Recarregar progresso do servidor para garantir sincronização
		call_deferred("_reload_progress", game_id)
	else:
		print("❌ Falha ao salvar pontuação no servidor - Código: ", response_code)
		
		# ✅ CORREÇÃO: Mostrar detalhes do erro
		var response_body = body.get_string_from_utf8()
		print("🔍 Detalhes do erro: ", response_body)
		
		# ✅ CORREÇÃO: Mesmo com erro no servidor, atualizar localmente
		# para que o usuário veja o progresso imediatamente
		print("🔄 Atualizando progresso localmente apesar do erro do servidor")
		_update_local_progress(level_name, score, game_id)
		progress_saved.emit(level_name, score)
	
	# Processar salvamentos pendentes
	_process_pending_saves()

# NOVO: Processar salvamentos na fila
func _process_pending_saves():
	if pending_saves.size() > 0:
		var next_save = pending_saves.pop_front()
		print("🔄 Processando salvamento pendente: ", next_save.level, " - Score: ", next_save.score)
		call_deferred("mark_level_completed", next_save.level, next_save.score)

# CORREÇÃO: Nova função para atualizar progresso local
func _update_local_progress(level_name: String, score: int, game_id: String):
	# Atualizar cache local
	if not user_progress.has(game_id):
		user_progress[game_id] = {
			"game_id": game_id,
			"total_levels": 10,
			"completed_levels": 0,
			"next_level": "",
			"levels": []
		}
	
	# Verificar se o nível já existe nos dados
	var level_found = false
	for level_data in user_progress[game_id].get("levels", []):
		if level_data.get("name") == level_name:
			level_data["completed"] = true
			level_data["score"] = score
			level_data["unlocked"] = true
			level_found = true
			break
	
	# Se não encontrou, adicionar novo nível
	if not level_found:
		user_progress[game_id]["levels"].append({
			"name": level_name,
			"completed": true,
			"score": score,
			"unlocked": true
		})
	
	# Atualizar contagem de níveis concluídos
	var completed_count = 0
	for level_data in user_progress[game_id].get("levels", []):
		if level_data.get("completed", false):
			completed_count += 1
	user_progress[game_id]["completed_levels"] = completed_count
	
	# Adicionar à lista de desbloqueados
	if not levels_unlocked.has(game_id):
		levels_unlocked[game_id] = []
	
	if not level_name in levels_unlocked[game_id]:
		levels_unlocked[game_id].append(level_name)
	
	# DESBLOQUEAR AUTOMATICAMENTE O PRÓXIMO NÍVEL
	var next_level_name = _get_next_level_name(level_name, game_id)
	if next_level_name != "" and not next_level_name in levels_unlocked[game_id]:
		levels_unlocked[game_id].append(next_level_name)
		print("🔓 Próximo nível desbloqueado automaticamente: ", next_level_name)

# Obter o nome do próximo nível
func _get_next_level_name(level_name: String, game_id: String) -> String:
	if game_id == "1":
		# Para Jogo 1: nivel1, nivel2, ..., nivel10
		var current_number = level_name.replace("nivel", "").to_int()
		if current_number < 10:
			return "nivel" + str(current_number + 1)
	else:
		# Para Jogo 2: arvore_binaria_nivel1, arvore_binaria_nivel2, ...
		var current_number = level_name.replace("arvore_binaria_nivel", "").to_int()
		if current_number < 10:
			return "arvore_binaria_nivel" + str(current_number + 1)
	
	return ""

func _reload_progress(game_id: String):
	# Recarregar do servidor para garantir dados atualizados
	if server_available and SessionManager and SessionManager.is_authenticated():
		print("🔄 Recarregando progresso do servidor para jogo: ", game_id)
		load_user_progress(game_id)

# Forçar atualização do status do servidor
func refresh_server_status():
	print("🔄 Atualizando status do servidor...")
	_check_server_status()

# Verificar se o servidor está disponível
func is_server_available() -> bool:
	return server_available

# Limpar todo o cache (útil para logout)
func clear_cache():
	print("🧹 Limpando cache completo do ProgressManager")
	user_progress.clear()
	levels_unlocked.clear()
	current_user_id = ""
	
	# CORREÇÃO: Limpar também o sistema de salvamento
	save_in_progress.clear()
	pending_saves.clear()
	
	print("✅ Cache limpo - pronto para novo usuário")

func force_clear_cache():
	print("💥 FORÇANDO LIMPEZA COMPLETA DO CACHE")
	user_progress.clear()
	levels_unlocked.clear()
	current_user_id = ""
	save_in_progress.clear()
	pending_saves.clear()
	
	# CORREÇÃO: Também limpar quaisquer requisições HTTP pendentes
	for child in get_children():
		if child is HTTPRequest:
			child.queue_free()
	
	print("✅ Cache forçado a limpar")

func _on_user_logged_out():
	print("🚪 Usuário fez logout - limpando cache")
	force_clear_cache()




func debug_backend_response():
	if not SessionManager or not SessionManager.is_authenticated():
		print("❌ Usuário não autenticado para debug")
		return
	
	print("🐛 INICIANDO DEBUG DO BACKEND...")
	
	var http_request = HTTPRequest.new()
	get_tree().root.add_child(http_request)
	
	http_request.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		http_request.queue_free()
		
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var json = JSON.new()
			var parse_result = json.parse(body.get_string_from_utf8())
			
			if parse_result == OK:
				var response = json.get_data()
				print("🐛 DEBUG BACKEND - RESPOSTA COMPLETA:")
				print("   total_levels: ", response.get("total_levels"))
				print("   completed_levels: ", response.get("completed_levels")) 
				print("   next_level: ", response.get("next_level"))
				print("   levels count: ", response.get("levels", []).size())
				
				var levels = response.get("levels", [])
				for i in range(levels.size()):
					var level = levels[i]
					print("   [", i, "] ", level.get("name"), " - unlocked: ", level.get("unlocked"), " - completed: ", level.get("completed"))
			else:
				print("❌ DEBUG: Erro ao parsear JSON")
		else:
			print("❌ DEBUG: Erro na requisição - Código: ", response_code)
	)
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + SessionManager.auth_token]
	var error = http_request.request("http://127.0.0.1:5000/user-progress?game_id=1", headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("❌ DEBUG: Erro ao fazer requisição de debug")


# ✅ NOVA FUNÇÃO: Completar níveis faltantes quando o backend retorna menos de 10
func _completar_niveis_faltantes(game_id: String, levels_array: Array, response: Dictionary):
	var completed_levels_count = response.get("completed_levels", 0)
	var next_level_name = response.get("next_level", "")
	
	print("🔄 Completando níveis faltantes para jogo ", game_id)
	print("   - Níveis concluídos: ", completed_levels_count)
	print("   - Próximo nível: ", next_level_name)
	
	# Determinar prefixo dos níveis baseado no game_id
	var level_prefix = "nivel" if game_id == "1" else "arvore_binaria_nivel"
	
	# Para cada nível de 1 a 10, verificar se existe na resposta
	for level_num in range(1, 11):
		var level_name = level_prefix + str(level_num)
		var level_exists = false
		
		# Verificar se o nível já existe no array
		for existing_level in levels_array:
			if existing_level.get("name") == level_name:
				level_exists = true
				break
		
		# Se não existe, adicionar
		if not level_exists:
			print("   + Adicionando nível faltante: ", level_name)
			
			# ✅ CORREÇÃO: Novo usuário - apenas o primeiro nível deve estar desbloqueado
			var should_unlock = (level_num == 1)  # Apenas nível 1 desbloqueado para novos usuários
			
			var new_level_data = {
				"name": level_name,
				"completed": false,
				"unlocked": should_unlock,
				"score": 0,
				"order": level_num
			}
			levels_array.append(new_level_data)
	
	# Atualizar a resposta com os níveis completos
	response["levels"] = levels_array
	response["total_levels"] = 10  # ✅ SEMPRE 10 níveis totais

# ✅ NOVA FUNÇÃO: Desbloquear automaticamente o próximo nível após o último concluído
func _desbloquear_proximo_nivel_automaticamente(game_id: String):
	if not user_progress.has(game_id) or not levels_unlocked.has(game_id):
		return
	
	var levels_array = user_progress[game_id].get("levels", [])
	var level_prefix = "nivel" if game_id == "1" else "arvore_binaria_nivel"
	
	# Encontrar o último nível concluído
	var last_completed_level = 0
	for level_data in levels_array:
		if level_data.get("completed", false):
			var level_name = level_data.get("name", "")
			var level_num = level_name.replace(level_prefix, "").to_int()
			if level_num > last_completed_level:
				last_completed_level = level_num
	
	print("🎯 Último nível concluído encontrado: ", last_completed_level)
	
	# ✅ CORREÇÃO CRÍTICA: Só desbloquear níveis adicionais se houver níveis concluídos
	if last_completed_level == 0:
		print("🔒 Nenhum nível concluído - mantendo apenas o primeiro nível desbloqueado")
		# Garantir que apenas o primeiro nível está desbloqueado
		var first_level = level_prefix + "1"
		if not first_level in levels_unlocked[game_id]:
			levels_unlocked[game_id].append(first_level)
		
		# Remover qualquer outro nível que possa ter sido adicionado erroneamente
		var levels_to_remove = []
		for level_name in levels_unlocked[game_id]:
			if level_name != first_level:
				levels_to_remove.append(level_name)
		
		for level_name in levels_to_remove:
			levels_unlocked[game_id].erase(level_name)
			print("🔒 Removendo nível desbloqueado erroneamente: ", level_name)
	else:
		# ✅ CORREÇÃO: Desbloquear todos os níveis até o próximo após o último concluído
		for level_num in range(1, last_completed_level + 2):  # +2 para incluir o próximo nível
			if level_num > 10:  # Não passar do nível 10
				break
				
			var level_name = level_prefix + str(level_num)
			
			# Adicionar à lista de desbloqueados se não estiver lá
			if not level_name in levels_unlocked[game_id]:
				levels_unlocked[game_id].append(level_name)
				print("🔓 DESBLOQUEANDO NÍVEL: ", level_name)
			
			# Atualizar também no array de levels
			var level_found = false
			for level_data in levels_array:
				if level_data.get("name") == level_name:
					level_data["unlocked"] = true
					level_found = true
					break
			
			# Se não encontrou nos levels existentes, adicionar
			if not level_found:
				var new_level_data = {
					"name": level_name,
					"completed": false,
					"unlocked": true,
					"score": 0,
					"order": level_num
				}
				levels_array.append(new_level_data)
				print("➕ Adicionando nível faltante aos dados: ", level_name)
	
	print("🔓 Níveis desbloqueados finais: ", levels_unlocked[game_id])
