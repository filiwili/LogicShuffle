extends Node2D

var arrow_back: TextureButton
var button_hover_script: GDScript

# Dicionário para mapear nomes dos níveis para cenas
var level_scenes = {
	"arvore_binaria_nivel1": "res://Jogo2Fase1.tscn",
	"arvore_binaria_nivel2": "res://Jogo2Fase2.tscn",
	"arvore_binaria_nivel3": "res://Jogo2Fase3.tscn",
	"arvore_binaria_nivel4": "res://Jogo2Fase4.tscn",
	"arvore_binaria_nivel5": "res://Jogo2Fase5.tscn",
	"arvore_binaria_nivel6": "res://Jogo2Fase6.tscn",
	"arvore_binaria_nivel7": "res://Jogo2Fase7.tscn",
	"arvore_binaria_nivel8": "res://Jogo2Fase8.tscn",
	"arvore_binaria_nivel9": "res://Jogo2Fase9.tscn",
	"arvore_binaria_nivel10": "res://Jogo2Fase10.tscn"
}

@onready var level_buttons = {
	"arvore_binaria_nivel1": $VBoxContainer/HBoxContainer/ButtonNivel1,
	"arvore_binaria_nivel2": $VBoxContainer/HBoxContainer/ButtonNivel2,
	"arvore_binaria_nivel3": $VBoxContainer/HBoxContainer/ButtonNivel3,
	"arvore_binaria_nivel4": $VBoxContainer/HBoxContainer/ButtonNivel4,
	"arvore_binaria_nivel5": $VBoxContainer/HBoxContainer/ButtonNivel5,
	"arvore_binaria_nivel6": $VBoxContainer/HBoxContainer/ButtonNivel6,
	"arvore_binaria_nivel7": $VBoxContainer/HBoxContainer2/ButtonNivel7,
	"arvore_binaria_nivel8": $VBoxContainer/HBoxContainer2/ButtonNivel8,
	"arvore_binaria_nivel9": $VBoxContainer/HBoxContainer2/ButtonNivel9,
	"arvore_binaria_nivel10": $VBoxContainer/HBoxContainer2/ButtonNivel10
}

func _ready():
	print("=== INICIANDO SELEÇÃO DE NÍVEIS ÁRVORE BINÁRIA ===")
	
	# Conectar botão de voltar
	arrow_back = $ArrowBack
	if arrow_back:
		arrow_back.pressed.connect(_on_arrow_back_pressed)
	else:
		print("Aviso: ArrowBack não encontrado")
	
	# Conectar sinais do progress manager
	if ProgressManager:
		ProgressManager.progress_loaded.connect(_on_progress_loaded)
		ProgressManager.level_access_checked.connect(_on_level_access_checked)
		
		# Carregar progresso do usuário para o jogo 2 (Árvores Binárias)
		ProgressManager.load_user_progress("2")
	else:
		print("Erro: ProgressManager não encontrado - verifique configuração do autoload")
	
	# Conectar botões de nível
	_setup_level_buttons()
	
	# Configurar efeito hover
	button_hover_script = preload("res://ButtonHoverEffect.gd")
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()

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
	get_tree().change_scene_to_file("res://jogar.tscn")

func _on_level_button_pressed(level_name: String):
	print("🎮 Tentando acessar nível: ", level_name)
	
	# Verificação SIMPLIFICADA - SEM AWAIT
	if ProgressManager and ProgressManager.has_access_to_level(level_name, "2"):
		_open_level(level_name)
	else:
		# Verificar com o servidor
		if ProgressManager:
			ProgressManager.check_level_access(level_name, "2")
		else:
			print("Erro: ProgressManager não disponível")
			# Fallback: permitir acesso se não houver progress manager
			_open_level(level_name)

func _on_progress_loaded(game_id: String):
	if game_id == "2":  # Só atualizar se for do jogo 2
		print("🔄 Atualizando interface com progresso carregado")
		update_level_buttons_visual()

func _on_level_access_checked(level_name: String, access_granted: bool):
	if access_granted:
		_open_level(level_name)
	else:
		show_access_denied_message(level_name)

func update_level_buttons_visual():
	if not ProgressManager:
		print("Erro: ProgressManager não disponível para atualizar visual")
		return
	
	for level_name in level_buttons:
		var button = level_buttons[level_name]
		if button:
			var level_data = ProgressManager.get_level_data(level_name, "2")
			var is_unlocked = ProgressManager.has_access_to_level(level_name, "2")  # CORRIGIDO
			var is_completed = level_data.get("completed", false) if level_data else false
			var score = level_data.get("score", 0) if level_data else 0
			
			# Configurar aparência baseada no estado
			if is_completed:
				button.text = level_name.replace("arvore_binaria_nivel", "Nível ") + " ✅\n" + str(score) + " pts"
				button.modulate = Color(0.5, 1.0, 0.5)  # Verde para concluído
				button.disabled = false
			elif is_unlocked:
				button.text = level_name.replace("arvore_binaria_nivel", "Nível ")
				button.modulate = Color(1.0, 1.0, 1.0)  # Normal para desbloqueado
				button.disabled = false
			else:
				button.text = level_name.replace("arvore_binaria_nivel", "Nível ") + " 🔒"
				button.modulate = Color(0.5, 0.5, 0.5)  # Cinza para bloqueado
				button.disabled = true

func _open_level(level_name: String):
	print("🚀 Abrindo nível: ", level_name)
	
	if level_name in level_scenes:
		var scene_path = level_scenes[level_name]
		var error = get_tree().change_scene_to_file(scene_path)
		if error != OK:
			print("❌ Erro ao carregar cena: ", scene_path, " - Código: ", error)
	else:
		print("❌ Cena não encontrada para: ", level_name)

func show_access_denied_message(level_name: String):
	var alert = AcceptDialog.new()
	alert.title = "Nível Bloqueado"
	alert.dialog_text = "Complete o nível anterior para desbloquear " + level_name.replace("arvore_binaria_nivel", "Nível ")
	add_child(alert)
	alert.popup_centered()
	alert.confirmed.connect(alert.queue_free)

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
