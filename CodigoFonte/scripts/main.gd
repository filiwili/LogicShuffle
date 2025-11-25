extends Control

@onready var trophy: TextureButton = $Trophy
@onready var profile_picture: TextureButton = $ProfilePicture

var default_profile_texture = preload("res://cat.png")
const PROFILE_IMAGE_SIZE = 256
var button_hover_script: GDScript

func _ready():
	if trophy:
		trophy.pressed.connect(_on_trophy_pressed)
	if profile_picture:
		profile_picture.pressed.connect(_on_perfil_pressed)
	
	# Carregar imagem de perfil quando a cena carrega
	_load_profile_picture()
	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# Aplicar efeito hover após um pequeno delay para garantir que todos os botões estejam carregados
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()

# CORREÇÃO: Atualizar a imagem quando a cena ganha foco (quando voltamos do Perfil)
func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_SCENE_INSTANTIATED:
		_load_profile_picture()

func _load_profile_picture():
	print("=== MAIN - Carregando imagem do perfil ===")
	print("SessionManager.profile_image está vazio?: ", SessionManager.profile_image == "")
	
	# Se temos imagem no SessionManager, carregamos
	if SessionManager.profile_image != "":
		print("Carregando imagem do SessionManager")
		_load_image_from_base64(SessionManager.profile_image)
	else:
		print("Carregando imagem padrão")
		_set_default_profile_picture()

func _load_image_from_base64(base64_string: String):
	if base64_string == "" or base64_string == null:
		print("String base64 vazia, usando imagem padrão")
		_set_default_profile_picture()
		return
	
	var image_data = Marshalls.base64_to_raw(base64_string)
	var image = Image.new()
	var error = image.load_png_from_buffer(image_data)
	
	if error == OK:
		print("Imagem carregada com sucesso no Main")
		image.resize(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE, Image.INTERPOLATE_LANCZOS)
		var texture = ImageTexture.create_from_image(image)
		profile_picture.texture_normal = texture
		profile_picture.custom_minimum_size = Vector2(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE)
	else:
		print("Erro ao carregar imagem do perfil no Main: ", error)
		_set_default_profile_picture()

func _set_default_profile_picture():
	print("Configurando imagem padrão no Main")
	if default_profile_texture:
		var default_image = default_profile_texture.get_image()
		default_image.resize(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE, Image.INTERPOLATE_LANCZOS)
		var resized_texture = ImageTexture.create_from_image(default_image)
		profile_picture.texture_normal = resized_texture
		profile_picture.custom_minimum_size = Vector2(PROFILE_IMAGE_SIZE, PROFILE_IMAGE_SIZE)
	else:
		print("Erro: Imagem padrão não encontrada no Main")

func _on_trophy_pressed():
	get_tree().change_scene_to_file("res://Ranking.tscn")
	
func _on_perfil_pressed():
	get_tree().change_scene_to_file("res://Perfil.tscn")

func _on_jogar_pressed():
	get_tree().change_scene_to_file("res://jogar.tscn")

func _on_configuracoes_pressed():
	get_tree().change_scene_to_file("res://configuracoes.tscn")

func _on_sair_pressed():
	get_tree().quit()

# ADICIONE ESTA FUNÇÃO - mesma estrutura dos outros botões
func _on_sobre_pressed():
	get_tree().change_scene_to_file("res://Sobre.tscn")
	
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
