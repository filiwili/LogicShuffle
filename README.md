# Logic Shuffle - Jogo Educativo para Ensino de Estruturas de Dados

<div align="center">

![Godot](https://img.shields.io/badge/Godot-478CBF?style=for-the-badge&logo=GodotEngine&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-000000?style=for-the-badge&logo=flask&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)

**Uma ferramenta educacional inovadora para o ensino de estruturas de dados através de jogos interativos**

</div>

## Sobre o Projeto

O **Logic Shuffle** é um aplicativo educacional desenvolvido como Trabalho de Graduação para abordar as dificuldades recorrentes no ensino de **Estruturas de Dados** entre estudantes de Computação. 

### Problema Identificado
Através de pesquisa com formulários aplicados a estudantes, identificamos que o ensino de Estruturas de Dados apresenta elevado grau de dificuldade devido à necessidade de:
- **Alta abstração lógica**
- **Visualização de conceitos complexos**
- **Compreensão de algoritmos abstratos**

### Solução Proposta
Desenvolvemos uma série de **jogos educativos** que transformam conceitos complexos em experiências interativas e visuais, facilitando o aprendizado de:
- **Árvores binárias** e algoritmos de busca
- **Pilhas, filas e deques**
- **Estruturas de dados lineares**

##  Criadores

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/Karovii">
        <img src="https://avatars.githubusercontent.com/u/159808804" width="100px;" alt="Cauã Viana"/><br>
        <sub><b>Cauã Viana</b></sub><br>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/filiwili">
        <img src="https://avatars.githubusercontent.com/u/161388271" width="100px;" alt="Filipe de Moura"/><br>
        <sub><b>Filipe de Moura</b></sub><br>
      </a>
    </td>
  </tr>
</table>

**Orientador:** Denilce de Almeida Oliveira Veloso

**Instituição:** Fatec Sorocaba - José Crespo Gonzales

**Curso:** Tecnólogo em Análise e Desenvolvimento de Sistemas  
**Ano:** 2025

## Sobre o Jogo

### Origem do Projeto
O Logic Shuffle teve início como projeto para a disciplina de **Engenharia de Software III**, evoluindo para se tornar um **Trabalho de Graduação** completo, demonstrando o potencial de jogos educativos no ensino de computação.

### Metodologia de Desenvolvimento
1. **Elicitação de Requisitos** através de formulários com estudantes
2. **Análise Comparativa** de game engines existentes
3. **Desenvolvimento Iterativo** com feedback contínuo
4. **Documentação Completa** utilizando UML

## Arquitetura Técnica

### Frontend
- **Engine:** Godot Engine 4.2+
- **Linguagem:** GDScript
- **Foco:** Performance em projetos 2D e custo-benefício

### Backend
- **Framework:** Python Flask
- **Arquitetura:** Camadas com API REST
- **Comunicação:** HTTP/JSON

### Banco de Dados
- **SGBD:** PostgreSQL
- **Características:** Persistência de progresso e ranking


## Versões Disponíveis

### **Versão Online** - Ambiente de Desenvolvimento
Projetada para desenvolvimento e testes, com integração completa entre banco de dados, servidor e interface gráfica.

### **Versão Offline** - Uso Recomendado
Versão standalone independente, ideal para demonstrações e uso em ambientes acadêmicos.

---

## Começando Rápido (Versão Offline)

### Processo de Utilização
1. **Acesse** a pasta `LogicShuffleOffline`
2. **Execute** o arquivo `LogicShuffle.exe`
3. **Aguarde** o carregamento automático do jogo

### Vantagens da Versão Offline
- Funcionamento completo em modo local
- Ausência de necessidade de instalação
- Ideal para apresentações rápidas
- Uso em locais sem conexão de rede
- Compatível com Windows 7 ou superior

---

## Configuração Completa (Versão Online)

### Pré-requisitos
- **Python** 3.8 ou superior
- **PostgreSQL** 12 ou superior  
- **Godot Engine** 4.0 ou superior (apenas para modificações no front-end)

### Configuração do Back-end

1. **Acesse a pasta do programa em qualquer prompt de comando:**

   cd SuaPastaLogicShuffleOnline

2. **Instale as dependências Python**

    pip install -r requirements.txt

3. **Configure as variáveis de ambiente criando/editando o arquivo .env / config.py**

    DATABASE_URL=seubancodedados

    SECRET_KEY=suachavesecreta

    JWT_SECRET_KEY=suaoutrachavesecreta
4. **Configure o banco de dados PostgreSQL:**

    CREATE DATABASE logicshuffle;
    \c logicshuffle;
5. **Execute o script de criação do banco de dados:**

    psql -d logicshuffle -f schema.sql
6. **Execute o servidor Flask, na pasta do programa:**

    python app.py

## E então, basta se divertir enquanto aprende, clicando em LogicShuffleOnline/LogicShuffle.exe!
