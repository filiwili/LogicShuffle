extends Node2D

# Remove todos os Labels filhos antes de redesenhar
func limpar_nos():
	for child in get_children():
		if child is Label:
			child.queue_free()

# Desenha a árvore e cria Labels para os valores
func desenhar_arvore(no, pos = Vector2(400,50), offset_x = 200):
	if no == null:
		return

	limpar_nos()  # limpa Labels antigos para redesenhar

	_desenhar_recursivo(no, pos, offset_x)

func _desenhar_recursivo(no, pos, offset_x):
	if no == null:
		return
	no["pos"] = pos

	# Desenhar círculo
	draw_circle(pos, 20, Color(0.4, 0.6, 1))

	# Criar Label para o valor
	var lbl = Label.new()
	lbl.text = str(no["valor"])
	lbl.position = pos - Vector2(8, 8)
	add_child(lbl)

	# Desenhar filhos
	if no["esquerda"] != null:
		draw_line(pos, pos + Vector2(-offset_x, 100), Color(1,1,1), 2)
		_desenhar_recursivo(no["esquerda"], pos + Vector2(-offset_x, 100), offset_x / 1.5)
	if no["direita"] != null:
		draw_line(pos, pos + Vector2(offset_x, 100), Color(1,1,1), 2)
		_desenhar_recursivo(no["direita"], pos + Vector2(offset_x, 100), offset_x / 1.5)
