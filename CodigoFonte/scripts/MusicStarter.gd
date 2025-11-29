# MusicStarter.gd
extends Node

func _ready():
	# Esperar o SettingsManager estar pronto
	await get_tree().create_timer(2.0).timeout
	
	print(" MusicStarter: Iniciando música de fundo...")
	
	# Verificar se o SettingsManager está carregado
	if has_node("/root/SettingsManager"):
		SettingsManager.play_background_music()
	else:
		print(" SettingsManager não encontrado")
