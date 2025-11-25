extends Control

enum Tool { 
	ADD_NODE, 
	CONNECT_NODES, 
	MOVE, 
	DELETE 
}

# Variáveis de estado do jogo
var current_tool: Tool = Tool.ADD_NODE
var nodes = {}
var edges = []
var next_node_id: int = 1
var selected_node_id: int = -1
var connection_start_id: int = -1
var move_start_position: Vector2 = Vector2.ZERO
var move_start_node_id: int = -1
var feedback_popup: ConfirmationDialog
var confirmacao_popup: ConfirmationDialog
var aviso_popup: AcceptDialog
var button_hover_script: GDScript

var root_node_id: int = -1
var first_node_added: bool = false
var nodes_to_swap: Array = []

# Sistema de tempo e pontuação
var tempo_inicio: int = 0
var pontuacao: int = 1000
var nivel_concluido: bool = false
var tempo_decorrido: int = 0
var solucionado: bool = false
var primeira_conclusao: bool = true

# ---------- Sistema de Conclusão ----------
var popup_conclusao: AcceptDialog
var redirecionamento_auto_timer: Timer
var redirecionamento_ok_timer: Timer
var redirecionamento_em_andamento: bool = false

# Referências aos nós da cena
var drawing_area: ColorRect
var nodes_container: Node2D
var tool_label: Label
var node_value_edit: LineEdit
var tempo_label: Label
var score_label: Label
var show_solution_button: Button
var submit_button: Button
var quit_button: Button
var mensagem_label: Label
var help_button: Button

# Popup tutorial
var canvas_layer: CanvasLayer
var overlay: TextureRect
var popup_tutorial: Panel
var popup_text_label: RichTextLabel
var close_button: Button

# Cena do nó
var tree_node_scene: PackedScene = preload("res://SimpleTreeNode.tscn")

func _ready():
	print("=== INICIANDO JOGO 2 FASE 2 (RÁ) ===")
	
	# Inicializar referências
	_initialize_references()
	
	# Conectar todos os sinais
	_connect_signals()
	
	# Configurar estado inicial
	update_tool_display()
	setup_level()
	
	# Configurar área de desenho
	if drawing_area:
		drawing_area.mouse_filter = Control.MOUSE_FILTER_STOP
		drawing_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drawing_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Configurar o LineEdit
	if node_value_edit:
		node_value_edit.max_length = 1
		node_value_edit.placeholder_text = "Valor"
	
	# Inicializar tempo e pontuação
	tempo_inicio = Time.get_ticks_msec()
	nivel_concluido = false
	pontuacao = 1000
	
	# Verificar se já foi concluído antes
	verificar_primeira_conclusao()
	
	# Mostrar popup tutorial
	abrir_tutorial()
	
	# Mostrar mensagem inicial
	atualizar_mensagem_instrucao()
	
	# Criar os popups
	_setup_popups()
	
	# Configurar sistema de conclusão
	_setup_sistema_conclusao()
	
	await get_tree().process_frame
	
	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# Aplicar efeito hover após um pequeno delay para garantir que todos os botões estejam carregados
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()

func _on_help_button_pressed():
	print("🆘 HelpButton pressionado - reabrindo tutorial")
	abrir_tutorial()

# ---------- Sistema de Conclusão ----------
func _setup_sistema_conclusao():
	popup_conclusao = AcceptDialog.new()
	popup_conclusao.title = "🎉 Nível Concluído!"
	popup_conclusao.unresizable = true
	popup_conclusao.confirmed.connect(_on_conclusao_ok_pressed)
	add_child(popup_conclusao)
	
	redirecionamento_auto_timer = Timer.new()
	redirecionamento_auto_timer.wait_time = 10.0
	redirecionamento_auto_timer.one_shot = true
	redirecionamento_auto_timer.timeout.connect(_on_redirecionamento_auto_timeout)
	add_child(redirecionamento_auto_timer)
	
	redirecionamento_ok_timer = Timer.new()
	redirecionamento_ok_timer.wait_time = 2.0
	redirecionamento_ok_timer.one_shot = true
	redirecionamento_ok_timer.timeout.connect(_on_redirecionamento_ok_timeout)
	add_child(redirecionamento_ok_timer)

func mostrar_conclusao_nivel():
	if SettingsManager:
		SettingsManager.play_sound("res://sounds/crowdcheer.wav", "SFX")
	var tempo_total = tempo_decorrido
	var minutos = tempo_total / 60
	var segundos = tempo_total % 60
	
	var texto_conclusao = "✅ Nível Concluído!\nPontuação: %d pontos\nTempo: %02d:%02d\n\nRedirecionando em 10s...\nOK para 2s" % [pontuacao, minutos, segundos]
	
	popup_conclusao.dialog_text = texto_conclusao
	
	var popup_size = Vector2(200, 100)
	var screen_size = get_viewport().get_visible_rect().size
	var popup_position = Vector2((screen_size.x - popup_size.x) / 2, 20)
	
	if popup_conclusao.visible:
		popup_conclusao.hide()
	
	popup_conclusao.popup(Rect2(popup_position, popup_size))
	redirecionamento_auto_timer.start()
	redirecionamento_em_andamento = false

func _on_conclusao_ok_pressed():
	if redirecionamento_auto_timer.time_left > 0:
		redirecionamento_auto_timer.stop()
		redirecionamento_ok_timer.start()
		
		var tempo_total = tempo_decorrido
		var minutos = tempo_total / 60
		var segundos = tempo_total % 60
		popup_conclusao.dialog_text = "✅ Nível Concluído!\nPontuação: %d pontos\nTempo: %02d:%02d\n\nRedirecionando em 2s..." % [pontuacao, minutos, segundos]

func _on_redirecionamento_auto_timeout():
	redirecionamento_em_andamento = true
	popup_conclusao.hide()
	get_tree().change_scene_to_file("res://Niveis2.tscn")

func _on_redirecionamento_ok_timeout():
	redirecionamento_em_andamento = true
	popup_conclusao.hide()
	get_tree().change_scene_to_file("res://Niveis2.tscn")

func _initialize_references():
	drawing_area = find_child("DrawingArea")
	nodes_container = find_child("NodesContainer")
	tool_label = find_child("ToolLabel")
	node_value_edit = find_child("NodeValueEdit")
	tempo_label = find_child("TempoLabel")
	score_label = find_child("ScoreLabel")
	show_solution_button = find_child("ShowSolutionButton")
	submit_button = find_child("SubmitButton")
	quit_button = find_child("QuitButton")
	mensagem_label = find_child("MensagemLabel")
	help_button = find_child("HelpButton")

	canvas_layer = find_child("CanvasLayer")
	if canvas_layer:
		overlay = canvas_layer.find_child("Overlay")
		popup_tutorial = canvas_layer.find_child("PopupTutorial")
		if popup_tutorial:
			popup_text_label = popup_tutorial.find_child("TextLabel")
			close_button = popup_tutorial.find_child("CloseButton")

func _setup_popups():
	feedback_popup = ConfirmationDialog.new()
	feedback_popup.title = "Resultado da Verificação"
	feedback_popup.get_ok_button().text = "Tentar Novamente"
	feedback_popup.confirmed.connect(_on_feedback_try_again)
	feedback_popup.close_requested.connect(_on_feedback_closed)
	add_child(feedback_popup)
	
	confirmacao_popup = ConfirmationDialog.new()
	confirmacao_popup.title = "Confirmar Mostrar Solução"
	confirmacao_popup.dialog_text = "Ver a solução reduzirá sua pontuação máxima para 500 pontos. Tem certeza?"
	confirmacao_popup.get_ok_button().text = "Sim, Mostrar Solução"
	confirmacao_popup.get_cancel_button().text = "Cancelar"
	confirmacao_popup.confirmed.connect(_on_confirmar_mostrar_solucao)
	confirmacao_popup.canceled.connect(_on_cancelar_mostrar_solucao)
	add_child(confirmacao_popup)
	
	aviso_popup = AcceptDialog.new()
	aviso_popup.title = "Aviso"
	add_child(aviso_popup)

func _connect_signals():
	print("🔌 Conectando sinais...")
	
	var add_node_tool = find_child("AddNodeTool")
	if add_node_tool:
		add_node_tool.pressed.connect(_on_add_node_tool_selected)
	
	var connect_tool = find_child("ConnectTool")
	if connect_tool:
		connect_tool.pressed.connect(_on_connect_tool_selected)
	
	var move_tool = find_child("MoveTool")
	if move_tool:
		move_tool.pressed.connect(_on_move_tool_selected)
	
	var delete_tool = find_child("DeleteTool")
	if delete_tool:
		delete_tool.pressed.connect(_on_delete_tool_selected)
	
	var clear_button = find_child("ClearButton")
	if clear_button:
		clear_button.pressed.connect(_on_clear_button_pressed)
	
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)
		print("✅ HelpButton conectado")
	else:
		print("❌ HelpButton não encontrado")
	
	if show_solution_button:
		show_solution_button.pressed.connect(solicitar_mostrar_solucao)
	
	if submit_button:
		submit_button.pressed.connect(_on_submit_pressed)
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
	
	if close_button:
		close_button.pressed.connect(_on_close_tutorial)
	
	if drawing_area:
		drawing_area.gui_input.connect(_on_drawing_area_input)
	
	print("🎯 Todos os sinais conectados!")

func _process(_delta):
	if not nivel_concluido:
		atualizar_pontuacao_tempo()
		atualizar_ui_tempo()

func atualizar_pontuacao_tempo():
	tempo_decorrido = int((Time.get_ticks_msec() - tempo_inicio) / 1000)
	
	pontuacao = 1000
	if tempo_decorrido > 60:
		pontuacao -= (tempo_decorrido - 60) * 3
	pontuacao = max(pontuacao, 500)
	
	if solucionado:
		pontuacao = min(pontuacao, 500)

func atualizar_ui_tempo():
	if tempo_label:
		tempo_label.text = "Tempo: %ds" % tempo_decorrido
	
	if score_label:
		score_label.text = "Pontuação: %d" % pontuacao

func atualizar_mensagem_instrucao():
	if not mensagem_label:
		return
	
	match current_tool:
		Tool.ADD_NODE:
			mensagem_label.text = "Clique na área para adicionar uma placa. A primeira placa é a raiz."
		Tool.CONNECT_NODES:
			if connection_start_id == -1:
				mensagem_label.text = "Selecione a primeira placa para conectar."
			else:
				mensagem_label.text = "Agora selecione uma segunda, para completar a conexão."
		Tool.MOVE:
			if nodes_to_swap.size() == 0:
				mensagem_label.text = "Selecione duas placas para trocar seus valores."
			elif nodes_to_swap.size() == 1:
				mensagem_label.text = "Selecione a segunda placa para trocar."
		Tool.DELETE:
			mensagem_label.text = "Clique em uma placa ou conexão para deletar."
		_:
			mensagem_label.text = "Use as ferramentas para construir a árvore."

func abrir_tutorial():
	if overlay and popup_tutorial:
		overlay.visible = true
		popup_tutorial.visible = true
		ocultar_ui_para_tutorial()
		configurar_texto_tutorial()

func configurar_texto_tutorial():
	if not popup_text_label:
		return
	
	popup_text_label.bbcode_enabled = true
	popup_text_label.text = """
	[b]Nível 10: A GLÓRIA DE RÁ III [/b]

	Você é um jovem sacerdote no templo de Osíris, aprendendo os segredos das "Árvores da Vida" - estruturas sagradas que mantêm a ordem do universo.
	
	Ó jovem sacerdote, Rá, o deus do sol que tudo vê desde o amanhecer, te convoca! Siga meu caminho sagrado: primeiro a raiz, depois a esquerda e por fim a direita. Como meu sol que nasce e ilumina tudo em sequência, revele os valores na ordem que eu determinar!
	
	[b]Mandamento de Rá:[/b]
	Ordem de nascimento das placas: 5, 6, 4, 3, 7
	Leia como: [b]RAIZ-ESQUERDA-DIREITA[/b]
	(5) RAIZ
	(6) Lado esquerdo
	(4, 3, 7) Lado direito
	Note que o lado direito também deve seguir a ordem de Raiz - Lado esquerdo - Lado direito
	
	• Use a ferramenta [b]Adicionar Placa[/b] para construir as placas na tela.
	• Use a ferramenta [b]Conectar Placas[/b] para ligar as placas conforme a glória de Rá.
	• Lembre-se: cada placa pode somente ser ligada a no máximo duas placas.

	"""

func ocultar_ui_para_tutorial():
	var main_container = find_child("MainContainer")
	if main_container:
		main_container.visible = false
	
	if tempo_label:
		tempo_label.visible = false
	
	if score_label:
		score_label.visible = false
	
	if mensagem_label:
		mensagem_label.visible = false

func mostrar_ui_apos_tutorial():
	var main_container = find_child("MainContainer")
	if main_container:
		main_container.visible = true
	
	if tempo_label:
		tempo_label.visible = true
	
	if score_label:
		score_label.visible = true
	
	if mensagem_label:
		mensagem_label.visible = true

func _on_close_tutorial():
	if overlay and popup_tutorial:
		overlay.visible = false
		popup_tutorial.visible = false
		mostrar_ui_apos_tutorial()

func verificar_primeira_conclusao():
	var save = ConfigFile.new()
	var err = save.load("user://savegame.cfg")
	
	if err == OK and save.has_section_key("arvore_binaria_nivel10", "concluido"):
		primeira_conclusao = false
		print("ℹ️ Nível já foi concluído anteriormente - pontuação não será salva")
	else:
		primeira_conclusao = true
		print("✅ Primeira vez neste nível - pontuação será salva")

func update_tool_display():
	if tool_label:
		match current_tool:
			Tool.ADD_NODE:
				tool_label.text = "Ferramenta: Adicionar Nó"
			Tool.CONNECT_NODES:
				tool_label.text = "Ferramenta: Conectar Nós"
			Tool.MOVE:
				tool_label.text = "Ferramenta: Trocar Posições"
			Tool.DELETE:
				tool_label.text = "Ferramenta: Deletar"
	
	atualizar_mensagem_instrucao()

func _on_add_node_tool_selected():
	current_tool = Tool.ADD_NODE
	update_tool_display()
	deselect_all_nodes()
	reset_connection_start()

func _on_connect_tool_selected():
	current_tool = Tool.CONNECT_NODES
	update_tool_display()
	deselect_all_nodes()
	reset_connection_start()

func _on_move_tool_selected():
	current_tool = Tool.MOVE
	update_tool_display()
	deselect_all_nodes()
	reset_connection_start()
	nodes_to_swap.clear()
	atualizar_mensagem_instrucao()

func _on_delete_tool_selected():
	current_tool = Tool.DELETE
	update_tool_display()
	deselect_all_nodes()
	reset_connection_start()

func _on_clear_button_pressed():
	clear_tree()

func reset_connection_start():
	connection_start_id = -1
	atualizar_mensagem_instrucao()

func _on_drawing_area_input(event):
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = drawing_area.get_local_mouse_position()
		
		match current_tool:
			Tool.ADD_NODE:
				add_node(mouse_pos)
			Tool.DELETE:
				handle_delete_click(mouse_pos)
			Tool.MOVE:
				var clicked_node_id = find_node_at_position(mouse_pos)
				if clicked_node_id != -1:
					start_node_move(clicked_node_id, mouse_pos)
	
	elif event is InputEventMouseMotion and current_tool == Tool.MOVE and move_start_node_id != -1:
		continue_node_move(drawing_area.get_local_mouse_position())
	
	elif event is InputEventMouseButton and not event.pressed and current_tool == Tool.MOVE:
		finish_node_move()

func start_node_move(node_id: int, mouse_pos: Vector2):
	move_start_node_id = node_id
	move_start_position = mouse_pos

func continue_node_move(mouse_pos: Vector2):
	if move_start_node_id != -1 and move_start_node_id in nodes:
		var node = nodes[move_start_node_id]
		var offset = mouse_pos - move_start_position
		
		var new_position = node.position + offset
		
		if drawing_area:
			var area_size = drawing_area.size
			var node_size = Vector2(80, 80)
			new_position.x = clamp(new_position.x, 0, area_size.x - node_size.x)
			new_position.y = clamp(new_position.y, 0, area_size.y - node_size.y)
		
		node.position = new_position
		node.visual_node.position = new_position
		move_start_position = mouse_pos
		update_connections_for_node(move_start_node_id)

func finish_node_move():
	if move_start_node_id != -1:
		move_start_node_id = -1
		move_start_position = Vector2.ZERO

func handle_delete_click(mouse_pos: Vector2):
	var clicked_edge = find_edge_at_position(mouse_pos)
	if clicked_edge:
		remove_connection_between_nodes(clicked_edge.from, clicked_edge.to)
		return
	
	var clicked_node_id = find_node_at_position(mouse_pos)
	if clicked_node_id != -1:
		delete_node(clicked_node_id)
		return
	
	mostrar_aviso("Nada para deletar nessa posição!")

func find_node_at_position(pos: Vector2) -> int:
	for node_id in nodes:
		var node = nodes[node_id]
		var node_rect = Rect2(node.position, Vector2(100, 100))
		if node_rect.has_point(pos):
			return node_id
	return -1

func find_edge_at_position(pos: Vector2):
	for edge in edges:
		var from_pos = nodes[edge.from].position + Vector2(40, 40)
		var to_pos = nodes[edge.to].position + Vector2(40, 40)
		var distance = point_to_line_distance(pos, from_pos, to_pos)
		if distance < 10:
			return edge
	return null

func point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_length = line_vec.length()
	
	if line_length == 0:
		return point_vec.length()
	
	var t = max(0, min(1, point_vec.dot(line_vec) / (line_length * line_length)))
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

func add_node(position: Vector2):
	if not nodes_container:
		return
	
	var node_value = ""
	if node_value_edit:
		node_value = node_value_edit.text.strip_edges()
	
	if node_value == "":
		node_value = str(next_node_id)
	
	var node_instance = tree_node_scene.instantiate()
	if not node_instance:
		return
	
	nodes_container.add_child(node_instance)
	
	var final_position = position
	if not first_node_added:
		first_node_added = true
		root_node_id = next_node_id
		final_position = Vector2(drawing_area.size.x / 2 - 40, 20)
		if mensagem_label:
			mensagem_label.text = "Nó " + node_value + " definido como raiz. Agora adicione mais placas e conecte-os."
	
	node_instance.position = final_position
	node_instance.node_id = next_node_id
	
	if node_instance.has_method("set_value"):
		node_instance.set_value(node_value)
	
	if node_instance.has_signal("node_clicked"):
		node_instance.node_clicked.connect(_on_tree_node_clicked)
	
	nodes[next_node_id] = {
		"id": next_node_id,
		"value": node_value,
		"position": final_position,
		"visual_node": node_instance,
		"parent": -1,
		"left_child": -1,
		"right_child": -1
	}
	
	next_node_id += 1
	
	if node_value_edit:
		node_value_edit.text = ""
	
	atualizar_mensagem_instrucao()

func _on_tree_node_clicked(node_id: int):
	match current_tool:
		Tool.CONNECT_NODES:
			handle_connection_click(node_id)
		Tool.DELETE:
			delete_node(node_id)
		Tool.MOVE:
			handle_swap_click(node_id)

func handle_swap_click(node_id: int):
	if nodes_to_swap.size() < 2:
		nodes_to_swap.append(node_id)
		select_node(node_id)
		atualizar_mensagem_instrucao()
		
		if nodes_to_swap.size() == 2:
			var node1_in_tree = (nodes_to_swap[0] == root_node_id) or is_node_connected_to_root(nodes_to_swap[0])
			var node2_in_tree = (nodes_to_swap[1] == root_node_id) or is_node_connected_to_root(nodes_to_swap[1])
			
			if not node1_in_tree and not node2_in_tree:
				mostrar_aviso("Pelo menos uma das placas deve estar na árvore para a troca ser possível!")
				nodes_to_swap.clear()
				deselect_all_nodes()
				return
			
			swap_node_positions(nodes_to_swap[0], nodes_to_swap[1])
			nodes_to_swap.clear()
			deselect_all_nodes()

func swap_node_positions(node1_id: int, node2_id: int):
	var node1 = nodes[node1_id]
	var node2 = nodes[node2_id]
	
	var temp_value = node1.value
	node1.value = node2.value
	node2.value = temp_value
	
	if node1.visual_node.has_method("set_value"):
		node1.visual_node.set_value(node1.value)
	if node2.visual_node.has_method("set_value"):
		node2.visual_node.set_value(node2.value)
	
	if mensagem_label:
		mensagem_label.text = "Tumbas trocados! A cadeia pode estar inválida - cheque com 'Enviar Solução'"

func handle_connection_click(node_id: int):
	if connection_start_id == -1:
		connection_start_id = node_id
		if nodes[node_id].visual_node.has_method("set_selected"):
			nodes[node_id].visual_node.set_selected(true)
		atualizar_mensagem_instrucao()
	else:
		if connection_start_id != node_id:
			if not is_already_connected(connection_start_id, node_id):
				var connection_result = try_connect_nodes(connection_start_id, node_id)
				if not connection_result.success:
					connection_result = try_connect_nodes(node_id, connection_start_id)
					if not connection_result.success:
						mostrar_aviso(connection_result.message)
			else:
				mostrar_aviso("Estas placas já estão conectados!")
		else:
			mostrar_aviso("Não é possível conectar uma placa a si mesma")
		
		if connection_start_id in nodes and nodes[connection_start_id].visual_node.has_method("set_selected"):
			nodes[connection_start_id].visual_node.set_selected(false)
		connection_start_id = -1
		atualizar_mensagem_instrucao()

func try_connect_nodes(node_a: int, node_b: int) -> Dictionary:
	if can_connect_as_parent(node_a, node_b):
		connect_nodes(node_a, node_b)
		return {"success": true, "message": ""}
	return {"success": false, "message": "A conexão deve ser feita com uma placa na árvore!"}

func can_connect_as_parent(parent_id: int, child_id: int) -> bool:
	var parent_in_tree = (parent_id == root_node_id) or is_node_connected_to_root(parent_id)
	var child_has_parent = nodes[child_id].parent != -1
	var child_is_root = child_id == root_node_id
	
	if parent_in_tree and not child_has_parent and not child_is_root:
		return true
	
	if not first_node_added and not child_has_parent and not child_is_root:
		return true
	
	return false

# FUNÇÃO CONNECT_NODES MODIFICADA - PRIMEIRA CONEXÃO SEMPRE ESQUERDA, SEGUNDA SEMPRE DIREITA
func connect_nodes(parent_id: int, child_id: int):
	var parent_node = nodes[parent_id]
	var child_node = nodes[child_id]
	
	if not first_node_added:
		first_node_added = true
		root_node_id = parent_id
		if mensagem_label:
			mensagem_label.text = "Placa " + parent_node.value + " definido como raiz"
	
	if child_node.parent != -1:
		mostrar_aviso("Esta placa já tem um pai! Remova a conexão primeiro.")
		return
	
	# NOVA LÓGICA: Primeira conexão sempre esquerda, segunda sempre direita
	if parent_node.left_child == -1:
		# Primeiro filho vai para a esquerda
		parent_node.left_child = child_id
		child_node.parent = parent_id
		reposition_child_node(parent_id, child_id, true)
		create_visual_connection(parent_id, child_id, true)
		if mensagem_label:
			mensagem_label.text = "Filho esquerdo adicionado!"
	elif parent_node.right_child == -1:
		# Segundo filho vai para a direita
		parent_node.right_child = child_id
		child_node.parent = parent_id
		reposition_child_node(parent_id, child_id, false)
		create_visual_connection(parent_id, child_id, false)
		if mensagem_label:
			mensagem_label.text = "Filho direito adicionado!"
	else:
		mostrar_aviso("Esta placa já tem dois filhos!")

func is_node_connected_to_root(node_id: int) -> bool:
	if node_id == root_node_id:
		return true
	
	var current_id = node_id
	while current_id in nodes and nodes[current_id].parent != -1:
		if nodes[current_id].parent == root_node_id:
			return true
		current_id = nodes[current_id].parent
	
	return false

func reposition_child_node(parent_id: int, child_id: int, is_left: bool):
	var parent_node = nodes[parent_id]
	var child_node = nodes[child_id]
	
	var parent_pos = parent_node.position
	var horizontal_spacing = 150.0
	var vertical_spacing = 100.0
	
	var node_level = calculate_node_level(child_id)
	
	if node_level > 1:
		horizontal_spacing = horizontal_spacing / pow(2, node_level - 1)
		horizontal_spacing = max(horizontal_spacing, 40.0)
	
	var new_x = parent_pos.x
	if is_left:
		new_x -= horizontal_spacing
	else:
		new_x += horizontal_spacing
	
	var new_y = parent_pos.y + vertical_spacing
	var new_position = Vector2(new_x, new_y)
	
	child_node.position = new_position
	child_node.visual_node.position = new_position
	update_connections_for_node(child_id)

func create_visual_connection(from_id: int, to_id: int, is_left: bool):
	var from_node = nodes[from_id]
	var to_node = nodes[to_id]
	
	var connection = Line2D.new()
	
	var from_center = from_node.position + Vector2(40, 40)
	var to_center = to_node.position + Vector2(40, 40)
	
	var to_level = calculate_node_level(to_id)
	var adjustment_factor = 1.0
	
	if to_level > 1:
		adjustment_factor = 0.7 / (to_level - 0.5)
	
	var direction = (to_center - from_center).normalized()
	var from_adjusted = from_center + direction * 35 * adjustment_factor
	var to_adjusted = to_center - direction * 35 * adjustment_factor
	
	connection.add_point(from_adjusted)
	connection.add_point(to_adjusted)
	connection.width = 6
	connection.default_color = Color(1, 0, 0, 0.8)
	connection.z_index = 0
	connection.antialiased = true
	
	if nodes_container:
		nodes_container.add_child(connection)
		connection.position = Vector2.ZERO
	
	edges.append({
		"from": from_id,
		"to": to_id,
		"is_left": is_left,
		"visual_line": connection
	})

func is_already_connected(node1_id: int, node2_id: int) -> bool:
	for edge in edges:
		if (edge.from == node1_id and edge.to == node2_id) or (edge.from == node2_id and edge.to == node1_id):
			return true
	return false

func select_node(node_id: int):
	deselect_all_nodes()
	selected_node_id = node_id
	if nodes[node_id].visual_node.has_method("set_selected"):
		nodes[node_id].visual_node.set_selected(true)

func deselect_all_nodes():
	for node_id in nodes:
		if nodes[node_id].visual_node.has_method("set_selected"):
			nodes[node_id].visual_node.set_selected(false)
	selected_node_id = -1

func delete_node(node_id: int):
	if node_id in nodes:
		if node_id == root_node_id:
			root_node_id = -1
			first_node_added = false
			if mensagem_label:
				mensagem_label.text = "Raiz removida! A próxima placa adicionado será a nova raiz"
		
		remove_all_connections_of_node(node_id)
		nodes[node_id].visual_node.queue_free()
		nodes.erase(node_id)
		
		if selected_node_id == node_id:
			selected_node_id = -1
		if connection_start_id == node_id:
			connection_start_id = -1
		
		if mensagem_label:
			mensagem_label.text = "Placa deletada!"
		atualizar_mensagem_instrucao()

func remove_connection_between_nodes(node1_id: int, node2_id: int):
	var edge_to_remove = null
	for edge in edges:
		if (edge.from == node1_id and edge.to == node2_id) or (edge.from == node2_id and edge.to == node1_id):
			edge_to_remove = edge
			break
	
	if edge_to_remove:
		if edge_to_remove.has("visual_line") and is_instance_valid(edge_to_remove.visual_line):
			edge_to_remove.visual_line.queue_free()
		
		var node1 = nodes[node1_id]
		var node2 = nodes[node2_id]
		
		if node1.left_child == node2_id:
			node1.left_child = -1
		elif node1.right_child == node2_id:
			node1.right_child = -1
		
		if node2.parent == node1_id:
			node2.parent = -1
		
		edges.erase(edge_to_remove)
		if mensagem_label:
			mensagem_label.text = "Conexão removida!"

func update_connections_for_node(node_id: int):
	for edge in edges:
		if edge.from == node_id or edge.to == node_id:
			if edge.has("visual_line") and is_instance_valid(edge.visual_line):
				var from_pos = nodes[edge.from].position + Vector2(40, 40)
				var to_pos = nodes[edge.to].position + Vector2(40, 40)
				
				var direction = (to_pos - from_pos).normalized()
				var from_adjusted = from_pos + direction * 35
				var to_adjusted = to_pos - direction * 35
				
				edge.visual_line.clear_points()
				edge.visual_line.add_point(from_adjusted)
				edge.visual_line.add_point(to_adjusted)

func remove_all_connections_of_node(node_id: int):
	var edges_to_remove = []
	for edge in edges:
		if edge.from == node_id or edge.to == node_id:
			edges_to_remove.append(edge)
	
	for edge in edges_to_remove:
		if edge.has("visual_line") and is_instance_valid(edge.visual_line):
			edge.visual_line.queue_free()
		
		var other_node_id = edge.from if edge.to == node_id else edge.to
		if other_node_id in nodes:
			var other_node = nodes[other_node_id]
			if other_node.parent == node_id:
				other_node.parent = -1
			if other_node.left_child == node_id:
				other_node.left_child = -1
			if other_node.right_child == node_id:
				other_node.right_child = -1
		
		edges.erase(edge)

# --- SISTEMA DE VERIFICAÇÃO ---
func _on_submit_pressed():
	if nivel_concluido:
		return
	
	var tree_data = get_tree_data()
	var validation_result = validate_level_10_ra()  # Mude para validate_level_10_ra
	
	show_feedback_popup(validation_result.message, validation_result.is_valid)
	
	if validation_result.is_valid:
		nivel_concluido = true
		salvar_resultado()

func show_feedback_popup(message: String, is_success: bool):
	if is_success:
		feedback_popup.dialog_text = "✅ Parabéns! Árvore correta!\n\n" + message
		feedback_popup.get_ok_button().text = "OK"
		feedback_popup.get_cancel_button().visible = false
	else:
		feedback_popup.dialog_text = "❌ Ainda não está correto\n\n" + message
		feedback_popup.get_ok_button().text = "Tentar Novamente"
		var cancel_button = feedback_popup.get_cancel_button()
		cancel_button.visible = true
		cancel_button.text = "Mostrar Solução"
		if not feedback_popup.canceled.is_connected(_on_feedback_show_solution_requested):
			feedback_popup.canceled.connect(_on_feedback_show_solution_requested)
	
	feedback_popup.popup_centered(Vector2(500, 300))

func _on_feedback_closed():
	feedback_popup.hide()

func _on_feedback_show_solution_requested():
	feedback_popup.hide()
	confirmacao_popup.popup_centered(Vector2(500, 200))
	feedback_popup.canceled.disconnect(_on_feedback_show_solution_requested)

func _on_feedback_try_again():
	feedback_popup.hide()

func solicitar_mostrar_solucao():
	if nivel_concluido:
		return
	confirmacao_popup.popup_centered(Vector2(500, 200))

func _on_confirmar_mostrar_solucao():
	if nivel_concluido:
		confirmacao_popup.hide()
		return
	
	solucionado = true
	pontuacao = 500
	atualizar_ui_tempo()
	
	mostrar_solucao()
	
	if SettingsManager:
		SettingsManager.play_sound("res://sounds/crowdcheer.wav", "SFX")
	
	nivel_concluido = true
	salvar_resultado()
	
	var info_popup = AcceptDialog.new()
	info_popup.title = "Glória de Rá Revelada"
	info_popup.dialog_text = "A solução foi aplicada! Sua pontuação foi registrada como 500 pontos."
	info_popup.get_ok_button().text = "Entendi"
	add_child(info_popup)
	info_popup.popup_centered(Vector2(400, 150))
	info_popup.confirmed.connect(info_popup.queue_free)
	
	confirmacao_popup.hide()

func _on_cancelar_mostrar_solucao():
	confirmacao_popup.hide()

func mostrar_solucao():
	print("🎯 Aplicando solução do nível 10 (Rá - Pré-ordem com 5 nós)...")
	
	clear_tree()
	await get_tree().process_frame
	
	var screen_center = get_viewport().get_visible_rect().size / 2
	
	# Posições para a árvore pré-ordem 5, 6, 4, 3, 7
	var raiz_pos = Vector2(screen_center.x - 40, 100)        # 5 (raiz)
	var esquerda_pos = Vector2(screen_center.x - 150, 200)  # 6 (esquerda de 5)
	var direita_pos = Vector2(screen_center.x + 70, 200)    # 4 (direita de 5)
	var direita_esquerda_pos = Vector2(screen_center.x - 30, 300)  # 3 (esquerda de 4)
	var direita_direita_pos = Vector2(screen_center.x + 170, 300)  # 7 (direita de 4)
	
	# Adicionar nós na ordem correta: 5 (raiz), 6 (esquerda), 4 (direita), 3 (esquerda de 4), 7 (direita de 4)
	add_node_solucao(raiz_pos, "5")
	add_node_solucao(esquerda_pos, "6")
	add_node_solucao(direita_pos, "4")
	add_node_solucao(direita_esquerda_pos, "3")
	add_node_solucao(direita_direita_pos, "7")
	
	await get_tree().process_frame
	
	if nodes.size() >= 5:
		var node_ids = nodes.keys()
		
		# Verificar se os valores estão corretos antes de conectar
		if (nodes[node_ids[0]].value == "5" and nodes[node_ids[1]].value == "6" and 
			nodes[node_ids[2]].value == "4" and nodes[node_ids[3]].value == "3" and 
			nodes[node_ids[4]].value == "7"):
			
			var raiz_id = node_ids[0]  # 5
			var esquerda_id = node_ids[1]  # 6
			var direita_id = node_ids[2]  # 4
			var direita_esquerda_id = node_ids[3]  # 3
			var direita_direita_id = node_ids[4]  # 7
			
			# Conectar raiz (5) com filho esquerdo (6)
			if can_connect_as_parent(raiz_id, esquerda_id):
				connect_nodes(raiz_id, esquerda_id)
				await get_tree().process_frame
			
			# Conectar raiz (5) com filho direito (4)
			if can_connect_as_parent(raiz_id, direita_id):
				connect_nodes(raiz_id, direita_id)
				await get_tree().process_frame
			
			# Conectar nó 4 com filho esquerdo (3)
			if can_connect_as_parent(direita_id, direita_esquerda_id):
				connect_nodes(direita_id, direita_esquerda_id)
				await get_tree().process_frame
			
			# Conectar nó 4 com filho direito (7)
			if can_connect_as_parent(direita_id, direita_direita_id):
				connect_nodes(direita_id, direita_direita_id)
				print("✅ Solução Rá aplicada: Árvore 5-6-4-3-7")
				
				if mensagem_label:
					mensagem_label.text = "Solução aplicada!"
			else:
				print("❌ Erro ao conectar 4 com 7")
		else:
			print("❌ Valores dos nós incorretos na solução")
	else:
		print("❌ Erro: Não foi possível criar todas as placas da solução")

func add_node_solucao(position: Vector2, value: String):
	if not nodes_container:
		return
	
	var node_instance = tree_node_scene.instantiate()
	if not node_instance:
		return
	
	nodes_container.add_child(node_instance)
	
	node_instance.position = position
	node_instance.node_id = next_node_id
	
	if node_instance.has_method("set_value"):
		node_instance.set_value(value)
	
	if node_instance.has_signal("node_clicked"):
		node_instance.node_clicked.connect(_on_tree_node_clicked)
	
	nodes[next_node_id] = {
		"id": next_node_id,
		"value": value,
		"position": position,
		"visual_node": node_instance,
		"parent": -1,
		"left_child": -1,
		"right_child": -1
	}
	
	if not first_node_added:
		first_node_added = true
		root_node_id = next_node_id
		print("🎯 Placa raiz definido: ", value)
	
	next_node_id += 1

func validate_level_10_ra() -> Dictionary:
	# Verificar número de nós - agora são 5 nós
	if nodes.size() != 5:
		return {"is_valid": false, "message": "Rá exige exatamente 5 placas sagradas! Você tem " + str(nodes.size()) + " placas."}
	
	var root_id = find_root_node()
	if root_id == -1:
		return {"is_valid": false, "message": "Nenhuma raiz encontrada! Rá demanda uma árvore com raiz."}
	
	# Verificar valor da raiz - deve ser 5
	var root_value = nodes[root_id].value
	if root_value != "5":
		return {"is_valid": false, "message": "Rá ordena que a raiz seja 5! Sua raiz é " + root_value + "."}
	
	# Verificar se todos os nós estão conectados
	var connected_nodes = get_connected_nodes(root_id)
	if connected_nodes.size() != nodes.size():
		return {"is_valid": false, "message": "Todos os nós devem estar conectados na árvore! Existem nós isolados."}
	
	# Verificar estrutura específica para pré-ordem 5, 6, 4, 3, 7
	# Estrutura esperada:
	#       5
	#      / \
	#     6   4
	#        / \
	#       3   7
	
	var root_node = nodes[root_id]
	
	# Verificar filho esquerdo da raiz (deve ser 6)
	if root_node.left_child == -1:
		return {"is_valid": false, "message": "A raiz 5 deve ter um filho à esquerda (6)!"}
	var left_child_value = nodes[root_node.left_child].value
	if left_child_value != "6":
		return {"is_valid": false, "message": "O filho esquerdo da raiz deve ser 6! Seu filho esquerdo é " + left_child_value + "."}
	
	# Verificar filho direito da raiz (deve ser 4)
	if root_node.right_child == -1:
		return {"is_valid": false, "message": "A raiz 5 deve ter um filho à direita (4)!"}
	var right_child_value = nodes[root_node.right_child].value
	if right_child_value != "4":
		return {"is_valid": false, "message": "O filho direito da raiz deve ser 4! Seu filho direito é " + right_child_value + "."}
	
	# Verificar filhos do nó 4
	var right_child_node = nodes[root_node.right_child]
	
	# Verificar filho esquerdo do nó 4 (deve ser 3)
	if right_child_node.left_child == -1:
		return {"is_valid": false, "message": "O nó 4 deve ter um filho à esquerda (3)!"}
	var right_left_value = nodes[right_child_node.left_child].value
	if right_left_value != "3":
		return {"is_valid": false, "message": "O filho esquerdo do nó 4 deve ser 3! Seu filho esquerdo é " + right_left_value + "."}
	
	# Verificar filho direito do nó 4 (deve ser 7)
	if right_child_node.right_child == -1:
		return {"is_valid": false, "message": "O nó 4 deve ter um filho à direita (7)!"}
	var right_right_value = nodes[right_child_node.right_child].value
	if right_right_value != "7":
		return {"is_valid": false, "message": "O filho direito do nó 4 deve ser 7! Seu filho direito é " + right_right_value + "."}
	
	# Verificar travessia pré-ordem
	var preorder = get_preorder_traversal(root_id)
	var expected_preorder = ["5", "6", "4", "3", "7"]
	
	if preorder != expected_preorder:
		return {"is_valid": false, "message": "A ordem de Rá não foi seguida! Pré-ordem deve ser: 5, 6, 4, 3, 7. Sua ordem: " + str(preorder)}
	
	return {"is_valid": true, "message": "✅ Glória a Rá! A árvore está perfeitamente ordenada na pré-ordem."}
	
func get_preorder_traversal(node_id: int) -> Array:
	var result = []
	if node_id in nodes:
		var node = nodes[node_id]
		result.append(node.value)
		if node.left_child != -1:
			result.append_array(get_preorder_traversal(node.left_child))
		if node.right_child != -1:
			result.append_array(get_preorder_traversal(node.right_child))
	return result

func get_inorder_traversal(node_id: int) -> Array:
	var result = []
	if node_id in nodes:
		var node = nodes[node_id]
		if node.left_child != -1:
			result.append_array(get_inorder_traversal(node.left_child))
		result.append(node.value)
		if node.right_child != -1:
			result.append_array(get_inorder_traversal(node.right_child))
	return result

func get_connected_nodes(start_id: int) -> Array:
	var visited = []
	var stack = [start_id]
	
	while stack.size() > 0:
		var current_id = stack.pop_back()
		if current_id in visited:
			continue
		visited.append(current_id)
		var node = nodes[current_id]
		if node.left_child != -1:
			stack.append(node.left_child)
		if node.right_child != -1:
			stack.append(node.right_child)
	return visited

func get_tree_data() -> Dictionary:
	return {
		"nodes": nodes.duplicate(true),
		"edges": edges.duplicate(true),
		"root_id": find_root_node()
	}

func find_root_node() -> int:
	for node_id in nodes:
		if nodes[node_id].parent == -1:
			return node_id
	return -1

func salvar_resultado():
	print("=== INICIANDO SALVAR_RESULTADO ===")
	
	print("💾 Salvando pontuação: ", pontuacao, " pontos")
	
	var save = ConfigFile.new()
	var err = save.load("user://savegame.cfg")
	if err != OK:
		print("📝 Criando novo arquivo de save")
	
	save.set_value("arvore_binaria_nivel10", "concluido", true)
	save.set_value("arvore_binaria_nivel10", "pontuacao", pontuacao)
	save.set_value("arvore_binaria_nivel10", "tempo", tempo_decorrido)
	
	var save_error = save.save("user://savegame.cfg")
	if save_error != OK:
		print("❌ Erro ao salvar localmente: ", save_error)
	else:
		print("✅ Dados salvos localmente com sucesso")
	
	if ProgressManager:
		if not ProgressManager.progress_saved.is_connected(_on_progress_saved_jogo2):
			ProgressManager.progress_saved.connect(_on_progress_saved_jogo2, CONNECT_ONE_SHOT)
		
		ProgressManager.mark_level_completed("arvore_binaria_nivel10", pontuacao)
		print("📤 Progresso enviado para o ProgressManager")
	else:
		print("❌ ProgressManager não disponível")
	
	mostrar_conclusao_nivel()

func _on_progress_saved_jogo2(level_name: String, score: int):
	print("🎉 Progresso confirmado no servidor (Jogo 2): ", level_name, " - Score: ", score)
	if ProgressManager and ProgressManager.progress_saved.is_connected(_on_progress_saved_jogo2):
		ProgressManager.progress_saved.disconnect(_on_progress_saved_jogo2)

func setup_level():
	first_node_added = false
	root_node_id = -1
	nodes_to_swap.clear()
	clear_tree()

func _on_quit_button_pressed():
	if redirecionamento_auto_timer and redirecionamento_auto_timer.time_left > 0:
		redirecionamento_auto_timer.stop()
	if redirecionamento_ok_timer and redirecionamento_ok_timer.time_left > 0:
		redirecionamento_ok_timer.stop()
	
	print("← Voltando para seleção de níveis")
	get_tree().change_scene_to_file("res://Niveis2.tscn")

func mostrar_aviso(mensagem: String):
	aviso_popup.dialog_text = mensagem
	aviso_popup.popup_centered(Vector2(400, 200))

func clear_tree():
	first_node_added = false
	root_node_id = -1
	nodes_to_swap.clear()
	
	for node_id in nodes:
		nodes[node_id].visual_node.queue_free()
	
	for edge in edges:
		if edge.has("visual_line"):
			edge.visual_line.queue_free()
	
	nodes.clear()
	edges.clear()
	next_node_id = 1
	selected_node_id = -1
	connection_start_id = -1
	
	if mensagem_label:
		mensagem_label.text = "Placas limpas. Adicione a primeira placa - ela será a raiz."

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

func calculate_node_level(node_id: int) -> int:
	var level = 0
	var current_id = node_id
	
	while current_id != -1 and current_id in nodes:
		var node = nodes[current_id]
		if node.parent == -1:
			break
		level += 1
		current_id = node.parent
	
	return level

func validate_tree_by_traversal(tree_data: Dictionary) -> Dictionary:
	var root_id = find_root_node()
	
	if root_id == -1:
		return {"is_valid": false, "message": "Árvore vazia! Rá exige uma árvore sagrada. Adicione pelo menos uma placa."}
	
	var connected_nodes = get_connected_nodes(root_id)
	if connected_nodes.size() < tree_data.nodes.size():
		var disconnected_count = tree_data.nodes.size() - connected_nodes.size()
		return {"is_valid": false, "message": "Árvore desconexa! Existem " + str(disconnected_count) + " placas isoladas que não estão conectadas à raiz. Rá demanda que todas as placas estejam unidas."}
	
	return validate_level_10_ra()  # Mude para validate_level_10_ra
