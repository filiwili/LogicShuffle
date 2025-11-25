extends Node2D

@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var rich_text_label2: RichTextLabel = $RichTextLabel2
@onready var rich_text_label3: RichTextLabel = $RichTextLabel3
@onready var arrow_back: TextureButton = $ArrowBack  # Nova referência para o botão voltar
var button_hover_script: GDScript

var sobre_texto = """
[b]Jornada Educativa nas Estruturas de Dados[/b]

Este jogo foi desenvolvido para transformar o aprendizado de [b]estruturas de dados[/b] em uma experiência divertida e interativa, combinando desafios de lógica com conceitos fundamentais da computação.

[b]Os Dois Mundos do Conhecimento:[/b]

[b]Jogo 1: Dungeon Cave Quest[/b]
• [i]Filas, Pilhas e Deques[/i]
• Aprenda operações básicas como enfileirar, empilhar e manipular elementos
• Desafios progressivos que simulam situações do mundo real

[b]Jogo 2: Pyramid Maker[/b]  
• [i]Árvores, BSTs e Percursos[/i]
• Domine a construção e navegação em estruturas hierárquicas
• Algoritmos de busca e organização de dados

[b]Objetivo Educacional:[/b]

• Tornar conceitos abstratos em visualizações tangíveis
• Desenvolver pensamento algorítmico através da prática
• Mostrar a aplicação prática das estruturas de dados

- A ideia é que esse jogo seja futuramente expandível, no sentido de ter mais níveis e mais jogos também.

[i]"A melhor maneira de aprender é fazendo - e se divertindo no processo!"[/i]
"""

var criador_filipe = """
[b]Filipe de Moura Affonso[/b]
Estudante da Fatec Sorocaba
E-mail para contato: filipe.affonso@fatec.sp.gov.br
"""

var criador_caua = """
[b]Cauã Rodrigues Viana[/b]
Estudante da Fatec Sorocaba
E-mail para contato: caua.viana01@fatec.sp.gov.br
"""

func _ready():
	# Configurar o texto principal
	if rich_text_label:
		rich_text_label.bbcode_enabled = true
		rich_text_label.text = sobre_texto
	else:
		print("❌ RichTextLabel não encontrado!")
	
	# Configurar o texto do primeiro criador
	if rich_text_label2:
		rich_text_label2.bbcode_enabled = true
		rich_text_label2.text = criador_filipe
	else:
		print("❌ RichTextLabel2 não encontrado!")
	
	# Configurar o texto do segundo criador
	if rich_text_label3:
		rich_text_label3.bbcode_enabled = true
		rich_text_label3.text = criador_caua
	else:
		print("❌ RichTextLabel3 não encontrado!")
	
	# Conectar o botão ArrowBack para voltar ao Main
	if arrow_back:
		arrow_back.pressed.connect(_on_arrow_back_pressed)
		print("✅ ArrowBack conectado com sucesso")
	else:
		print("❌ ArrowBack não encontrado!")

	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# Aplicar efeito hover após um pequeno delay para garantir que todos os botões estejam carregados
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()


# Função para voltar à tela principal
func _on_arrow_back_pressed():
	print("← Voltando para tela principal...")
	get_tree().change_scene_to_file("res://Main.tscn")



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
