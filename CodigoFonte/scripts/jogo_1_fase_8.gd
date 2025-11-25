extends Node2D

# ---------- Estruturas ----------
var fila: Array = ["A","B","E"]
var pilha: Array = ["C","D"]   # fila invertida
var deque: Array = ["F","G","H"]

# Capacidade reduzida para 5 slots
var fila_capacidade: int = 5
var pilha_capacidade: int = 5
var deque_capacidade: int = 5

var tempo_inicio: int = 0
var pontos: int = 1000
var nivel_concluido: bool = false
var solucionado: bool = false
var primeira_conclusao: bool = true

# ---------- Sistema de Seleção de Elementos ----------
var elemento_selecionado: String = ""
var operacao_pendente: String = ""
var popup_selecao: Window

# ---------- Sistema de Conclusão ----------
var popup_conclusao: AcceptDialog
var redirecionamento_auto_timer: Timer
var redirecionamento_ok_timer: Timer
var redirecionamento_em_andamento: bool = false

# Elementos disponíveis para a caverna
var elementos_caverna = {
	"E": {"nome": "José", "textura": "res://assets/jose.png"},
	"A": {"nome": "Pedra", "textura": "res://assets/pedra.png"},
	"B": {"nome": "Cristal", "textura": "res://assets/cristal.png"},
	"C": {"nome": "Cogumelo", "textura": "res://assets/cogumelo.png"},
	"D": {"nome": "Osso", "textura": "res://assets/osso.png"},
	"F": {"nome": "Moeda", "textura": "res://assets/moeda.png"},
	"G": {"nome": "Pérola", "textura": "res://assets/perola.png"},
	"H": {"nome": "Diamante", "textura": "res://assets/diamante.png"}
}

# Textura do slot vazio
var textura_slot_vazio = preload("res://assets/slot_bg.png")

# ---------- Popups ----------
var feedback_popup: ConfirmationDialog
var confirmacao_popup: ConfirmationDialog

var button_hover_script: GDScript

# ---------- Função segura para conectar ----------
func conectar_botao(path: NodePath, func_ref: Callable):
	var btn = get_node_or_null(path)
	if btn:
		btn.pressed.connect(func_ref)
	else:
		print("Botão não encontrado:", path)

# ---------- Ready ----------
func _ready():
	tempo_inicio = Time.get_ticks_msec()
	
	# Debug do SessionManager
	print("=== DEBUG SESSION MANAGER ===")
	if SessionManager:
		print("SessionManager disponível")
		print("User:", SessionManager.user_name)
		print("Token:", SessionManager.auth_token)
	else:
		print("❌ SessionManager NÃO disponível")
	print("=============================")
	
	# Conectar botões Deque
	conectar_botao("UI/HBoxDeque/btnAddFront", _on_add_front_deque)
	conectar_botao("UI/HBoxDeque/btnAddBack", _on_add_back_deque)
	conectar_botao("UI/HBoxDeque/btnRemFront", _on_rem_front_deque)
	conectar_botao("UI/HBoxDeque/btnRemBack", _on_rem_back_deque)
	conectar_botao("UI/HBoxDeque/btnToPilha", mover_para_pilha)
	conectar_botao("UI/HBoxDeque/btnToFila", mover_para_fila)

	# Conectar botões Pilha
	conectar_botao("UI/VBoxPilha/btnAddPilha", _on_add_pilha)
	conectar_botao("UI/VBoxPilha/btnRemPilha", _on_rem_pilha)
	conectar_botao("UI/btnToDequeFromPilha", mover_para_deque_de_pilha)
	conectar_botao("UI/btnToFilaFromPilha", mover_para_fila_from_pilha)

	# Conectar botões Fila
	conectar_botao("UI/HBoxFila/btnAddFila", _on_add_fila)
	conectar_botao("UI/HBoxFila/btnRemFila", _on_rem_fila)
	conectar_botao("UI/HBoxFila/btnToDequeFromFila", mover_para_deque_de_fila)
	conectar_botao("UI/HBoxFila/btnToPilhaFromFila", mover_para_pilha_from_fila)

	# Botão verificar
	conectar_botao("UI/btnVerificar", _on_verificar)
	
	# Botão sair
	conectar_botao("QuitButton", _on_sair_pressed)

	# Historinha
	conectar_botao("UI/btnHistoria", _on_btn_historia)
	conectar_botao("CanvasLayer/PopupHistoria/btnFechar", _on_btn_fechar)

	# Configurar popups
	_setup_popups()
	
	# Configurar sistema de seleção de elementos
	_setup_selecao_elementos()
	
	# Configurar sistema de conclusão
	_setup_sistema_conclusao()

	# Verificar se já foi concluído antes
	verificar_primeira_conclusao()

	# Mostrar historinha sempre
	abrir_historia()

	atualizar_ui()
	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# Aplicar efeito hover após um pequeno delay para garantir que todos os botões estejam carregados
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()
	
# ---------- Sistema de Conclusão ----------
func _setup_sistema_conclusao():
	# Criar popup de conclusão
	popup_conclusao = AcceptDialog.new()
	popup_conclusao.title = "🎉 Nível Concluído!"
	popup_conclusao.unresizable = true
	popup_conclusao.confirmed.connect(_on_conclusao_ok_pressed)
	add_child(popup_conclusao)
	
	# Criar timer para redirecionamento automático (10 segundos)
	redirecionamento_auto_timer = Timer.new()
	redirecionamento_auto_timer.wait_time = 10.0
	redirecionamento_auto_timer.one_shot = true
	redirecionamento_auto_timer.timeout.connect(_on_redirecionamento_auto_timeout)
	add_child(redirecionamento_auto_timer)
	
	# Criar timer para redirecionamento após OK (2 segundos)
	redirecionamento_ok_timer = Timer.new()
	redirecionamento_ok_timer.wait_time = 2.0
	redirecionamento_ok_timer.one_shot = true
	redirecionamento_ok_timer.timeout.connect(_on_redirecionamento_ok_timeout)
	add_child(redirecionamento_ok_timer)

func mostrar_conclusao_nivel():
	if SettingsManager:
		SettingsManager.play_sound("res://sounds/crowdcheer.wav", "SFX")
	var tempo_total = int((Time.get_ticks_msec() - tempo_inicio) / 1000)
	var minutos = tempo_total / 60
	var segundos = tempo_total % 60
	
	var texto_conclusao = "✅ Nível Concluído!\nPontuação: %d pontos\nTempo: %02d:%02d\n\nRedirecionando em 10s...\nOK para 2s" % [pontos, minutos, segundos]
	
	popup_conclusao.dialog_text = texto_conclusao
	
	# Popup menor e mais compacto
	var popup_size = Vector2(200, 100)
	var screen_size = get_viewport().get_visible_rect().size
	var popup_position = Vector2((screen_size.x - popup_size.x) / 2, 20)  # 20 pixels do topo
	
	if popup_conclusao.visible:
		popup_conclusao.hide()
	
	popup_conclusao.popup(Rect2(popup_position, popup_size))
	
	# Iniciar timer para redirecionamento automático
	redirecionamento_auto_timer.start()
	redirecionamento_em_andamento = false

func _on_conclusao_ok_pressed():
	# Se o jogador apertou OK, cancelar o timer automático e iniciar o de 2 segundos
	if redirecionamento_auto_timer.time_left > 0:
		redirecionamento_auto_timer.stop()
		redirecionamento_ok_timer.start()
		
		# Atualizar texto para mostrar que vai redirecionar em 2 segundos
		var tempo_total = int((Time.get_ticks_msec() - tempo_inicio) / 1000)
		var minutos = tempo_total / 60
		var segundos = tempo_total % 60
		popup_conclusao.dialog_text = "✅ Nível Concluído com Sucesso!\n\nPontuação: %d pontos\nTempo: %02d:%02d\n\nRedirecionando em 2 segundos..." % [pontos, minutos, segundos]

func _on_redirecionamento_auto_timeout():
	# Redirecionamento automático após 10 segundos
	redirecionamento_em_andamento = true
	popup_conclusao.hide()
	get_tree().change_scene_to_file("res://Niveis1.tscn")

func _on_redirecionamento_ok_timeout():
	# Redirecionamento após 2 segundos do OK
	redirecionamento_em_andamento = true
	popup_conclusao.hide()
	get_tree().change_scene_to_file("res://Niveis1.tscn")

func _setup_selecao_elementos():
	# Criar popup de seleção de elementos
	popup_selecao = Window.new()
	popup_selecao.title = "Selecionar Elemento da Caverna"
	popup_selecao.size = Vector2(550, 500)
	popup_selecao.unresizable = true
	popup_selecao.close_requested.connect(_on_popup_selecao_fechado)
	
	# Criar container para os elementos
	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_selecao.add_child(vbox)
	
	# Título
	var label = Label.new()
	label.text = "Escolha um elemento para adicionar:"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	# Grid de elementos
	var grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	vbox.add_child(grid)
	
	# Criar botões para cada elemento
	for elemento_id in elementos_caverna:
		var elemento_data = elementos_caverna[elemento_id]
		
		# Usar Button normal em vez de TextureButton para melhor controle
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 120)
		btn.flat = true  # Remove o estilo padrão do botão
		
		# Container para organizar imagem e texto
		var container = VBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_CENTER
		btn.add_child(container)
		
		# TextureRect para a imagem
		var texture_rect = TextureRect.new()
		var textura = load(elemento_data["textura"])
		if textura:
			texture_rect.texture = textura
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.custom_minimum_size = Vector2(60, 60)
		else:
			print("❌ Não foi possível carregar a textura: ", elemento_data["textura"])
		
		# Label com nome do elemento
		var label_elemento = Label.new()
		label_elemento.text = elemento_data["nome"] + " (" + elemento_id + ")"
		label_elemento.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		container.add_child(texture_rect)
		container.add_child(label_elemento)
		
		btn.pressed.connect(_on_elemento_selecionado.bind(elemento_id))
		grid.add_child(btn)
	
	# Botão cancelar
	var btn_cancelar = Button.new()
	btn_cancelar.text = "Cancelar"
	btn_cancelar.pressed.connect(_on_popup_selecao_fechado)
	vbox.add_child(btn_cancelar)
	
	add_child(popup_selecao)
	popup_selecao.hide()

func _on_elemento_selecionado(elemento_id: String):
	elemento_selecionado = elemento_id
	popup_selecao.hide()
	_executar_operacao_pendente()

func _on_popup_selecao_fechado():
	elemento_selecionado = ""
	operacao_pendente = ""
	popup_selecao.hide()

func _executar_operacao_pendente():
	if elemento_selecionado == "" or operacao_pendente == "":
		return
	
	match operacao_pendente:
		"add_front_deque":
			if deque.size() < deque_capacidade:
				deque.insert(0, elemento_selecionado)
		"add_back_deque":
			if deque.size() < deque_capacidade:
				deque.append(elemento_selecionado)
		"add_pilha":
			if pilha.size() < pilha_capacidade:
				pilha.insert(0, elemento_selecionado)
		"add_fila":
			if fila.size() < fila_capacidade:
				fila.append(elemento_selecionado)
	
	# Resetar
	elemento_selecionado = ""
	operacao_pendente = ""
	atualizar_ui()

func _setup_popups():
	# Criar popup de feedback (que mostra os erros)
	feedback_popup = ConfirmationDialog.new()
	feedback_popup.title = "Resultado da Verificação"
	feedback_popup.get_ok_button().text = "Tentar Novamente"
	feedback_popup.confirmed.connect(_on_feedback_try_again)
	feedback_popup.close_requested.connect(_on_feedback_closed)
	add_child(feedback_popup)
	
	# Criar popup de confirmação para mostrar solução
	confirmacao_popup = ConfirmationDialog.new()
	confirmacao_popup.title = "Confirmar Mostrar Solução"
	confirmacao_popup.dialog_text = "Ver a solução reduzirá sua pontuação máxima para 500 pontos. Tem certeza?"
	confirmacao_popup.get_ok_button().text = "Sim, Mostrar Solução"
	confirmacao_popup.get_cancel_button().text = "Cancelar"
	confirmacao_popup.confirmed.connect(_on_confirmar_mostrar_solucao)
	confirmacao_popup.canceled.connect(_on_cancelar_mostrar_solucao)
	add_child(confirmacao_popup)

func verificar_primeira_conclusao():
	# SEMPRE considerar como primeira conclusão para novos usuários
	# A verificação real será feita pelo servidor
	primeira_conclusao = true
	
	# Verificar com o ProgressManager se há dados do servidor
	if ProgressManager:
		var level_data = ProgressManager.get_level_data("nivel8", "1")
		if level_data and level_data.get("completed", false):
			primeira_conclusao = false
			print("✅ Nível já concluído anteriormente (dados do servidor)")
		else:
			print("🆕 Primeira vez neste nível")
	else:
		print("⚠️ ProgressManager não disponível, assumindo primeira vez")

func _process(_delta):
	if not nivel_concluido:
		atualizar_pontuacao_tempo()
	atualizar_ui()

# ---------- Deque ----------
func _on_add_front_deque():
	if nivel_concluido: return
	operacao_pendente = "add_front_deque"
	popup_selecao.popup_centered()

func _on_add_back_deque():
	if nivel_concluido: return
	operacao_pendente = "add_back_deque"
	popup_selecao.popup_centered()

func _on_rem_front_deque():
	if nivel_concluido: return
	if deque.size() > 0:
		deque.pop_front()
		atualizar_ui()

func _on_rem_back_deque():
	if nivel_concluido: return
	if deque.size() > 0:
		deque.pop_back()
		atualizar_ui()

# ---------- Pilha ----------
func _on_add_pilha():
	if nivel_concluido: return
	operacao_pendente = "add_pilha"
	popup_selecao.popup_centered()

func _on_rem_pilha():
	if nivel_concluido: return
	if pilha.size() > 0:
		pilha.pop_front()
		atualizar_ui()

# ---------- Fila ----------
func _on_add_fila():
	if nivel_concluido: return
	operacao_pendente = "add_fila"
	popup_selecao.popup_centered()

func _on_rem_fila():
	if nivel_concluido: return
	if fila.size() > 0:
		fila.pop_front()
		atualizar_ui()

# ---------- Transições ----------
func mover_para_pilha():
	if nivel_concluido: return
	if deque.size() > 0:
		for i in range(deque.size()-1, -1, -1):
			if pilha.size() < pilha_capacidade:
				pilha.insert(0, deque[i])
		deque.clear()
		atualizar_ui()

func mover_para_fila():
	if nivel_concluido: return
	if deque.size() > 0:
		var qtd = min(fila_capacidade - fila.size(), deque.size())
		for i in range(qtd):
			fila.append(deque[i])
		for i in range(qtd-1, -1, -1):
			deque.remove_at(i)
		atualizar_ui()

func mover_para_deque_de_pilha():
	if nivel_concluido: return
	for elem in pilha:
		if deque.size() < deque_capacidade:
			deque.append(elem)
	pilha.clear()
	atualizar_ui()

func mover_para_deque_de_fila():
	if nivel_concluido: return
	for elem in fila:
		if deque.size() < deque_capacidade:
			deque.append(elem)
	fila.clear()
	atualizar_ui()

func mover_para_fila_from_pilha():
	if nivel_concluido: return
	for elem in pilha:
		if fila.size() < fila_capacidade:
			fila.append(elem)
	pilha.clear()
	atualizar_ui()

func mover_para_pilha_from_fila():
	if nivel_concluido: return
	for i in range(fila.size()-1, -1, -1):
		if pilha.size() < pilha_capacidade:
			pilha.insert(0, fila[i])
	fila.clear()
	atualizar_ui()

# ---------- Verificação ----------
func _on_verificar():
	if nivel_concluido: return
	
	var resultado = verificar_solucao()
	
	if resultado.is_valid:
		# Não mostrar mais o feedback_popup para sucesso
		nivel_concluido = true
		salvar_resultado()  # Isso vai chamar mostrar_conclusao_nivel()
	else:
		show_feedback_popup(resultado.message, false)

func verificar_solucao() -> Dictionary:
	# Verificar a pilha (Túnel Invertido): C, D, C (do topo para o fundo)
	var ordem_pilha_esperada = ["C", "D", "C"]
	var ordem_fila_esperada = ["A", "B", "E", "G"]
	
	var erros = []
	
	# Verificar pilha
	if pilha != ordem_pilha_esperada:
		if pilha.size() != ordem_pilha_esperada.size():
			erros.append("A pilha (Túnel Invertido) não tem a quantidade correta de elementos. Esperados: %d, Atuais: %d." % [ordem_pilha_esperada.size(), pilha.size()])
		else:
			for i in range(pilha.size()):
				if pilha[i] != ordem_pilha_esperada[i]:
					var elemento_esperado = elementos_caverna[ordem_pilha_esperada[i]]["nome"]
					var elemento_atual = elementos_caverna[pilha[i]]["nome"] if elementos_caverna.has(pilha[i]) else "Desconhecido"
					var posicao = ""
					match i:
						0: posicao = "topo"
						1: posicao = "meio"
						2: posicao = "fundo"
					erros.append("Ordem incorreta na pilha (%s). Esperado: %s (%s), Atual: %s (%s)." % [posicao, ordem_pilha_esperada[i], elemento_esperado, pilha[i], elemento_atual])
					break
	
	# Verificar fila
	if fila != ordem_fila_esperada:
		if fila.size() != ordem_fila_esperada.size():
			erros.append("A fila (Túnel Linear) não tem a quantidade correta de elementos. Esperados: %d, Atuais: %d." % [ordem_fila_esperada.size(), fila.size()])
		else:
			for i in range(fila.size()):
				if fila[i] != ordem_fila_esperada[i]:
					var elemento_esperado = elementos_caverna[ordem_fila_esperada[i]]["nome"]
					var elemento_atual = elementos_caverna[fila[i]]["nome"] if elementos_caverna.has(fila[i]) else "Desconhecido"
					var posicao = ""
					match i:
						0: posicao = "início"
						1: posicao = "segunda posição"
						2: posicao = "terceira posição"
						3: posicao = "final"
					erros.append("Ordem incorreta na fila (%s). Esperado: %s (%s), Atual: %s (%s)." % [posicao, ordem_fila_esperada[i], elemento_esperado, fila[i], elemento_atual])
					break
	
	# Se não há erros, sucesso
	if erros.size() == 0:
		return {"is_valid": true, "message": "🎉 Parabéns! José dominou a bruxaria dupla! Ambas as estruturas estão com as ordens corretas!"}
	
	# Construir mensagem de erro
	var mensagem_erro = "Ainda existem problemas:\n\n"
	for erro in erros:
		mensagem_erro += "• " + erro + "\n"
	
	mensagem_erro += "\nLembre-se:\n"
	mensagem_erro += "- Túnel Invertido (pilha): Cogumelo, Osso, Cogumelo (do topo para o fundo)\n"
	mensagem_erro += "- Túnel Linear (fila): Pedra, Cristal, José, Pérola (do início para o final)"
	
	return {"is_valid": false, "message": mensagem_erro}

func show_feedback_popup(message: String, is_success: bool):
	if is_success:
		feedback_popup.dialog_text = "✅ Parabéns! Resposta correta!\n\n" + message
		feedback_popup.get_ok_button().text = "OK"
		feedback_popup.get_cancel_button().visible = false
	else:
		feedback_popup.dialog_text = "❌ Ainda não está correto\n\n" + message
		feedback_popup.get_ok_button().text = "Tentar Novamente"
		var cancel_button = feedback_popup.get_cancel_button()
		cancel_button.visible = true
		cancel_button.text = "Mostrar Solução"
		if not feedback_popup.canceled.is_connected(_on_feedback_show_solution_requested):
			feedback_popup.canceled.connect(_on_feedback_show_solution_requested)
	
	feedback_popup.popup_centered(Vector2(500, 300))

func _on_feedback_closed():
	feedback_popup.hide()

func _on_feedback_try_again():
	feedback_popup.hide()

func _on_feedback_show_solution_requested():
	feedback_popup.hide()
	confirmacao_popup.popup_centered(Vector2(500, 200))
	feedback_popup.canceled.disconnect(_on_feedback_show_solution_requested)

func _on_confirmar_mostrar_solucao():
	solucionado = true
	pontos = 500
	
	# Aplicar a solução
	mostrar_solucao()
	
	if SettingsManager:
		SettingsManager.play_sound("res://sounds/crowdcheer.wav", "SFX")
	
	# Marcar como concluído e salvar os 500 pontos
	nivel_concluido = true
	salvar_resultado()  # Isso agora vai chamar mostrar_conclusao_nivel()

func _on_cancelar_mostrar_solucao():
	confirmacao_popup.hide()

func mostrar_solucao():
	# Limpar todas as estruturas
	fila.clear()
	pilha.clear()
	deque.clear()
	
	# Preencher a pilha (Túnel Invertido) com: C, D, C (do topo para o fundo)
	pilha.append("C")  # Topo - primeiro Cogumelo
	pilha.append("D")  # Meio - Osso
	pilha.append("C")  # Fundo - segundo Cogumelo
	
	# Preencher a fila (Túnel Linear) com: A, B, E, G (do início para o final)
	fila.append("A")  # Pedra
	fila.append("B")  # Cristal
	fila.append("E")  # José
	fila.append("G")  # Pérola
	
	atualizar_ui()

func atualizar_pontuacao_tempo():
	var tempo_decorrido = int((Time.get_ticks_msec() - tempo_inicio) / 1000)
	
	# Pontuação base: 1000 pontos
	# Penalidade por tempo: -3 pontos por segundo acima de 60 segundos
	# Mínimo: 500 pontos
	pontos = 1000
	if tempo_decorrido > 60:
		pontos -= (tempo_decorrido - 60) * 3
	pontos = max(pontos, 500)
	
	# Se viu solução, máximo é 500
	if solucionado:
		pontos = min(pontos, 500)

func salvar_resultado():
	print("💾 Salvando resultado do nível 1...")
	print("📊 Pontuação: ", pontos)
	print("⏰ Tempo: ", int((Time.get_ticks_msec() - tempo_inicio) / 1000), "s")
	
	# CORREÇÃO: Verificar autenticação
	if not SessionManager or not SessionManager.is_authenticated():
		print("❌ Usuário não autenticado - não é possível salvar progresso")
		mostrar_conclusao_nivel()
		return
	
	if primeira_conclusao:
		print("✅ Primeira conclusão - enviando para o servidor via ProgressManager")
		
		if ProgressManager:
			# CORREÇÃO: Conectar o sinal ANTES de chamar mark_level_completed
			if not ProgressManager.progress_saved.is_connected(_on_progresso_salvo):
				ProgressManager.progress_saved.connect(_on_progresso_salvo, CONNECT_ONE_SHOT)
			
			ProgressManager.mark_level_completed("nivel8", pontos)
			print("📤 Progresso enviado para o ProgressManager")
		else:
			print("❌ ProgressManager não disponível")
		
		primeira_conclusao = false
	else:
		print("ℹ️  Nível já foi concluído anteriormente")
	
	mostrar_conclusao_nivel()

# CORREÇÃO: Nova função para quando o progresso é salvo no servidor
func _on_progresso_salvo(level_name: String, score: int):
	print("🎉 Progresso confirmado no servidor: ", level_name, " - Score: ", score)
	# Desconectar o sinal para garantir que não seja chamado novamente
	if ProgressManager and ProgressManager.progress_saved.is_connected(_on_progresso_salvo):
		ProgressManager.progress_saved.disconnect(_on_progresso_salvo)

func enviar_pontuacao_servidor():
	# Verificar se temos token de autenticação
	if not SessionManager:
		return
	
	if SessionManager.auth_token == "":
		return
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(_on_pontuacao_enviada.bind(http_request))
	
	var body = {
		"level": "nivel8",
		"score": pontos,
		"time": int((Time.get_ticks_msec() - tempo_inicio) / 1000)
	}
	
	var body_string = JSON.stringify(body)
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + SessionManager.auth_token]
	
	var error = http_request.request("http://127.0.0.1:5000/save-score", headers, HTTPClient.METHOD_POST, body_string)
	if error != OK:
		http_request.queue_free()

func _on_pontuacao_enviada(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	if http_request:
		http_request.queue_free()

# ---------- Atualização UI ----------
func atualizar_ui():
	# Deque - mantém o tamanho atual (que está bom)
	for i in range(deque_capacidade):
		var slot = get_node_or_null("UI/HBoxDeque/SlotDeque" + str(i+1))
		if slot and slot is TextureRect:
			if i < deque.size():
				var elemento_id = deque[i]
				var textura_path = elementos_caverna[elemento_id]["textura"]
				var textura = load(textura_path)
				if textura:
					slot.texture = textura
					slot.tooltip_text = elementos_caverna[elemento_id]["nome"]
					slot.modulate = Color(1, 1, 1, 1)
					# Não alteramos o tamanho do Deque pois já está bom
			else:
				slot.texture = textura_slot_vazio
				slot.tooltip_text = "Slot vazio"
				slot.modulate = Color(1, 1, 1, 0.7)

	# Pilha - aumentamos o tamanho para igualar ao Deque
	for i in range(pilha_capacidade):
		var slot = get_node_or_null("UI/VBoxPilha/SlotPilha" + str(i+1))
		if slot and slot is TextureRect:
			if i < pilha.size():
				var elemento_id = pilha[i]
				var textura_path = elementos_caverna[elemento_id]["textura"]
				var textura = load(textura_path)
				if textura:
					slot.texture = textura
					slot.tooltip_text = elementos_caverna[elemento_id]["nome"]
					slot.modulate = Color(1, 1, 1, 1)
					# Aumentamos o tamanho da Pilha para igualar ao Deque
					slot.custom_minimum_size = Vector2(80, 80)
			else:
				slot.texture = textura_slot_vazio
				slot.tooltip_text = "Slot vazio"
				slot.modulate = Color(1, 1, 1, 0.7)
				# Aumentamos o tamanho do slot vazio também
				slot.custom_minimum_size = Vector2(80, 80)

	# Fila - aumentamos o tamanho para igualar ao Deque
	for i in range(fila_capacidade):
		var slot = get_node_or_null("UI/HBoxFila/SlotFila" + str(i+1))
		if slot and slot is TextureRect:
			if i < fila.size():
				var elemento_id = fila[i]
				var textura_path = elementos_caverna[elemento_id]["textura"]
				var textura = load(textura_path)
				if textura:
					slot.texture = textura
					slot.tooltip_text = elementos_caverna[elemento_id]["nome"]
					slot.modulate = Color(1, 1, 1, 1)
					# Aumentamos o tamanho da Fila para igualar ao Deque
					slot.custom_minimum_size = Vector2(80, 80)
			else:
				slot.texture = textura_slot_vazio
				slot.tooltip_text = "Slot vazio"
				slot.modulate = Color(1, 1, 1, 0.7)
				# Aumentamos o tamanho do slot vazio também
				slot.custom_minimum_size = Vector2(80, 80)

	# Tempo e pontos
	var tempo_decorrido = int((Time.get_ticks_msec() - tempo_inicio) / 1000)
	var lbl_tempo = get_node_or_null("UI/lblTempo")
	if lbl_tempo:
		lbl_tempo.text = "Tempo: %ds" % tempo_decorrido

	var lbl_pontos = get_node_or_null("UI/lblPontuacao")
	if lbl_pontos:
		lbl_pontos.text = "Pontuação: %d" % pontos

# ---------- Historinha ----------
func abrir_historia():
	# Ocultar a UI para que nada apareça por baixo
	var ui = get_node("UI")
	ui.hide()

	# Mostrar overlay e popup
	var overlay = get_node("CanvasLayer/Overlay")
	var popup = get_node("CanvasLayer/PopupHistoria")
	overlay.show()
	popup.show()
	
	# CORREÇÃO: Configurar o overlay para não bloquear eventos do mouse
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Configurar texto da historinha - ATUALIZADA PARA A CAVERNA
	var lblTexto = popup.get_node("lblTexto")
	if lblTexto is RichTextLabel:
		lblTexto.bbcode_enabled = true
		lblTexto.text = """
Em uma caverna misteriosa existem três caminhos:

Cada caminho pode ser utilizado como um meio de bruxaria para certos experimentos, como também pode ser utilizado como um meio de locomoção.
→ [b]Túnel Linear[/b]: o primeiro que entra é o primeiro que sai
→ [b]Túnel Invertido[/b]: o último que entra é o primeiro que sai  
→ [b]Galeria Dupla[/b]: um corredor com duas entradas e duas saídas

José agora evoluirá um passo em suas bruxarias: ele utilizará dois caminhos ao mesmo tempo:
Em Túnel Invertido (do topo, para o fundo) você precisará de: cogumelo, osso, cogumelo
Em Túnel Linear, você precisará de: pedra, cristal, josé, pérola.
""" 

func _on_btn_historia():
	abrir_historia()

func _on_btn_fechar():
	# Mostrar UI novamente
	var ui = get_node("UI")
	ui.show()

	# Esconder overlay e popup
	var popup = get_node("CanvasLayer/PopupHistoria")
	var overlay = get_node("CanvasLayer/Overlay")
	popup.hide()
	overlay.hide()

	# Salvar que já viu a historinha
	var save = ConfigFile.new()
	save.set_value("nivel8", "historia_vista", true)
	save.save("user://savegame.cfg")

# ---------- Botão Sair ----------
func _on_sair_pressed():
	# Fechar qualquer popup aberto antes de sair
	if feedback_popup and feedback_popup.visible:
		feedback_popup.hide()
	if confirmacao_popup and confirmacao_popup.visible:
		confirmacao_popup.hide()
	if popup_selecao and popup_selecao.visible:
		popup_selecao.hide()
	
	# FECHAR TAMBÉM O POPUP DE HISTÓRIA SE ESTIVER ABERTO
	var popup_historia = get_node_or_null("CanvasLayer/PopupHistoria")
	if popup_historia and popup_historia.visible:
		popup_historia.hide()
		var overlay = get_node_or_null("CanvasLayer/Overlay")
		if overlay and overlay.visible:
			overlay.hide()
		# Mostrar a UI novamente
		var ui = get_node_or_null("UI")
		if ui:
			ui.show()
	
	# Parar quaisquer timers de redirecionamento
	if redirecionamento_auto_timer and redirecionamento_auto_timer.time_left > 0:
		redirecionamento_auto_timer.stop()
	if redirecionamento_ok_timer and redirecionamento_ok_timer.time_left > 0:
		redirecionamento_ok_timer.stop()
	
	get_tree().change_scene_to_file("res://Niveis1.tscn")



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
