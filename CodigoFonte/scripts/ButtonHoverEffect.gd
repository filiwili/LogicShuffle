# ButtonHoverEffect.gd (versão adaptada)
extends Node

@export var animation_duration: float = 0.15
@export var button_hover_scale: Vector2 = Vector2(1.05, 1.05)
@export var texture_button_hover_scale: Vector2 = Vector2(1.0, 1.0)  # Sem escala para TextureButtons

var botao: Control
var normal_scale: Vector2
var current_tween: Tween
var is_texture_button: bool = false

func _ready():
	botao = get_parent()
	
	if botao is BaseButton:
		# Verificar se é um TextureButton
		is_texture_button = botao is TextureButton
		
		botao.mouse_entered.connect(_on_mouse_entered)
		botao.mouse_exited.connect(_on_mouse_exited)
		
		normal_scale = botao.scale

func _on_mouse_entered():
	# Parar tween anterior se existir
	if current_tween:
		current_tween.kill()
	
	# Criar novo tween
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	# Aplicar efeito vermelho para todos os botões
	current_tween.tween_property(botao, "modulate", Color(1.4, 0.7, 0.7), animation_duration)
	
	# Aplicar escala apenas para botões normais, não para TextureButtons
	if not is_texture_button:
		current_tween.tween_property(botao, "scale", normal_scale * button_hover_scale, animation_duration)

func _on_mouse_exited():
	# Parar tween anterior se existir
	if current_tween:
		current_tween.kill()
	
	# Criar novo tween
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	# Resetar cor para todos os botões
	current_tween.tween_property(botao, "modulate", Color(1, 1, 1), animation_duration)
	
	# Resetar escala apenas para botões normais
	if not is_texture_button:
		current_tween.tween_property(botao, "scale", normal_scale, animation_duration)
