# FeedbackPopup.gd
extends ConfirmationDialog

var is_success: bool = false
var detailed_message: String = ""
var parent_node: Node = null

func _ready():
	# Configurar o popup
	title = "Resultado"
	
	# Adicionar botões personalizados
	get_ok_button().text = "Tentar Novamente"
	add_button("Mostrar Solução", false, "show_solution")
	
	# Conectar sinais
	confirmed.connect(_on_try_again)
	custom_action.connect(_on_custom_action)

func setup(message: String, success: bool, parent: Node):
	detailed_message = message
	is_success = success
	parent_node = parent
	
	# Configurar texto baseado no resultado
	if success:
		dialog_text = "✅ Parabéns! Árvore correta!"
	else:
		dialog_text = "❌ Ainda não está correto"

func _on_try_again():
	# Fechar o popup - o usuário quer tentar novamente
	hide()
	queue_free()

func _on_custom_action(action: String):
	if action == "show_solution":
		# Fechar este popup primeiro
		hide()
		# Pedir ao parent node para mostrar a confirmação da solução
		if parent_node and parent_node.has_method("solicitar_mostrar_solucao"):
			parent_node.solicitar_mostrar_solucao()
		queue_free()
