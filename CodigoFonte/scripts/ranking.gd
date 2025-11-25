extends Control

# Referências para os nós da cena
@onready var container_ranking: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var lista_ranking: VBoxContainer = $ScrollContainer/VBoxContainer/ListaRanking
@onready var cabecalho_ranking: HBoxContainer = $ScrollContainer/VBoxContainer/CabecalhoRanking
@onready var panel_sua_posicao: Panel = $PanelSuaPosicao
@onready var label_sua_posicao: Label = $PanelSuaPosicao/LabelSuaPosicao
@onready var texture_sua_foto: TextureRect = $PanelSuaPosicao/HBoxContainerUsuario/TextureRectSuaFoto
@onready var label_seu_nome: Label = $PanelSuaPosicao/HBoxContainerUsuario/LabelSeuNome
@onready var label_sua_pontuacao: Label = $PanelSuaPosicao/LabelSuaPontuacao
@onready var label_seus_niveis: Label = $PanelSuaPosicao/LabelSeusNiveis
@onready var label_carregando: Label = $LabelCarregando
@onready var label_erro: Label = $LabelErro
@onready var arrow_back: TextureButton = $ArrowBack
var button_hover_script: GDScript

var http: HTTPRequest

func _ready():
	print("=== INICIANDO RANKING DINÂMICO ===")
	
	# Configurar a foto do usuário no painel para ter tamanho fixo
	if texture_sua_foto:
		texture_sua_foto.custom_minimum_size = Vector2(60, 60)
		texture_sua_foto.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_sua_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_sua_foto.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		texture_sua_foto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Debug das referências
	print("🔍 Referências carregadas:")
	print("  container_ranking: ", container_ranking != null)
	print("  lista_ranking: ", lista_ranking != null)
	print("  cabecalho_ranking: ", cabecalho_ranking != null)
	print("  panel_sua_posicao: ", panel_sua_posicao != null)
	print("  label_carregando: ", label_carregando != null)
	print("  label_erro: ", label_erro != null)
	print("  arrow_back: ", arrow_back != null)
	
	# Verificar SessionManager
	if not SessionManager or SessionManager.auth_token == "":
		print("❌ SessionManager não disponível")
		mostrar_erro("Faça login para ver o ranking")
		return
	
	print("✅ SessionManager disponível - User:", SessionManager.user_name)
	
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_ranking_carregado)
	
	if arrow_back:
		arrow_back.pressed.connect(_on_voltar_pressed)
	else:
		print("❌ ArrowBack não encontrado")
	
	carregar_ranking()
	
	button_hover_script = preload("res://ButtonHoverEffect.gd")
	
	# Aplicar efeito hover após um pequeno delay para garantir que todos os botões estejam carregados
	await get_tree().create_timer(0.1).timeout
	aplicar_efeito_hover_todos_botoes()

func carregar_ranking():
	print("🔄 Carregando ranking do servidor...")
	
	# Resetar UI
	label_carregando.visible = true
	label_erro.visible = false
	panel_sua_posicao.visible = false
	
	# Limpar lista de ranking anterior
	for child in lista_ranking.get_children():
		if child != cabecalho_ranking:  # Não remover o cabeçalho
			child.queue_free()
	
	var headers = ["Authorization: Bearer " + SessionManager.auth_token]
	print("📤 Fazendo requisição para /global-ranking")
	
	var error = http.request("http://127.0.0.1:5000/global-ranking", headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		print("❌ Erro na requisição HTTP:", error)
		mostrar_erro("Erro ao carregar ranking")

func _on_ranking_carregado(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("📥 Resposta do servidor recebida!")
	print("   Result:", result)
	print("   Response Code:", response_code)
	
	label_carregando.visible = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("❌ Erro de conexão:", result)
		mostrar_erro("Erro de conexão")
		return
	
	var response = body.get_string_from_utf8()
	print("   Response Body:", response)
	
	var json = JSON.new()
	var parse_error = json.parse(response)
	
	if parse_error != OK:
		print("❌ Erro ao parsear JSON:", parse_error)
		mostrar_erro("Erro ao processar ranking")
		return
		
	var data = json.get_data()
	print("✅ JSON parseado com sucesso!")
	
	if response_code == 200:
		if data != null and "top_ranking" in data:
			print("🎯 Dados do ranking válidos encontrados")
			print("   top_ranking size:", data["top_ranking"].size())
			if "user_ranking" in data:
				print("   user_ranking disponível")
			exibir_ranking(data)
		else:
			print("❌ Formato de ranking inválido")
			mostrar_erro("Formato de ranking inválido")
	else:
		print("❌ Erro HTTP:", response_code)
		mostrar_erro("Erro ao carregar ranking: " + str(response_code))

func exibir_ranking(data: Dictionary):
	var top_ranking = data["top_ranking"]
	var user_ranking = data.get("user_ranking", {})
	
	print("🎨 Exibindo ranking com ", top_ranking.size(), " jogadores")
	
	# FILTRAR: Mostrar apenas jogadores com pontuação > 0
	var ranking_filtrado = []
	for jogador in top_ranking:
		if jogador.get("total_score", 0) > 0:
			ranking_filtrado.append(jogador)
	
	print("🎯 Ranking filtrado: ", ranking_filtrado.size(), " jogadores com pontuação > 0")
	
	# LIMITAR: Mostrar apenas top 5
	if ranking_filtrado.size() > 5:
		ranking_filtrado = ranking_filtrado.slice(0, 5)
		print("📊 Limitado ao top 5 jogadores")
	
	# DEBUG: Verificar fotos recebidas
	print("📸 DEBUG - Fotos recebidas do servidor:")
	for i in range(ranking_filtrado.size()):
		var jogador = ranking_filtrado[i]
		var tem_foto = jogador.has("profile_image") and jogador["profile_image"] != null and jogador["profile_image"] != ""
		var foto_tamanho = jogador["profile_image"].length() if tem_foto else 0
		print("   Jogador ", jogador["username"], " - Tem foto: ", tem_foto, " - Tamanho: ", foto_tamanho)
	
	# Adicionar jogadores do ranking
	for i in range(ranking_filtrado.size()):
		var jogador = ranking_filtrado[i]
		print("   👤 Jogador ", i + 1, ":", jogador["username"], " - Pontos:", jogador["total_score"])
		var linha = criar_linha_ranking(jogador, i + 1)
		if linha:
			lista_ranking.add_child(linha)
			print("   ✅ Linha adicionada para ", jogador["username"])
		else:
			print("   ❌ Falha ao criar linha para ", jogador["username"])
	
	# Verificar se usuário está no top ranking
	var usuario_no_top = false
	if user_ranking:
		for jogador in ranking_filtrado:
			if jogador["username"] == SessionManager.user_name:
				usuario_no_top = true
				break
	
	# Exibir seção do usuário se não estiver no top E se tiver pontuação > 0
	if user_ranking and user_ranking.get("total_score", 0) > 0 and not usuario_no_top:
		exibir_secao_usuario(user_ranking)
	elif usuario_no_top:
		print("✅ Usuário está no Top ", ranking_filtrado.size())
	else:
		print("ℹ️  Usuário não tem pontuação no ranking")

func criar_linha_ranking(jogador: Dictionary, posicao: int) -> HBoxContainer:
	var linha = HBoxContainer.new()
	linha.add_theme_constant_override("separation", 20)
	linha.name = "LinhaRanking" + str(posicao)
	linha.custom_minimum_size = Vector2(0, 70)  # Aumentado para acomodar foto maior
	
	# Coluna Posição
	var coluna_pos = Label.new()
	coluna_pos.name = "LabelPosicao" + str(posicao)
	coluna_pos.text = str(posicao) + "°"
	coluna_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna_pos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna_pos.custom_minimum_size.x = 80
	
	# Emojis para top 3
	if posicao == 1:
		coluna_pos.text += " 🥇"
		coluna_pos.add_theme_color_override("font_color", Color.GOLD)
	elif posicao == 2:
		coluna_pos.text += " 🥈"
		coluna_pos.add_theme_color_override("font_color", Color.SILVER)
	elif posicao == 3:
		coluna_pos.text += " 🥉"
		coluna_pos.add_theme_color_override("font_color", Color.ORANGE)
	
	# Coluna Jogador (com foto e nome)
	var coluna_jogador = HBoxContainer.new()
	coluna_jogador.name = "ContainerJogador" + str(posicao)
	coluna_jogador.add_theme_constant_override("separation", 10)
	coluna_jogador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna_jogador.custom_minimum_size.x = 200
	
	var foto_jogador = TextureRect.new()
	foto_jogador.name = "FotoJogador" + str(posicao)
	# MESMO TAMANHO QUE O PAINEL: 60x60
	foto_jogador.custom_minimum_size = Vector2(60, 60)
	foto_jogador.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	foto_jogador.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	foto_jogador.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	foto_jogador.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Carregar foto do perfil (abordagem simplificada)
	var profile_image = jogador.get("profile_image", "")
	if profile_image and profile_image != "":
		print("📸 Carregando foto para: ", jogador["username"])
		var texture = criar_textura_da_string_base64(profile_image)
		if texture:
			foto_jogador.texture = texture
			print("✅ Foto carregada com sucesso para: ", jogador["username"])
		else:
			foto_jogador.texture = carregar_placeholder()
			print("❌ Falha ao carregar foto para: ", jogador["username"])
	else:
		foto_jogador.texture = carregar_placeholder()
		print("📸 Usando placeholder para: ", jogador["username"])
	
	var nome_jogador = Label.new()
	nome_jogador.name = "LabelNome" + str(posicao)
	nome_jogador.text = jogador["username"]
	nome_jogador.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nome_jogador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Destacar usuário atual
	if SessionManager and jogador["username"] == SessionManager.user_name:
		nome_jogador.add_theme_color_override("font_color", Color.CYAN)
		nome_jogador.text += " (você)"
	
	coluna_jogador.add_child(foto_jogador)
	coluna_jogador.add_child(nome_jogador)
	
	# Coluna Pontuação - sem casas decimais
	var coluna_pontos = Label.new()
	coluna_pontos.name = "LabelPontuacao" + str(posicao)
	var pontuacao_int = int(jogador["total_score"])
	coluna_pontos.text = str(pontuacao_int)
	coluna_pontos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna_pontos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna_pontos.custom_minimum_size.x = 120
	
	# Coluna Níveis - sem casas decimais
	var coluna_niveis = Label.new()
	coluna_niveis.name = "LabelNiveisComp" + str(posicao)
	var niveis_int = int(jogador["levels_completed"])
	coluna_niveis.text = str(niveis_int)
	coluna_niveis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna_niveis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna_niveis.custom_minimum_size.x = 100
	
	# Adicionar colunas à linha
	linha.add_child(coluna_pos)
	linha.add_child(coluna_jogador)
	linha.add_child(coluna_pontos)
	linha.add_child(coluna_niveis)
	
	return linha

func criar_textura_da_string_base64(base64_string: String) -> Texture2D:
	if base64_string == "" or base64_string == null:
		return null
	
	# Limpar a string base64 se tiver cabeçalho data URL
	var clean_base64 = base64_string
	if "base64," in base64_string:
		clean_base64 = base64_string.split("base64,")[1]
	
	var image = Image.new()
	var image_data = Marshalls.base64_to_raw(clean_base64)
	
	# Tentar carregar como PNG, JPG ou WebP
	var error = image.load_png_from_buffer(image_data)
	if error != OK:
		error = image.load_jpg_from_buffer(image_data)
	if error != OK:
		error = image.load_webp_from_buffer(image_data)
	
	if error == OK:
		var texture = ImageTexture.create_from_image(image)
		return texture
	
	return null

func carregar_placeholder() -> Texture2D:
	var placeholder = load("res://cat.png")
	if not placeholder:
		print("❌ Não foi possível carregar o placeholder")
	return placeholder

func exibir_secao_usuario(user_ranking: Dictionary):
	print("👤 Exibindo seção do usuário")
	
	# Atualizar dados do usuário
	var posicao_int = int(user_ranking.get("position", 0))
	label_sua_posicao.text = "Sua Posição: " + str(posicao_int) + "°"
	
	label_seu_nome.text = SessionManager.user_name
	
	var pontuacao_int = int(user_ranking.get("total_score", 0))
	label_sua_pontuacao.text = "Pontuação: " + str(pontuacao_int)
	
	var niveis_int = int(user_ranking.get("levels_completed", 0))
	label_seus_niveis.text = "Níveis Completados: " + str(niveis_int)
	
	# Carregar foto do usuário
	var profile_image = user_ranking.get("profile_image", "")
	if profile_image and profile_image != "":
		print("📸 Carregando foto do usuário do user_ranking")
		var texture = criar_textura_da_string_base64(profile_image)
		if texture:
			texture_sua_foto.texture = texture
			print("✅ Foto do usuário carregada com sucesso")
		else:
			texture_sua_foto.texture = carregar_placeholder()
			print("❌ Falha ao carregar foto do usuário")
	else:
		texture_sua_foto.texture = carregar_placeholder()
		print("📸 Usando placeholder para usuário")
	
	# Garantir que a foto tenha o tamanho correto (60x60)
	texture_sua_foto.custom_minimum_size = Vector2(60, 60)
	texture_sua_foto.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_sua_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	panel_sua_posicao.visible = true
	print("✅ Seção do usuário exibida")

func mostrar_erro(mensagem: String):
	print("❌ Erro:", mensagem)
	label_erro.text = mensagem
	label_erro.visible = true

func _on_voltar_pressed():
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
