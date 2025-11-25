extends Node2D

var arrow_back: TextureButton
var button_minigame1: Button
var button_minigame2: Button
var button_hover_script: GDScript


func _ready():
	# Debug: verificar estrutura da cena
	print("=== ESTRUTURA DA CENA ===")
	print("Nós disponíveis:")
	for child in get_children():
		print(" - ", child.name)
	print("========================")
	
	# Conectar botões com verificação de existência
	_setup_arrow_back()
	_setup_minigame_buttons()
	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# Aplicar efeito hover após um pequeno delay para garantir que todos os botões estejam carregados
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()

func _setup_arrow_back():
	arrow_back = $Minimal3/ArrowBack
	if arrow_back:
		arrow_back.pressed.connect(_on_arrow_back_pressed)
		print("✅ ArrowBack conectado com sucesso")
	else:
		print("❌ ArrowBack não encontrado. Verifique o caminho: Minimal3/ArrowBack")
		# Tentar caminho alternativo
		arrow_back = find_child("ArrowBack")
		if arrow_back:
			print("✅ ArrowBack encontrado via busca")
			arrow_back.pressed.connect(_on_arrow_back_pressed)

func _setup_minigame_buttons():
	# Minigame 1
	button_minigame1 = $UI/MainContainer/ButtonMinigame1
	if button_minigame1:
		button_minigame1.pressed.connect(_on_minigame1_pressed)
		print("✅ ButtonMinigame1 conectado")
	else:
		print("❌ ButtonMinigame1 não encontrado. Verifique o caminho: UI/ButtonMinigame1")
		button_minigame1 = find_child("ButtonMinigame1")
		if button_minigame1:
			print("✅ ButtonMinigame1 encontrado via busca")
			button_minigame1.pressed.connect(_on_minigame1_pressed)
	
	# Minigame 2
	button_minigame2 = $UI/MainContainer/ButtonMinigame2
	if button_minigame2:
		button_minigame2.pressed.connect(_on_minigame2_pressed)
		print("✅ ButtonMinigame2 conectado")
	else:
		print("❌ ButtonMinigame2 não encontrado. Verifique o caminho: UI/ButtonMinigame2")
		button_minigame2 = find_child("ButtonMinigame2")
		if button_minigame2:
			print("✅ ButtonMinigame2 encontrado via busca")
			button_minigame2.pressed.connect(_on_minigame2_pressed)

func _on_arrow_back_pressed():
	print("Voltando para a tela principal...")
	var error = get_tree().change_scene_to_file("res://Main.tscn")
	if error != OK:
		print("❌ Erro ao carregar Main.tscn: ", error)

func _on_minigame1_pressed():
	print("Iniciando Minigame 1...")
	var error = get_tree().change_scene_to_file("res://Niveis1.tscn")
	if error != OK:
		print("❌ Erro ao carregar Minigame1.tscn: ", error)

func _on_minigame2_pressed():
	print("Iniciando Minigame 2...")
	var error = get_tree().change_scene_to_file("res://Niveis2.tscn")
	if error != OK:
		print("❌ Erro ao carregar Minigame2.tscn: ", error)

# Função opcional para criar botões programaticamente se não existirem
func _create_fallback_buttons():
	print("Criando botões de fallback...")
	
	# Criar container se não existir
	var ui_node = $UI
	if not ui_node:
		ui_node = Control.new()
		ui_node.name = "UI"
		add_child(ui_node)
	
	# Criar botão Minigame 1
	if not button_minigame1:
		button_minigame1 = Button.new()
		button_minigame1.text = "Minigame 1"
		button_minigame1.position = Vector2(100, 100)
		button_minigame1.pressed.connect(_on_minigame1_pressed)
		ui_node.add_child(button_minigame1)
	
	# Criar botão Minigame 2
	if not button_minigame2:
		button_minigame2 = Button.new()
		button_minigame2.text = "Minigame 2"
		button_minigame2.position = Vector2(100, 150)
		button_minigame2.pressed.connect(_on_minigame2_pressed)
		ui_node.add_child(button_minigame2)


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
