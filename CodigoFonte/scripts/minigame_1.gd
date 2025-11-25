extends Node2D

const MAX_PASSOS_PILHA = 3
const MAX_PASSOS_FILA = 2
const MAX_PASSOS_DEQUE = 3
const TAMANHO_FILA = 3

const PERMITE_INSERCAO = "pilha"
const PERMITE_REMOCAO = "pilha"

const LISTA_INICIAL = ["a", "b", "c", "d", "e"]
const LISTA_DESEJADA = ["a", "b", "d", "c", "e"]

var passos_pilha = 0
var passos_fila = 0
var passos_deque = 0

var pilha = []
var fila = []
var deque = []

func _ready():
	preencher_lista_inicial()
	atualizar_lista_final()
	atualizar_slots_pilha()
	atualizar_slots_fila()
	atualizar_slots_deque()

func preencher_lista_inicial():
	for i in LISTA_INICIAL.size():
		var nome = "Minimal3/VBoxElementosInicial/HBoxElementosInicial/lblElemInicialSlot%d" % (i + 1)
		var lbl = get_node_or_null(nome)
		if lbl:
			lbl.text = LISTA_INICIAL[i]

func atualizar_lista_final():
	for i in LISTA_DESEJADA.size():
		var nome = "Minimal3/VBoxElementosFinal/HBoxElementosFinal/lblElemFinalSlot%d" % (i + 1)
		var lbl = get_node_or_null(nome)
		if lbl:
			lbl.text = LISTA_DESEJADA[i]

func pegar_elemento_input():
	var input = get_node_or_null("Minimal3/txtElementoInserir")
	return input.text.strip_edges() if input else ""

# PILHA
func on_btnAddPilha_pressed():
	if PERMITE_INSERCAO != "pilha" or passos_pilha >= MAX_PASSOS_PILHA:
		return
	var elem = pegar_elemento_input()
	if elem == "":
		return
	pilha.append(elem)
	passos_pilha += 1
	atualizar_slots_pilha()

func on_btnRemPilha_pressed():
	if PERMITE_REMOCAO != "pilha" or pilha.empty():
		return
	pilha.pop_back()
	atualizar_slots_pilha()

func atualizar_slots_pilha():
	for i in 5:
		var nome = "Minimal3/lblPilhaSlot%d" % (i + 1)
		var label = get_node_or_null(nome)
		if label:
			label.text = pilha[i] if i < pilha.size() else ""

# FILA
func on_btnAddFila_pressed():
	if PERMITE_INSERCAO != "fila" or passos_fila >= MAX_PASSOS_FILA or fila.size() >= TAMANHO_FILA:
		return
	var elem = pegar_elemento_input()
	if elem == "":
		return
	fila.append(elem)
	passos_fila += 1
	atualizar_slots_fila()

func on_btnRemFila_pressed():
	if PERMITE_REMOCAO != "fila" or fila.empty():
		return
	fila.pop_front()
	atualizar_slots_fila()

func atualizar_slots_fila():
	for i in 3:
		var nome = "Minimal3/lblFilaSlot%d" % (i + 1)
		var label = get_node_or_null(nome)
		if label:
			label.text = fila[i] if i < fila.size() else ""

# DEQUE
func on_btnAddDeque_pressed():
	if PERMITE_INSERCAO != "deque" or passos_deque >= MAX_PASSOS_DEQUE:
		return
	var elem = pegar_elemento_input()
	if elem == "":
		return
	deque.append(elem)
	passos_deque += 1
	atualizar_slots_deque()

func on_btnRemDeque_pressed():
	if PERMITE_REMOCAO != "deque" or deque.empty():
		return
	deque.pop_front()
	atualizar_slots_deque()

func atualizar_slots_deque():
	for i in 5:
		var nome = "Minimal3/lblDequeSlot%d" % (i + 1)
		var label = get_node_or_null(nome)
		if label:
			label.text = deque[i] if i < deque.size() else ""

# Conferência
func on_btnConferir_pressed():
	var resposta = []
	for i in 5:
		var nome = "Minimal3/VBoxElementosFinal/HBoxElementosFinal/lblElemFinalSlot%d" % (i + 1)
		var label = get_node_or_null(nome)
		if label:
			resposta.append(label.text)

	if resposta == LISTA_DESEJADA:
		print("Acertou!")
	else:
		print("Tente novamente.")
