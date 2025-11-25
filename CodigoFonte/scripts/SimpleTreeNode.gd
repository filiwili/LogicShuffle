# SimpleTreeNode.gd (versão melhorada)
extends Control

signal node_clicked(node_id)

var node_id: int = -1
var node_value: String = ""
var is_selected: bool = false

# Referência para a textura do nó
var node_texture: Texture2D = preload("res://assets/egplaca.png")

func _ready():
	size = Vector2(80, 80)
	custom_minimum_size = Vector2(80, 80)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_setup_visuals()

func _setup_visuals():
	# Background com textura
	var background = TextureRect.new()
	background.name = "Background"
	background.size = size
	background.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if node_texture:
		background.texture = node_texture
	else:
		# Fallback - criar um círculo colorido
		var color_rect = ColorRect.new()
		color_rect.name = "Background"
		color_rect.size = size
		color_rect.color = Color(0.2, 0.4, 0.8)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(color_rect)
	
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	
	# Container para centralizar o texto
	var center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.size = size
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_container)
	
	# Label com melhor contraste
	var value_label = Label.new()
	value_label.name = "ValueLabel"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.add_theme_font_size_override("font_size", 22)  # Tamanho levemente reduzido
	value_label.add_theme_constant_override("outline_size", 3)  # Contorno mais espesso
	value_label.add_theme_color_override("font_outline_color", Color.BLACK)
	value_label.text = node_value
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_container.add_child(value_label)
	
	# Highlight de seleção (apenas borda)
	var selection_highlight = ColorRect.new()
	selection_highlight.name = "SelectionHighlight"
	selection_highlight.size = size
	selection_highlight.color = Color(0, 0, 0, 0)  # Transparente
	selection_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selection_highlight)

func set_value(value: String):
	node_value = value
	var center_container = get_node("CenterContainer")
	if center_container:
		var value_label = center_container.get_node("ValueLabel")
		if value_label:
			value_label.text = value

func set_selected(selected: bool):
	is_selected = selected
	var selection_highlight = get_node("SelectionHighlight")
	
	if selection_highlight:
		if selected:
			# Desenhar uma borda amarela ao redor do nó
			selection_highlight.draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.8, 0.0), false, 4.0)
		else:
			selection_highlight.queue_redraw()  # Limpar o desenho

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		node_clicked.emit(node_id)
		accept_event()

func _get_minimum_size():
	return Vector2(80, 80)
