# AudioDebugger.gd
extends Node

func _ready():
	print("🎧 AudioDebugger inicializado")
	# Verificar status do áudio após um pequeno delay
	await get_tree().create_timer(1.0).timeout
	check_audio_status()

func check_audio_status():
	print("=== DIAGNÓSTICO DE ÁUDIO ===")
	
	# Verificar se o áudio está habilitado globalmente
	print("🔊 Áudio global habilitado: ", AudioServer.is_bus_enabled(0))
	
	# Verificar todos os buses
	for i in range(AudioServer.get_bus_count()):
		var bus_name = AudioServer.get_bus_name(i)
		var volume_db = AudioServer.get_bus_volume_db(i)
		var is_muted = AudioServer.is_bus_mute(i)
		var is_enabled = AudioServer.is_bus_enabled(i)
		
		print("🎛️  Bus ", i, " ('", bus_name, "'):")
		print("   - Volume: ", volume_db, " dB")
		print("   - Mute: ", is_muted)
		print("   - Habilitado: ", is_enabled)
	
	# Verificar drivers de áudio
	print("🎵 Driver de áudio: ", AudioServer.get_device())
	print("🎵 Taxa de mixagem: ", AudioServer.get_mix_rate(), " Hz")
	
	# Verificar se há algum efeito aplicado
	for i in range(AudioServer.get_bus_count()):
		var effect_count = AudioServer.get_bus_effect_count(i)
		if effect_count > 0:
			print("🎚️  Bus ", i, " tem ", effect_count, " efeitos")
	
	print("=============================")
