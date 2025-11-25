extends Node2D

var arrow_back: TextureButton
var button_hover_script: GDScript

# Dicionário para mapear nomes dos níveis para cenas
var level_scenes = {
	"nivel1": "res://Jogo1Fase1.tscn",
	"nivel2": "res://Jogo1Fase2.tscn",
	"nivel3": "res://Jogo1Fase3.tscn",
	"nivel4": "res://Jogo1Fase4.tscn",
	"nivel5": "res://Jogo1Fase5.tscn",
	"nivel6": "res://Jogo1Fase6.tscn",
	"nivel7": "res://Jogo1Fase7.tscn",
	"nivel8": "res://Jogo1Fase8.tscn",
	"nivel9": "res://Jogo1Fase9.tscn",
	"nivel10": "res://Jogo1Fase10.tscn"
}

@onready var level_buttons = {
	"nivel1": $VBoxContainer/HBoxContainer/ButtonNivel1,
	"nivel2": $VBoxContainer/HBoxContainer/ButtonNivel2,
	"nivel3": $VBoxContainer/HBoxContainer/ButtonNivel3,
	"nivel4": $VBoxContainer/HBoxContainer/ButtonNivel4,
	"nivel5": $VBoxContainer/HBoxContainer/ButtonNivel5,
	"nivel6": $VBoxContainer/HBoxContainer/ButtonNivel6,
	"nivel7": $VBoxContainer/HBoxContainer2/ButtonNivel7,
	"nivel8": $VBoxContainer/HBoxContainer2/ButtonNivel8,
	"nivel9": $VBoxContainer/HBoxContainer2/ButtonNivel9,
	"nivel10": $VBoxContainer/HBoxContainer2/ButtonNivel10
}

func _ready():
	print("=== INICIANDO SELEÇÃO DE NÍVEIS JOGO 1 ===")
	
	# CORREÇÃO: Verificar se está na árvore
	if not is_inside_tree():
		await tree_entered
	
	# CORREÇÃO: Remover limpeza de cache local (não é mais necessária)
	# limpar_cache_local()
	
	# Conectar botão de voltar
	arrow_back = $ArrowBack
	if arrow_back:
		arrow_back.pressed.connect(_on_arrow_back_pressed)
	else:
		print("Aviso: ArrowBack não encontrado")
	
	# CORREÇÃO: Verificar autenticação antes de carregar progresso
	if not SessionManager or not SessionManager.is_authenticated():
		print("❌ Usuário não autenticado - redirecionando para login")
		show_authentication_error()
		return
	
	# Conectar sinais do progress manager
	if ProgressManager:
		ProgressManager.progress_loaded.connect(_on_progress_loaded)
		ProgressManager.level_access_checked.connect(_on_level_access_checked)
		ProgressManager.progress_saved.connect(_on_progress_saved)
		
		print("✅ ProgressManager conectado - carregando progresso para jogo 1")
		# Carregar progresso do usuário para o jogo 1 (Estruturas de Dados)
		ProgressManager.load_user_progress("1")
	else:
		print("❌ Erro: ProgressManager não encontrado - verifique configuração do autoload")
		# Fallback: garantir pelo menos o primeiro nível desbloqueado
		_ensure_basic_progress()
	
	# Conectar botões de nível
	_setup_level_buttons()
	
	# Configurar efeito hover
	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# CORREÇÃO: Aplicar efeito hover de forma segura
	call_deferred("aplicar_efeito_hover_todos_botoes")

# CORREÇÃO: Função para garantir progresso básico
func _ensure_basic_progress():
	print("🛡️  Garantindo progresso básico para jogo 1")
	for level_name in level_buttons:
		var button = level_buttons[level_name]
		if button:
			if level_name == "nivel1":
				button.text = level_name.replace("nivel", "Nível ")
				button.modulate = Color(1.0, 1.0, 1.0)
				button.disabled = false
			else:
				button.text = level_name.replace("nivel", "Nível ") + " 🔒"
				button.modulate = Color(0.5, 0.5, 0.5)
				button.disabled = true

func _setup_level_buttons():
	# Conectar cada botão ao seu nível correspondente
	for level_name in level_buttons:
		var button = level_buttons[level_name]
		if button:
			# Remover conexões existentes para evitar duplicação
			if button.is_connected("pressed", _on_level_button_pressed):
				button.disconnect("pressed", _on_level_button_pressed)
			
			button.pressed.connect(_on_level_button_pressed.bind(level_name))
			print("Conectado botão: ", level_name)
		else:
			print("Aviso: Botão não encontrado para ", level_name)

func _on_arrow_back_pressed():
	print("← Voltando para tela principal...")
	if is_inside_tree():
		get_tree().change_scene_to_file("res://jogar.tscn")

func _on_level_button_pressed(level_name: String):
	print("🎮 Tentando acessar nível: ", level_name)
	
	# CORREÇÃO: Verificar autenticação primeiro
	if not SessionManager or not SessionManager.is_authenticated():
		print("❌ Usuário não autenticado")
		show_authentication_error()
		return
	
	# Verificação local primeiro
	if ProgressManager and ProgressManager.has_access_to_level(level_name, "1"):
		_open_level(level_name)
	else:
		# Verificar com o servidor
		if ProgressManager:
			print("🔍 Verificando acesso com servidor...")
			ProgressManager.check_level_access(level_name, "1")
		else:
			print("❌ Erro: ProgressManager não disponível")
			show_error_message("Erro interno - tente novamente")

func _on_progress_loaded(game_id: String):
	if game_id == "1":  # Só atualizar se for do jogo 1
		print("🔄 Atualizando interface com progresso carregado")
		update_level_buttons_visual()
		
		

# CORREÇÃO: Nova função para quando progresso é salvo
func _on_progress_saved(level_name: String, score: int):
	print("💾 Progresso salvo - recarregando interface")
	# Recarregar progresso para atualizar a interface
	if ProgressManager:
		ProgressManager.load_user_progress("1")

func _on_level_access_checked(level_name: String, access_granted: bool):
	if access_granted:
		print("✅ Acesso concedido pelo servidor: ", level_name)
		_open_level(level_name)
	else:
		print("❌ Acesso negado pelo servidor: ", level_name)
		show_access_denied_message(level_name)

func update_level_buttons_visual():
	if not ProgressManager:
		print("Erro: ProgressManager não disponível para atualizar visual")
		return
	
	for level_name in level_buttons:
		var button = level_buttons[level_name]
		if button:
			var level_data = ProgressManager.get_level_data(level_name, "1")
			var is_unlocked = ProgressManager.has_access_to_level(level_name, "1")
			var is_completed = level_data.get("completed", false) if level_data else false
			var score = level_data.get("score", 0) if level_data else 0
			
			# Configurar aparência baseada no estado
			if is_completed:
				button.text = level_name.replace("nivel", "Nível ") + " ✅\n" + str(score) + " pts"
				button.modulate = Color(0.5, 1.0, 0.5)  # Verde para concluído
				button.disabled = false
				print("✅ Nível concluído: ", level_name, " - Score: ", score)
			elif is_unlocked:
				button.text = level_name.replace("nivel", "Nível ")
				button.modulate = Color(1.0, 1.0, 1.0)  # Normal para desbloqueado
				button.disabled = false
				print("🔓 Nível desbloqueado: ", level_name)
			else:
				button.text = level_name.replace("nivel", "Nível ") + " 🔒"
				button.modulate = Color(0.5, 0.5, 0.5)  # Cinza para bloqueado
				button.disabled = true
				print("🔒 Nível bloqueado: ", level_name)

func _open_level(level_name: String):
	print("🚀 Abrindo nível: ", level_name)
	
	if level_name in level_scenes:
		var scene_path = level_scenes[level_name]
		if is_inside_tree():
			var error = get_tree().change_scene_to_file(scene_path)
			if error != OK:
				print("❌ Erro ao carregar cena: ", scene_path, " - Código: ", error)
				show_error_message("Erro ao carregar nível")
	else:
		print("❌ Cena não encontrada para: ", level_name)
		show_error_message("Nível não encontrado")

func show_access_denied_message(level_name: String):
	var alert = AcceptDialog.new()
	alert.title = "Nível Bloqueado"
	alert.dialog_text = "Complete o nível anterior para desbloquear " + level_name.replace("nivel", "Nível ")
	add_child(alert)
	alert.popup_centered()
	alert.confirmed.connect(alert.queue_free)

# CORREÇÃO: Nova função para mostrar erro de autenticação
func show_authentication_error():
	var alert = AcceptDialog.new()
	alert.title = "Erro de Autenticação"
	alert.dialog_text = "Você precisa fazer login para acessar os níveis."
	add_child(alert)
	alert.popup_centered()
	alert.confirmed.connect(func():
		if is_inside_tree():
			get_tree().change_scene_to_file("res://Login.tscn")
		alert.queue_free()
	)

# CORREÇÃO: Nova função para mostrar erro genérico
func show_error_message(message: String):
	var alert = AcceptDialog.new()
	alert.title = "Erro"
	alert.dialog_text = message
	add_child(alert)
	alert.popup_centered()
	alert.confirmed.connect(alert.queue_free)

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

# CORREÇÃO: Removida a função limpar_cache_local (não é mais necessária)
# func limpar_cache_local():
# 	# Limpar savegame local para forçar uso do servidor
# 	var save = ConfigFile.new()
# 	var err = save.load("user://savegame.cfg")
# 	if err == OK:
# 		# Remover todas as seções relacionadas aos níveis
# 		for section in save.get_sections():
# 			if section.begins_with("nivel"):
# 				save.erase_section(section)
# 		save.save("user://savegame.cfg")
# 		print("🧹 Cache local limpo")

# CORREÇÃO: Limpar conexões quando a cena for removida
func _exit_tree():
	# Desconectar sinais do ProgressManager
	if ProgressManager:
		if ProgressManager.progress_loaded.is_connected(_on_progress_loaded):
			ProgressManager.progress_loaded.disconnect(_on_progress_loaded)
		if ProgressManager.level_access_checked.is_connected(_on_level_access_checked):
			ProgressManager.level_access_checked.disconnect(_on_level_access_checked)
		if ProgressManager.progress_saved.is_connected(_on_progress_saved):
			ProgressManager.progress_saved.disconnect(_on_progress_saved)
