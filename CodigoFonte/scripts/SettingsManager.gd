# SettingsManager.gd
extends Node

# Sinais
signal settings_loaded()
signal settings_saved()
signal settings_reset()
signal audio_tested(bus: String)
signal background_music_started()
signal background_music_stopped()

# Configurações atuais - VOLUME PADRÃO 20%
var current_settings: Dictionary = {
	"master_volume": 0.2,  # 20% volume padrão
	"fx_volume": 1.0,
	"fullscreen": true
}

# Configurações padrão - VOLUME PADRÃO 20%
var default_settings: Dictionary = {
	"master_volume": 0.2,  # 20% volume padrão
	"fx_volume": 1.0,
	"fullscreen": false
}

# Referências para os buses de áudio
var master_bus: int
var sfx_bus: int

# Players de áudio
var music_test_player: AudioStreamPlayer
var fx_test_player: AudioStreamPlayer
var background_music_player: AudioStreamPlayer

# Streams de áudio carregados
var test_music_stream: AudioStreamWAV
var test_fx_stream: AudioStreamWAV

# Controle de música de fundo
var is_background_music_playing: bool = false
var current_music_path: String = ""
var music_timer: Timer
var button_sound_enabled: bool = true
var connected_buttons: Array = []

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
	
	setup_global_button_sounds()
	# Configurar os buses de áudio
	_setup_audio_buses()
	
	# Criar players para sons
	_setup_audio_players()
	
	# Carregar sons de teste
	_load_audio_files()
	
	# Carregar configurações locais (fallback)
	load_local_settings()
	
	# Aplicar configurações imediatamente
	apply_current_settings()
	
	# Configurar timer para música de fundo
	_setup_music_timer()

# Configurar timer para música de fundo
func _setup_music_timer():
	music_timer = Timer.new()
	music_timer.name = "BackgroundMusicTimer"
	music_timer.one_shot = true
	music_timer.timeout.connect(_on_music_timer_timeout)
	add_child(music_timer)
	print("⏰ Timer de música de fundo configurado")

func _on_music_timer_timeout():
	if is_background_music_playing:
		print("🔁 Timer de música ativado - reiniciando música...")
		background_music_player.play()
		
		# Reiniciar o timer para a próxima execução (4 minutos = 240 segundos)
		music_timer.start(240.0)
		print("⏰ Próxima execução em 4 minutos")

# Configurar os buses de áudio
func _setup_audio_buses():
	print("🎛️  Configurando buses de áudio...")
	
	# Configurar o bus Master
	AudioServer.set_bus_send(master_bus, "Master")
	
	# Configurar o bus SFX para enviar para Master
	AudioServer.set_bus_send(sfx_bus, "Master")
	
	print("✅ Buses de áudio configurados:")
	print("   - Master Bus: ", master_bus)
	print("   - SFX Bus: ", sfx_bus)

# Configurar players de áudio
func _setup_audio_players():
	print("🎵 Configurando players de áudio...")
	
	# Player para teste de música (usa bus Master)
	music_test_player = AudioStreamPlayer.new()
	music_test_player.name = "MusicTestPlayer"
	music_test_player.bus = "Master"
	add_child(music_test_player)
	
	# Player para teste de efeitos (usa bus SFX)
	fx_test_player = AudioStreamPlayer.new()
	fx_test_player.name = "FXTestPlayer" 
	fx_test_player.bus = "SFX"
	add_child(fx_test_player)
	
	# Player para música de fundo
	background_music_player = AudioStreamPlayer.new()
	background_music_player.name = "BackgroundMusicPlayer"
	background_music_player.bus = "Master"
	
	# Remover conexão do sinal finished
	if background_music_player.finished.is_connected(_on_background_music_finished):
		background_music_player.finished.disconnect(_on_background_music_finished)
	
	add_child(background_music_player)
	
	print("✅ Players de áudio configurados")

# Carregar arquivos de áudio
func _load_audio_files():
	print("📁 Carregando arquivos de áudio...")
	
	# Verificar se os arquivos existem antes de carregar
	if FileAccess.file_exists("res://sounds/test_music.wav"):
		test_music_stream = load("res://sounds/test_music.wav")
		if test_music_stream:
			print("✅ Som de música carregado: res://sounds/test_music.wav")
			print("   - Duração: ", test_music_stream.get_length(), " segundos")
			music_test_player.stream = test_music_stream
		else:
			print("❌ Erro ao carregar: res://sounds/test_music.wav")
	else:
		print("❌ Arquivo não encontrado: res://sounds/test_music.wav")
	
	if FileAccess.file_exists("res://sounds/test_fx.wav"):
		test_fx_stream = load("res://sounds/test_fx.wav")
		if test_fx_stream:
			print("✅ Som de efeitos carregado: res://sounds/test_fx.wav")
			fx_test_player.stream = test_fx_stream
		else:
			print("❌ Erro ao carregar: res://sounds/test_fx.wav")
	else:
		print("❌ Arquivo não encontrado: res://sounds/test_fx.wav")

# ===== MÚSICA DE FUNDO COM TIMER =====

func play_background_music(music_path: String = "", loop: bool = true) -> bool:
	if music_path == "":
		music_path = "res://sounds/test_music.wav"
	
	print("🎵 Iniciando música de fundo: ", music_path)
	
	# Verificar se o arquivo existe
	if not FileAccess.file_exists(music_path):
		print("❌ Arquivo de música não encontrado: ", music_path)
		return false
	
	# Parar música atual se estiver tocando
	if is_background_music_playing:
		stop_background_music()
	
	# Carregar stream
	var music_stream = load(music_path)
	if not music_stream:
		print("❌ Erro ao carregar música de fundo: ", music_path)
		return false
	
	# Salvar o caminho atual
	current_music_path = music_path
	
	# Configurar player
	background_music_player.stream = music_stream
	
	# Remover qualquer conexão anterior do sinal finished
	if background_music_player.finished.is_connected(_on_background_music_finished):
		background_music_player.finished.disconnect(_on_background_music_finished)
	
	# Configurar loop usando Timer
	if loop:
		print("   - Modo: LOOP (via Timer)")
		
		# Iniciar timer para 4 minutos (240 segundos)
		music_timer.start(240.0)
		print("⏰ Timer iniciado: 4 minutos")
	else:
		print("   - Modo: UMA VEZ")
		music_timer.stop()
	
	# Reproduzir
	background_music_player.play()
	is_background_music_playing = true
	
	print("✅ Música de fundo iniciada:")
	print("   - Volume: ", AudioServer.get_bus_volume_db(master_bus), " dB")
	print("   - Loop: ", loop)
	print("   - Estado: ", "TOCANDO" if background_music_player.playing else "PARADO")
	print("   - Duração: ", music_stream.get_length(), " segundos")
	
	background_music_started.emit()
	return true

# Função antiga (mantida por compatibilidade, mas não usada)
func _on_background_music_finished():
	# Esta função não é mais usada - o loop é controlado pelo Timer
	pass

func stop_background_music():
	if is_background_music_playing:
		background_music_player.stop()
		music_timer.stop()
		is_background_music_playing = false
		current_music_path = ""
		print("⏹️  Música de fundo parada")
		background_music_stopped.emit()

func toggle_background_music():
	if is_background_music_playing:
		stop_background_music()
	else:
		if current_music_path != "":
			play_background_music(current_music_path, true)
		else:
			play_background_music("res://sounds/test_music.wav", true)

func get_background_music_status() -> Dictionary:
	return {
		"playing": is_background_music_playing,
		"current_path": current_music_path,
		"volume_db": AudioServer.get_bus_volume_db(master_bus),
		"time_remaining": music_timer.time_left if music_timer else 0
	}

# Função para ajustar o intervalo do timer (se necessário)
func set_music_interval(seconds: float):
	if music_timer and music_timer.time_left > 0:
		var remaining = music_timer.time_left
		music_timer.start(seconds)
		print("⏰ Intervalo da música ajustado para ", seconds, " segundos")
		print("   - Tempo anterior restante: ", remaining, " segundos")

# Resto do código permanece igual...

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
	
	# CORREÇÃO DO FULLSCREEN - Apenas aplicar se não estiver no editor
	if not Engine.is_editor_hint():
		apply_fullscreen_setting()
	else:
		print("🖥️  Editor Godot - Fullscreen ignorado")
	
	print("✅ Configurações aplicadas:")
	print("   - Master Volume: ", current_settings["master_volume"], " (", linear_to_db(current_settings["master_volume"]), " dB)")
	print("   - FX Volume: ", current_settings["fx_volume"], " (", linear_to_db(current_settings["fx_volume"]), " dB)")
	print("   - Fullscreen: ", current_settings["fullscreen"])

# CORREÇÃO: Fullscreen apenas fora do editor
func apply_fullscreen_setting():
	if not Engine.is_editor_hint():
		if current_settings["fullscreen"]:
			# Salvar a posição e tamanho atual da janela antes de entrar em fullscreen
			var previous_position = DisplayServer.window_get_position()
			var previous_size = DisplayServer.window_get_size()
			
			# Entrar em fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			
			# Configurar o scaling para manter a proporção (como zoom)
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
			get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
			get_tree().root.content_scale_size = previous_size  # Manter o tamanho base da interface
			
			print("🖥️  Fullscreen ativado (modo zoom)")
			print("   - Tamanho base mantido: ", previous_size)
			print("   - Tamanho da tela: ", DisplayServer.screen_get_size())
			
		else:
			# Sair do fullscreen e restaurar tamanho/posição anteriores
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			
			# Restaurar tamanho e posição (você pode ajustar esses valores)
			DisplayServer.window_set_size(Vector2(1152, 648))
			
			# Centralizar na tela
			var screen_size = DisplayServer.screen_get_size()
			var window_size = Vector2(1152, 648)
			var centered_position = (screen_size - window_size) / 2
			DisplayServer.window_set_position(centered_position)
			
			# Resetar scaling
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			
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
	# Converter de 0-100 para 0-1 se necessário
	var normalized_volume = volume
	if volume > 1.0:  # Se está em escala 0-100
		normalized_volume = volume / 100.0
	
	current_settings["master_volume"] = clamp(normalized_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(current_settings["master_volume"]))
	AudioServer.set_bus_mute(master_bus, current_settings["master_volume"] <= 0.001)

func set_fx_volume(volume: float):
	# Converter de 0-100 para 0-1 se necessário
	var normalized_volume = volume
	if volume > 1.0:  # Se está em escala 0-100
		normalized_volume = volume / 100.0
	
	current_settings["fx_volume"] = clamp(normalized_volume, 0.0, 1.0)
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

# ===== SISTEMA DE ÁUDIO =====

# Tocar som de teste para música
func play_music_test():
	if test_music_stream and music_test_player:
		print("🔊 Tocando teste de música no bus Master...")
		music_test_player.play()
		audio_tested.emit("Master")
	else:
		print("❌ Não foi possível tocar teste de música")

# Tocar som de teste para efeitos
func play_fx_test():
	if test_fx_stream and fx_test_player:
		print("🔊 Tocando teste de efeitos no bus SFX...")
		fx_test_player.play()
		audio_tested.emit("SFX")
	else:
		print("❌ Não foi possível tocar teste de efeitos")

# Função para tocar efeitos sonoros em todo o jogo
func play_sound(sound_path: String, bus: String = "SFX") -> bool:
	# Verificar se o arquivo existe
	if not FileAccess.file_exists(sound_path):
		print("❌ Arquivo de som não encontrado: ", sound_path)
		return false
	
	var sound_stream = load(sound_path)
	if sound_stream:
		var player = AudioStreamPlayer.new()
		player.stream = sound_stream
		player.bus = bus
		player.finished.connect(player.queue_free)
		add_child(player)
		player.play()
		print("🔊 Tocando som: ", sound_path, " no bus: ", bus)
		return true
	else:
		print("❌ Erro ao carregar som: ", sound_path)
		return false

# Debug: imprimir configurações atuais
func print_current_settings():
	print("=== CONFIGURAÇÕES ATUAIS ===")
	print("Master Volume: ", current_settings["master_volume"])
	print("FX Volume: ", current_settings["fx_volume"])
	print("Fullscreen: ", current_settings["fullscreen"])
	print("=============================")

# Debug: imprimir status do áudio
func print_audio_status():
	print("=== STATUS DO ÁUDIO ===")
	print("Master Bus Volume: ", AudioServer.get_bus_volume_db(master_bus), " dB")
	print("SFX Bus Volume: ", AudioServer.get_bus_volume_db(sfx_bus), " dB")
	print("Master Bus Mute: ", AudioServer.is_bus_mute(master_bus))
	print("SFX Bus Mute: ", AudioServer.is_bus_mute(sfx_bus))
	print("Test Music Loaded: ", test_music_stream != null)
	print("Test FX Loaded: ", test_fx_stream != null)
	print("Background Music Playing: ", is_background_music_playing)
	print("Current Music Path: ", current_music_path)
	print("Music Timer Active: ", music_timer.time_left > 0 if music_timer else false)
	print("Time Until Next Loop: ", music_timer.time_left if music_timer else 0)
	print("=========================")


# Adicione esta função no SettingsManager.gd
func setup_button_sound(button: BaseButton):
	if button in connected_buttons:
		return
	
	# Verificar se o botão já tem uma conexão
	if not button.pressed.is_connected(_on_any_button_pressed):
		button.pressed.connect(_on_any_button_pressed)
		connected_buttons.append(button)
		
		print("✅ Som configurado para botão: ", button.name)

func _on_button_pressed(button: BaseButton):
	play_sound("res://sounds/test_fx.wav", "SFX")


func setup_global_button_sounds():
	print("🔊 Configurando sons de botão globais...")
	
	# Conectar para detectar novos botões adicionados à cena
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	
	# Conectar botões existentes
	connect_existing_buttons(get_tree().root)

func _on_node_added(node: Node):
	# Verificar se é um botão e conectar
	if node is Button or node is TextureButton:
		setup_button_sound(node as BaseButton)

func connect_existing_buttons(root: Node):
	# Percorrer recursivamente todos os nós
	for child in root.get_children():
		if child is Button or child is TextureButton:
			setup_button_sound(child as BaseButton)
		
		# Continuar percorrendo os filhos
		if child.get_child_count() > 0:
			connect_existing_buttons(child)

# Função para configurar som em um botão específico


func _on_any_button_pressed():
	if button_sound_enabled:
		play_sound("res://sounds/test_fx.wav", "SFX")

# Funções para controlar o sistema
func enable_button_sounds():
	button_sound_enabled = true
	print("🔊 Sons de botão ativados")

func disable_button_sounds():
	button_sound_enabled = false
	print("🔇 Sons de botão desativados")

func toggle_button_sounds():
	button_sound_enabled = not button_sound_enabled
	print("🔊 Sons de botão: ", "ATIVADOS" if button_sound_enabled else "DESATIVADOS")
