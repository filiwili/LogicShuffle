-- ========================================================
-- SCHEMA.SQL — Estrutura do Banco de Dados do Sistema de Jogos
-- ========================================================

-- Tabela principal de usuários
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(36) PRIMARY KEY,
  username VARCHAR(80) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  profile_image TEXT,  -- imagem de perfil em base64 (padrão: gatinho)
  score INTEGER DEFAULT 0,
  created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
  reset_token_hash VARCHAR(255),
  reset_token_expires_at TIMESTAMP WITHOUT TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ========================================================
-- Tabela de configurações do usuário
CREATE TABLE IF NOT EXISTS user_settings (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  master_volume NUMERIC,
  fx_volume NUMERIC,
  fullscreen BOOLEAN
);

-- ========================================================
-- Tabela de jogos
CREATE TABLE IF NOT EXISTS games (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(80) NOT NULL,
  description TEXT
);

-- ========================================================
-- Tabela de níveis dos jogos
CREATE TABLE IF NOT EXISTS game_levels (
  id VARCHAR(36) PRIMARY KEY,
  game_id VARCHAR(36) NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  name VARCHAR(80),
  order_number INTEGER,
  difficulty VARCHAR(50)
);

-- ========================================================
-- Tabela de ranks
CREATE TABLE IF NOT EXISTS ranks (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(80) NOT NULL,
  description TEXT
);

-- ========================================================
-- Tabela intermediária: relação usuário ↔ jogo
CREATE TABLE IF NOT EXISTS user_games (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  game_id VARCHAR(36) NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  rank_id VARCHAR(36) REFERENCES ranks(id),
  progress INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_user_games_user ON user_games(user_id);
CREATE INDEX IF NOT EXISTS idx_user_games_game ON user_games(game_id);

-- ========================================================
-- Tabela intermediária: relação usuário ↔ jogo ↔ nível
CREATE TABLE IF NOT EXISTS user_game_levels (
  id VARCHAR(36) PRIMARY KEY,
  user_game_id VARCHAR(36) NOT NULL REFERENCES user_games(id) ON DELETE CASCADE,
  level_id VARCHAR(36) NOT NULL REFERENCES game_levels(id) ON DELETE CASCADE,
  status VARCHAR(50),
  score INTEGER
);

CREATE INDEX IF NOT EXISTS idx_user_game_levels_usergame ON user_game_levels(user_game_id);
CREATE INDEX IF NOT EXISTS idx_user_game_levels_level ON user_game_levels(level_id);

-- ========================================================
-- Fim do schema
-- ========================================================
