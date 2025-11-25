extends Node2D

# ---------- Configuração do nível ----------
var lista_inicial = ["A","B","C","D","E"]
var lista_final   = ["A","B","D","C","E"]

var pilha: Array = []
var fila: Array = []
var deque: Array = []

var fila_capacidade: int = 3
var tempo_inicio: int = 0
var pontos: int = 1000

# ---------- Função segura para conectar botões ----------
func conectar_botao(path: NodePath, func_ref: Callable):
	var btn = get_node_or_null(path)
	if btn:
		btn.pressed.connect(func_ref)
	else:
		print("Botão não encontrado:", path)

# ---------- Ready ----------
func _ready():
	deque = lista_inicial.duplicate()
	tempo_inicio = Time.get_ticks_msec()

	# Conectar botões do deque
	conectar_botao("UI/HBoxDeque/btnAddFront", _on_add_front)
	conectar_botao("UI/HBoxDeque/btnAddBack", _on_add_back)
	conectar_botao("UI/HBoxDeque/btnRemFront", _on_rem_front)
	conectar_botao("UI/HBoxDeque/btnRemBack", _on_rem_back)
	conectar_botao("UI/HBoxDeque/btnToPilha", mover_para_pilha)
	conectar_botao("UI/HBoxDeque/btnToFila", mover_para_fila)

	# Conectar botões da pilha e fila
	conectar_botao("UI/VBoxPilha/btnToDequeFromPilha", mover_para_deque_de_pilha)
	conectar_botao("UI/HBoxFila/btnToDequeFromFila", mover_para_deque_de_fila)

	# Botão de verificação
	conectar_botao("UI/btnVerificar", _on_verificar)

	atualizar_ui()

func _process(_delta):
	atualizar_ui()

# ---------- Adição de elementos ----------
func _on_add_front():
	var input = get_node_or_null("UI/LineEditLetra")
	if input:
		if input.text != "":
			deque.insert(0, input.text.to_upper())
			input.text = ""  # limpa após adicionar

func _on_add_back():
	var input = get_node_or_null("UI/LineEditLetra")
	if input:
		if input.text != "":
			deque.append(input.text.to_upper())
			input.text = ""  # limpa após adicionar

# ---------- Remoção de elementos ----------
func _on_rem_front():
	if deque.size() > 0:
		deque.pop_front()

func _on_rem_back():
	if deque.size() > 0:
		deque.pop_back()

# ---------- Transmutações ----------
func mover_para_pilha():
	for i in range(deque.size()-1, -1, -1):
		pilha.insert(0, deque[i])
	deque.clear()

func mover_para_fila():
	var qtd = min(fila_capacidade, deque.size())
	for i in range(qtd):
		fila.append(deque[i])
	for i in range(qtd-1, -1, -1):
		deque.remove_at(i)

func mover_para_deque_de_pilha():
	for elem in pilha:
		deque.append(elem)
	pilha.clear()

func mover_para_deque_de_fila():
	for elem in fila:
		deque.append(elem)
	fila.clear()

# ---------- Verificação ----------
func _on_verificar():
	var lbl = get_node_or_null("UI/lblMensagem")
	if deque == lista_final:
		if lbl:
			lbl.text = "Parabéns! Você conseguiu!"
		salvar_resultado()
	else:
		if lbl:
			lbl.text = "Ainda não está correto."

func salvar_resultado():
	var save = ConfigFile.new()
	save.set_value("nivel1", "concluido", true)
	save.set_value("nivel1", "pontuacao", pontos)
	save.save("user://savegame.cfg")

# ---------- Atualização da UI ----------
func atualizar_ui():
	# Deque
	for i in range(5):
		var slot = get_node_or_null("UI/HBoxDeque/lblDequeSlot" + str(i+1))
		if slot:
			slot.text = deque[i] if i < deque.size() else "-"

	# Pilha
	for i in range(5):
		var slot = get_node_or_null("UI/VBoxPilha/lblPilhaSlot" + str(i+1))
		if slot:
			slot.text = pilha[i] if i < pilha.size() else "-"

	# Fila
	for i in range(fila_capacidade):
		var slot = get_node_or_null("UI/HBoxFila/lblFilaSlot" + str(i+1))
		if slot:
			slot.text = fila[i] if i < fila.size() else "-"

	# Tempo e pontos
	var tempo_decorrido = int((Time.get_ticks_msec() - tempo_inicio) / 1000)
	var lbl_tempo = get_node_or_null("UI/lblTempo")
	if lbl_tempo:
		lbl_tempo.text = "Tempo: %ds" % tempo_decorrido

	pontos = 1000
	if tempo_decorrido > 300:
		pontos -= (tempo_decorrido - 300) * 3
	pontos = max(pontos, 500)

	var lbl_pontos = get_node_or_null("UI/lblPontuacao")
	if lbl_pontos:
		lbl_pontos.text = "Pontuação: %d" % pontos
