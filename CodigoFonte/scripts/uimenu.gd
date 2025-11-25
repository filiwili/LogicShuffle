extends Control



func _on_jogar_pressed():
	print("Botão Jogar pressionado!")
	get_tree().change_scene_to_file("res://jogar.tscn")
	
func _on_lojinha_pressed():
	print("Botão Lojinha pressionado!")
	get_tree().change_scene_to_file("res://lojinha.tscn")

func _on_configuracoes_pressed():
	print("Botão Configurações pressionado!")
	get_tree().change_scene_to_file("res://configuracoes.tscn")

func _on_sair_pressed():
	get_tree().quit()
	
