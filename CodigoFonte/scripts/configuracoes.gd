# configuracoes.gd
extends Node2D

var arrow_back: TextureButton
var button_hover_script: GDScript

# Referências para os controles de configuração
var music_slider: HSlider
var fx_slider: HSlider
var fullscreen_checkbox: CheckBox
var reset_button: Button
var save_button: Button
var label_mensagem: Label

# Flags para controle
var settings_loaded: bool = false
var settings_changed: bool = false
var is_saving: bool = false

# Timers para feedback visual
var message_timer: Timer
var save_cooldown_timer: Timer

func _ready():
	# Obter referências com a nova estrutura
	arrow_back = $ArrowBack
	
	# Buscar controles dentro do nó UI - CORREÇÃO: usar nomes exatos
	var ui_node = $UI
	if ui_node:
		music_slider = ui_node.get_node("MusicHSlider")
		fx_slider = ui_node.get_node("FXHSlider")
		fullscreen_checkbox = ui_node.get_node("FullscreenCheckBox")
		reset_button = ui_node.get_node("ResetButton")
		label_mensagem = ui_node.get_node("LabelMensagem")
		print("✅ Encontrados controles dentro de UI")
	
	# SaveButton está no nível raiz
	save_button = $SaveButton

	# Conectar sinais
	if arrow_back:
		arrow_back.pressed.connect(_on_arrow_back_pressed)
	
	if music_slider:
		music_slider.value_changed.connect(_on_music_slider_changed)
		# CORREÇÃO: Conectar drag_ended se existir
		if music_slider.has_signal("drag_ended"):
			music_slider.drag_ended.connect(_on_music_drag_ended)
	
	if fx_slider:
		fx_slider.value_changed.connect(_on_fx_slider_changed)
		# CORREÇÃO: Conectar drag_ended se existir
		if fx_slider.has_signal("drag_ended"):
			fx_slider.drag_ended.connect(_on_fx_drag_ended)
	
	if fullscreen_checkbox:
		fullscreen_checkbox.toggled.connect(_on_fullscreen_checkbox_toggled)
	
	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)
	
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)

	# Criar timers
	message_timer = Timer.new()
	message_timer.one_shot = true
	add_child(message_timer)
	
	save_cooldown_timer = Timer.new()
	save_cooldown_timer.one_shot = true
	save_cooldown_timer.wait_time = 2.0  # 2 segundos entre salvamentos
	add_child(save_cooldown_timer)
	
	# Aplicar efeito hover
	button_hover_script = preload("res://ButtonHoverEffect.gd")
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()
	
	# Inicializar label de mensagem
	if label_mensagem:
		label_mensagem.text = "Carregando configurações..."
		label_mensagem.visible = true
		print("✅ LabelMensagem inicializado")
	
	# Carregar configurações
	load_settings()
	
	# Debug: verificar se todos os controles foram encontrados
	print("🔍 Controles encontrados:")
	print("   - Music Slider: ", music_slider != null)
	print("   - FX Slider: ", fx_slider != null)
	print("   - Fullscreen Checkbox: ", fullscreen_checkbox != null)
	print("   - Reset Button: ", reset_button != null)
	print("   - Save Button: ", save_button != null)
	print("   - Label Mensagem: ", label_mensagem != null)

func _on_arrow_back_pressed():
	# CORREÇÃO: Sempre salvar ao sair se houver mudanças
	if settings_changed:
		print("💾 Salvando mudanças antes de sair...")
		show_message("Salvando antes de sair...", 1.0)
		SettingsManager.save_settings_to_server()
		await get_tree().create_timer(1.0).timeout
	
	get_tree().change_scene_to_file("res://Main.tscn")

func load_settings():
	print("📥 Iniciando carregamento de configurações...")
	
	# Verificar se SettingsManager existe
	if not has_node("/root/SettingsManager"):
		print("❌ SettingsManager não encontrado como autoload!")
		apply_default_settings()
		return
	
	# Mostrar "Carregando..." apenas na primeira vez
	if not settings_loaded and label_mensagem:
		label_mensagem.text = "Carregando configurações..."
		label_mensagem.visible = true
	
	# Conectar aos sinais do SettingsManager (apenas uma vez)
	if not SettingsManager.settings_loaded.is_connected(_on_settings_loaded):
		SettingsManager.settings_loaded.connect(_on_settings_loaded)
	if not SettingsManager.settings_saved.is_connected(_on_settings_saved):
		SettingsManager.settings_saved.connect(_on_settings_saved)
	if not SettingsManager.settings_reset.is_connected(_on_settings_reset):
		SettingsManager.settings_reset.connect(_on_settings_reset)
	
	# Carregar configurações
	SettingsManager.load_settings_from_server()

func _on_settings_loaded():
	print("✅ Configurações carregadas - atualizando UI")
	update_ui_with_current_settings()
	settings_loaded = true
	settings_changed = false
	show_message("Configurações carregadas!", 2.0)

func _on_settings_saved():
	print("✅ Configurações salvas com sucesso")
	settings_changed = false
	is_saving = false
	show_message("Configurações salvas com sucesso!", 3.0)

func _on_settings_reset():
	print("✅ Configurações resetadas - atualizando UI")
	update_ui_with_current_settings()
	settings_changed = false
	show_message("Configurações resetadas para o padrão!", 3.0)

func update_ui_with_current_settings():
	if not SettingsManager:
		return
	
	# CORREÇÃO: Converter valores 0-1 para 0-100 nos sliders
	if music_slider:
		# Se o slider vai de 0-100, converter o volume 0-1 para 0-100
		var music_value = SettingsManager.get_master_volume()
		if music_slider.max_value > 1.0:
			music_slider.value = music_value * 100.0
		else:
			music_slider.value = music_value
	
	if fx_slider:
		# Se o slider vai de 0-100, converter o volume 0-1 para 0-100
		var fx_value = SettingsManager.get_fx_volume()
		if fx_slider.max_value > 1.0:
			fx_slider.value = fx_value * 100.0
		else:
			fx_slider.value = fx_value
	
	if fullscreen_checkbox:
		fullscreen_checkbox.button_pressed = SettingsManager.is_fullscreen()
	
	print("🎛️  UI atualizada com configurações atuais")

func apply_default_settings():
	# Aplicar configurações padrão na UI
	if music_slider:
		music_slider.value = 100.0 if music_slider.max_value > 1.0 else 1.0
	
	if fx_slider:
		fx_slider.value = 100.0 if fx_slider.max_value > 1.0 else 1.0
	
	if fullscreen_checkbox:
		fullscreen_checkbox.button_pressed = true
	
	settings_loaded = true
	settings_changed = false
	
	print("⚙️  Configurações padrão aplicadas")

# ===== HANDLERS DOS CONTROLES =====

func _on_music_slider_changed(value: float):
	if settings_loaded:
		SettingsManager.set_master_volume(value)
		settings_changed = true
		print("🎵 Volume da música alterado para: ", value)
		# CORREÇÃO: Não mostrar mensagem para mudanças normais de slider

func _on_fx_slider_changed(value: float):
	if settings_loaded:
		SettingsManager.set_fx_volume(value)
		settings_changed = true
		print("🔊 Volume dos efeitos alterado para: ", value)
		# CORREÇÃO: Não mostrar mensagem para mudanças normais de slider

func _on_music_drag_ended():
	# CORREÇÃO: Tocar som de teste quando o usuário soltar o slider de música
	if settings_loaded:
		print("🔊 Testando som de música...")
		SettingsManager.play_music_test()
		show_message("Testando áudio...", 1.0)

func _on_fx_drag_ended():
	# CORREÇÃO: Tocar som de teste quando o usuário soltar o slider de efeitos
	if settings_loaded:
		print("🔊 Testando som de efeitos...")
		SettingsManager.play_fx_test()
		show_message("Testando efeitos...", 1.0)

func _on_fullscreen_checkbox_toggled(button_pressed: bool):
	if settings_loaded:
		SettingsManager.set_fullscreen(button_pressed)
		settings_changed = true
		print("🖥️  Tela cheia: ", button_pressed)
		show_message("Alternando tela...", 1.0)

func _on_reset_button_pressed():
	print("🔄 Solicitando reset de configurações...")
	show_message("Resetando configurações...", 2.0)
	SettingsManager.reset_settings_to_default()

func _on_save_button_pressed():
	if is_saving or save_cooldown_timer.time_left > 0:
		show_message("Aguarde...", 1.0)
		return
	
	print("💾 Solicitando salvamento de configurações...")
	is_saving = true
	show_message("Salvando configurações...", 0)  # Manter até confirmação
	SettingsManager.save_settings_to_server()
	
	# Prevenir salvamentos rápidos consecutivos
	save_cooldown_timer.start()

# ===== FUNÇÕES AUXILIARES =====

func show_message(message: String, duration: float = 0.0):
	if not label_mensagem:
		print("💬 ", message)  # Fallback para console
		return
	
	label_mensagem.text = message
	label_mensagem.visible = true
	
	print("💬 Mensagem: ", message)
	
	# Se duration for 0, a mensagem permanece até a próxima chamada
	if duration > 0:
		message_timer.start(duration)
		await message_timer.timeout
		if label_mensagem and label_mensagem.text == message:  # Só esconder se ainda for a mesma mensagem
			label_mensagem.visible = false
			label_mensagem.text = ""

func aplicar_efeito_hover_todos_botoes():
	var botoes = _buscar_todos_botoes(self)
	
	for botao in botoes:
		if not botao.has_node("ButtonHoverEffect"):
			var effect_node = Node.new()
			effect_node.set_script(button_hover_script)
			botao.add_child(effect_node)
			effect_node.name = "ButtonHoverEffect"
			
			print("🎨 Efeito hover aplicado em: ", botao.name)

func _buscar_todos_botoes(node: Node) -> Array:
	var botoes = []
	
	if node is BaseButton and node.visible:
		botoes.append(node)
	
	for child in node.get_children():
		botoes.append_array(_buscar_todos_botoes(child))
	
	return botoes

# Notificação quando a cena está prestes a ser removida
func _exit_tree():
	# Salvar configurações se houver mudanças não salvas
	if settings_changed and not is_saving:
		print("💾 Salvando configurações antes de sair...")
		SettingsManager.save_settings_to_server()

# Função para debug
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:  # Debug com F12
			print("=== DEBUG CONFIGURAÇÕES ===")
			print("Settings loaded: ", settings_loaded)
			print("Settings changed: ", settings_changed)
			print("Current UI values:")
			print("   - Music: ", music_slider.value if music_slider else "N/A")
			print("   - FX: ", fx_slider.value if fx_slider else "N/A")
			print("   - Fullscreen: ", fullscreen_checkbox.button_pressed if fullscreen_checkbox else "N/A")
			
			if SettingsManager:
				SettingsManager.print_current_settings()
