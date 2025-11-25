# SettingsManager.gd
extends Node

# Sinais
signal settings_loaded()
signal settings_saved()
signal settings_reset()

# Configurações atuais
var current_settings: Dictionary = {
	"master_volume": 1.0,
	"fx_volume": 1.0,
	"fullscreen": true
}

# Configurações padrão
var default_settings: Dictionary = {
	"master_volume": 1.0,
	"fx_volume": 1.0,
	"fullscreen": true
}

# Referências para os buses de áudio
var master_bus: int
var sfx_bus: int

# Para tocar sons de teste
var test_sound_player: AudioStreamPlayer
var test_sounds_loaded: bool = false

func _ready():
	print("🔧 SettingsManager inicializado")
	
	# Obter índices dos buses de áudio
	master_bus = AudioServer.get_bus_index("Master")
	sfx_bus = AudioServer.get_bus_index("SFX")
	
	# Se o bus SFX não existir, criar
	if sfx_bus == -1:
		print("⚠️  Bus SFX não encontrado, criando...")
		sfx_bus = AudioServer.get_bus_count()
		AudioServer.add_bus(sfx_bus)
		AudioServer.set_bus_name(sfx_bus, "SFX")
	
	# Criar player para sons de teste
	test_sound_player = AudioStreamPlayer.new()
	test_sound_player.bus = "SFX"
	add_child(test_sound_player)
	
	# Tentar carregar sons de teste (sem preload para evitar erros de compilação)
	_load_test_sounds()
	
	# Carregar configurações locais (fallback)
	load_local_settings()
	
	# Aplicar configurações imediatamente
	apply_current_settings()

# NOVA FUNÇÃO: Carregar sons de teste de forma segura
func _load_test_sounds():
	# Esta função tenta carregar os sons, mas não quebra se não existirem
	print("🔊 Tentando carregar sons de teste...")
	test_sounds_loaded = false
	
	# Você pode adicionar seus arquivos de som aqui mais tarde
	# Por enquanto, apenas marcamos que não há sons disponíveis
	print("⚠️  Sons de teste não disponíveis (arquivos não encontrados)")
	print("💡 Para adicionar sons: crie os arquivos res://sounds/test_music.wav e res://sounds/test_fx.wav")

# ===== FUNÇÕES PRINCIPAIS =====

# Carregar configurações do servidor
func load_settings_from_server():
	if not SessionManager or not SessionManager.is_authenticated():
		print("❌ Usuário não autenticado - usando configurações locais")
		apply_current_settings()
		settings_loaded.emit()
		return
	
	print("📥 Carregando configurações do servidor...")
	
	var http_request = HTTPRequest.new()
	get_tree().root.add_child(http_request)
	
	http_request.request_completed.connect(_on_settings_loaded.bind(http_request))
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + SessionManager.auth_token]
	var error = http_request.request("http://127.0.0.1:5000/user-settings", headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		print("❌ Erro ao solicitar configurações")
		http_request.queue_free()
		settings_loaded.emit()

func _on_settings_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	http_request.queue_free()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		
		if parse_result == OK:
			var server_settings = json.get_data()
			
			# Atualizar configurações atuais
			current_settings["master_volume"] = server_settings.get("master_volume", default_settings["master_volume"])
			current_settings["fx_volume"] = server_settings.get("fx_volume", default_settings["fx_volume"])
			current_settings["fullscreen"] = server_settings.get("fullscreen", default_settings["fullscreen"])
			
			print("✅ Configurações carregadas do servidor:")
			print("   - Master Volume: ", current_settings["master_volume"])
			print("   - FX Volume: ", current_settings["fx_volume"])
			print("   - Fullscreen: ", current_settings["fullscreen"])
			
			# Aplicar configurações
			apply_current_settings()
			
			# Salvar localmente como backup
			save_local_settings()
		else:
			print("❌ Erro ao fazer parse das configurações do servidor")
			load_local_settings()
	else:
		print("❌ Falha ao carregar configurações do servidor - Código: ", response_code)
		load_local_settings()
	
	settings_loaded.emit()

# Salvar configurações no servidor
func save_settings_to_server():
	if not SessionManager or not SessionManager.is_authenticated():
		print("❌ Usuário não autenticado - salvando apenas localmente")
		save_local_settings()
		settings_saved.emit()
		return
	
	print("💾 Salvando configurações no servidor...")
	
	var http_request = HTTPRequest.new()
	get_tree().root.add_child(http_request)
	
	http_request.request_completed.connect(_on_settings_saved.bind(http_request))
	
	var payload = {
		"master_volume": current_settings["master_volume"],
		"fx_volume": current_settings["fx_volume"],
		"fullscreen": current_settings["fullscreen"]
	}
	
	var body = JSON.stringify(payload)
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + SessionManager.auth_token]
	
	var error = http_request.request("http://127.0.0.1:5000/user-settings", headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		print("❌ Erro ao enviar configurações")
		http_request.queue_free()
		settings_saved.emit()

func _on_settings_saved(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	http_request.queue_free()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("✅ Configurações salvas no servidor com sucesso")
		
		# Salvar também localmente
		save_local_settings()
	else:
		print("❌ Falha ao salvar configurações no servidor - Código: ", response_code)
		# Salvar localmente como fallback
		save_local_settings()
	
	settings_saved.emit()

# Resetar configurações para padrão
func reset_settings_to_default():
	print("🔄 Resetando configurações para padrão...")
	
	if not SessionManager or not SessionManager.is_authenticated():
		# Apenas resetar localmente
		current_settings = default_settings.duplicate()
		apply_current_settings()
		save_local_settings()
		settings_reset.emit()
		return
	
	# Resetar no servidor
	var http_request = HTTPRequest.new()
	get_tree().root.add_child(http_request)
	
	http_request.request_completed.connect(_on_settings_reset.bind(http_request))
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + SessionManager.auth_token]
	var error = http_request.request("http://127.0.0.1:5000/reset-user-settings", headers, HTTPClient.METHOD_POST)
	
	if error != OK:
		print("❌ Erro ao resetar configurações")
		http_request.queue_free()
		settings_reset.emit()

func _on_settings_reset(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	http_request.queue_free()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		
		if parse_result == OK:
			var response = json.get_data()
			var default_settings_from_server = response.get("default_settings", default_settings)
			
			# Atualizar configurações atuais
			current_settings = default_settings_from_server
			print("✅ Configurações resetadas no servidor")
			
			# Aplicar configurações
			apply_current_settings()
			
			# Salvar localmente
			save_local_settings()
		else:
			print("❌ Erro ao fazer parse do reset")
			_reset_local_settings()
	else:
		print("❌ Falha ao resetar configurações no servidor")
		_reset_local_settings()
	
	settings_reset.emit()

func _reset_local_settings():
	current_settings = default_settings.duplicate()
	apply_current_settings()
	save_local_settings()

# ===== APLICAÇÃO DAS CONFIGURAÇÕES =====

func apply_current_settings():
	print("🎛️  Aplicando configurações atuais...")
	
	# Aplicar volumes de áudio
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(current_settings["master_volume"]))
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(current_settings["fx_volume"]))
	
	# Aplicar mute se volume for 0
	AudioServer.set_bus_mute(master_bus, current_settings["master_volume"] <= 0.001)
	AudioServer.set_bus_mute(sfx_bus, current_settings["fx_volume"] <= 0.001)
	
	# CORREÇÃO DO FULLSCREEN - Usar a API correta do Godot 4
	apply_fullscreen_setting()
	
	print("✅ Configurações aplicadas:")
	print("   - Master Volume: ", current_settings["master_volume"], " (", linear_to_db(current_settings["master_volume"]), " dB)")
	print("   - FX Volume: ", current_settings["fx_volume"], " (", linear_to_db(current_settings["fx_volume"]), " dB)")
	print("   - Fullscreen: ", current_settings["fullscreen"])

# CORREÇÃO: Função específica para fullscreen
func apply_fullscreen_setting():
	if current_settings["fullscreen"]:
		# Modo tela cheia
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("🖥️  Modo tela cheia ativado")
	else:
		# Modo janela
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("🖥️  Modo janela ativado")

# ===== GERENCIAMENTO DE CONFIGURAÇÕES LOCAIS =====

func save_local_settings():
	var config = ConfigFile.new()
	
	config.set_value("audio", "master_volume", current_settings["master_volume"])
	config.set_value("audio", "fx_volume", current_settings["fx_volume"])
	config.set_value("video", "fullscreen", current_settings["fullscreen"])
	
	var error = config.save("user://local_settings.cfg")
	if error == OK:
		print("💾 Configurações salvas localmente")
	else:
		print("❌ Erro ao salvar configurações locais: ", error)

func load_local_settings():
	var config = ConfigFile.new()
	var error = config.load("user://local_settings.cfg")
	
	if error == OK:
		current_settings["master_volume"] = config.get_value("audio", "master_volume", default_settings["master_volume"])
		current_settings["fx_volume"] = config.get_value("audio", "fx_volume", default_settings["fx_volume"])
		current_settings["fullscreen"] = config.get_value("video", "fullscreen", default_settings["fullscreen"])
		
		print("📥 Configurações locais carregadas")
		return true
	else:
		print("⚠️  Nenhuma configuração local encontrada, usando padrão")
		current_settings = default_settings.duplicate()
		return false

# ===== GETTERS E SETTERS =====

func set_master_volume(volume: float):
	current_settings["master_volume"] = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(current_settings["master_volume"]))
	AudioServer.set_bus_mute(master_bus, current_settings["master_volume"] <= 0.001)

func set_fx_volume(volume: float):
	current_settings["fx_volume"] = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(current_settings["fx_volume"]))
	AudioServer.set_bus_mute(sfx_bus, current_settings["fx_volume"] <= 0.001)

func set_fullscreen(enabled: bool):
	current_settings["fullscreen"] = enabled
	apply_fullscreen_setting()

func get_master_volume() -> float:
	return current_settings["master_volume"]

func get_fx_volume() -> float:
	return current_settings["fx_volume"]

func is_fullscreen() -> bool:
	return current_settings["fullscreen"]

# ===== FUNÇÕES DE TESTE DE ÁUDIO =====

# Tocar som de teste para música
func play_music_test():
	if not test_sounds_loaded:
		print("🔇 Sons de teste não disponíveis")
		return
	
	# Esta função será implementada quando você adicionar os sons
	print("💡 Para testar música: adicione res://sounds/test_music.wav")

# Tocar som de teste para efeitos
func play_fx_test():
	if not test_sounds_loaded:
		print("🔇 Sons de teste não disponíveis")
		return
	
	# Esta função será implementada quando você adicionar os sons
	print("💡 Para testar efeitos: adicione res://sounds/test_fx.wav")

# Debug: imprimir configurações atuais
func print_current_settings():
	print("=== CONFIGURAÇÕES ATUAIS ===")
	print("Master Volume: ", current_settings["master_volume"])
	print("FX Volume: ", current_settings["fx_volume"])
	print("Fullscreen: ", current_settings["fullscreen"])
	print("=============================")
