# ClickableButton.gd
extends Button

func _ready():
	# Conectar o sinal pressed
	if not pressed.is_connected(_on_self_pressed):
		pressed.connect(_on_self_pressed)

func _on_self_pressed():
	# Tocar o som de efeito através do SettingsManager
	if SettingsManager:
		SettingsManager.play_sound("res://sounds/test_fx.wav", "SFX")
