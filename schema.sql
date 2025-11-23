DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- 1. Tabela de jogadores
CREATE TABLE jogador (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL
);

-- 2. Tabela de peças do dominó (0-0 a 6-6)
CREATE TABLE peca (
    id SERIAL PRIMARY KEY,
    lado1 INT NOT NULL,
    lado2 INT NOT NULL,
    UNIQUE (lado1, lado2)
);

-- Inserir as 28 peças
INSERT INTO peca (lado1, lado2) VALUES
(0,0), (0,1), (0,2), (0,3), (0,4), (0,5), (0,6),
(1,1), (1,2), (1,3), (1,4), (1,5), (1,6),
(2,2), (2,3), (2,4), (2,5), (2,6),
(3,3), (3,4), (3,5), (3,6),
(4,4), (4,5), (4,6),
(5,5), (5,6),
(6,6);

-- 3. Tabela de jogos (o conjunto de rodadas até 50 pontos)
CREATE TABLE jogo (
    id SERIAL PRIMARY KEY,
    data_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_fim TIMESTAMP,
    pontos_alvo INT DEFAULT 50,
    vencedor_jogador_id INT,
    vencedor_equipe SMALLINT, -- 1 ou 2
    status VARCHAR(20) DEFAULT 'em_andamento', -- em_andamento, finalizado
    FOREIGN KEY (vencedor_jogador_id) REFERENCES jogador(id)
);

-- 4. Jogadores vinculados ao jogo
CREATE TABLE jogo_jogador (
    id SERIAL PRIMARY KEY,
    jogo_id INT NOT NULL REFERENCES jogo(id) ON DELETE CASCADE,
    jogador_id INT NOT NULL REFERENCES jogador(id),
    equipe SMALLINT DEFAULT 1,  -- Se for individual, cada um é sua própria "equipe" ou controla via ID
    pontos INT DEFAULT 0        -- Pontos acumulados no JOGO GERAL
);

-- 5. Tabela de cada rodada (partida)
CREATE TABLE partida (
    id SERIAL PRIMARY KEY,
    jogo_id INT NOT NULL REFERENCES jogo(id) ON DELETE CASCADE,
    numero INT NOT NULL,
    vencedor_jogador_id INT,
    vencedor_equipe SMALLINT,
    trancou BOOLEAN NOT NULL DEFAULT FALSE,
    data_fim TIMESTAMP,
    FOREIGN KEY (vencedor_jogador_id) REFERENCES jogador(id)
);

-- 6. Estado da Mesa (para saber as pontas atuais)
CREATE TABLE mesa (
    partida_id INT PRIMARY KEY REFERENCES partida(id) ON DELETE CASCADE,
    ponta1 INT, -- Uma extremidade
    ponta2 INT  -- A outra extremidade
);

-- 7. Peças na mão dos jogadores
CREATE TABLE mao_rodada (
    partida_id INT NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
    jogador_id INT NOT NULL REFERENCES jogador(id),
    peca_id INT NOT NULL REFERENCES peca(id),
    PRIMARY KEY (partida_id, jogador_id, peca_id)
);

-- 8. Monte (peças disponíveis para compra)
CREATE TABLE monte (
    partida_id INT NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
    peca_id INT NOT NULL REFERENCES peca(id),
    PRIMARY KEY (partida_id, peca_id)
);

-- 9. Histórico de Movimentos
CREATE TABLE movimento (
    id SERIAL PRIMARY KEY,
    partida_id INT NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
    turno INT NOT NULL,
    jogador_id INT NOT NULL REFERENCES jogador(id),
    peca_id INT,                   -- Pode ser NULL se apenas passou a vez
    lado VARCHAR(10),              -- 'esquerda', 'direita' ou NULL (compra/passa)
    acao VARCHAR(20) NOT NULL,     -- 'jogou', 'comprou', 'passou'
    data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);