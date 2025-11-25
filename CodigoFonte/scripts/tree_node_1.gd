# TreeNode1.gd
extends Control

signal node_clicked(node_id)
signal node_dragged(node_id, new_position)

var node_id: int = -1
var node_value: String = ""
var is_selected: bool = false
var is_being_dragged: bool = false

# Referências
var background: ColorRect
var value_label: Label
var selection_highlight: ColorRect

func _ready():
	_initialize_references()
	_setup_appearance()
	
	print("✅ TreeNode pronto - ID: ", node_id, " em posição: ", position)

func _initialize_references():
	background = get_node("Background")
	value_label = get_node("ValueLabel") 
	selection_highlight = get_node("SelectionHighlight")

func _setup_appearance():
	# Configurar o nó principal
	size = Vector2(80, 80)
	custom_minimum_size = Vector2(80, 80)
	visible = true
	
	# IMPORTANTE: Configurar para capturar mouse
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	
	# Configurar background - FORÇAR posição e tamanho
	if background:
		background.position = Vector2(0, 0)
		background.size = Vector2(80, 80)
		background.color = Color(0.2, 0.4, 0.8)  # Azul
		background.visible = true
		print("🎨 Background configurado - Pos: ", background.position, ", Size: ", background.size)
	
	# Configurar label - FORÇAR posição e tamanho
	if value_label:
		value_label.position = Vector2(0, 0)
		value_label.size = Vector2(80, 80)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_color_override("font_color", Color.WHITE)
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.visible = true
		print("🔤 Label configurado - Pos: ", value_label.position, ", Size: ", value_label.size)
	
	# Configurar highlight - FORÇAR posição e tamanho
	if selection_highlight:
		selection_highlight.position = Vector2(0, 0)
		selection_highlight.size = Vector2(80, 80)
		selection_highlight.color = Color(1.0, 0.8, 0.0, 0.3)
		selection_highlight.visible = false
		print("🌟 SelectionHighlight configurado - Pos: ", selection_highlight.position)

func set_value(value: String):
	node_value = value
	if value_label:
		value_label.text = value
		print("🔤 Valor do nó ", node_id, " definido como: ", value)

func set_selected(selected: bool):
	is_selected = selected
	if selection_highlight:
		selection_highlight.visible = selected
	if background:
		if selected:
			background.color = Color(1.0, 0.8, 0.0)  # Laranja quando selecionado
		else:
			background.color = Color(0.2, 0.4, 0.8)  # Azul quando não selecionado
	print("🎯 Nó ", node_id, " selecionado: ", selected)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Clique no nó
				print("🖱️ Nó ", node_id, " clicado na posição: ", position)
				node_clicked.emit(node_id)
				is_being_dragged = true
				# Capturar o mouse para arrastar
				get_viewport().set_input_as_handled()
			else:
				# Soltar o mouse
				is_being_dragged = false
	
	elif event is InputEventMouseMotion and is_being_dragged:
		# Arrastar o nó
		position += event.relative
		print("↔️ Nó ", node_id, " arrastado para: ", position)
		node_dragged.emit(node_id, position)
		get_viewport().set_input_as_handled()
