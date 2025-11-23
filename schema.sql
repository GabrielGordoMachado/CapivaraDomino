DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

CREATE TABLE jogador (
                         id SERIAL PRIMARY KEY,
                         nome VARCHAR(100) NOT NULL
);

CREATE TABLE peca (
                      id SERIAL PRIMARY KEY,
                      lado1 INT NOT NULL,
                      lado2 INT NOT NULL,
                      UNIQUE (lado1, lado2)
);

INSERT INTO peca (lado1, lado2) VALUES
                                    (0,0), (0,1), (0,2), (0,3), (0,4), (0,5), (0,6),
                                    (1,1), (1,2), (1,3), (1,4), (1,5), (1,6),
                                    (2,2), (2,3), (2,4), (2,5), (2,6),
                                    (3,3), (3,4), (3,5), (3,6),
                                    (4,4), (4,5), (4,6),
                                    (5,5), (5,6),
                                    (6,6);

CREATE TABLE jogo (
                      id SERIAL PRIMARY KEY,
                      data_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                      data_fim TIMESTAMP,
                      pontos_alvo INT DEFAULT 50,
                      vencedor_jogador_id INT REFERENCES jogador(id),
                      vencedor_equipe SMALLINT,
                      status VARCHAR(20) DEFAULT 'em_andamento'
);

CREATE TABLE jogo_jogador (
                              id SERIAL PRIMARY KEY,
                              jogo_id INT NOT NULL REFERENCES jogo(id) ON DELETE CASCADE,
                              jogador_id INT NOT NULL REFERENCES jogador(id),
                              equipe SMALLINT DEFAULT 1,
                              pontos FLOAT DEFAULT 0 -- Importante: FLOAT para aceitar divisão (ex: 2.5)
);

CREATE TABLE partida (
                         id SERIAL PRIMARY KEY,
                         jogo_id INT NOT NULL REFERENCES jogo(id) ON DELETE CASCADE,
                         numero INT NOT NULL,
                         vencedor_jogador_id INT REFERENCES jogador(id),
                         vencedor_equipe SMALLINT,
                         trancou BOOLEAN NOT NULL DEFAULT FALSE,
                         pontos_ganhos INT DEFAULT 0,
                         data_fim TIMESTAMP
);

CREATE TABLE mesa (
                      partida_id INT PRIMARY KEY REFERENCES partida(id) ON DELETE CASCADE,
                      ponta1 INT,
                      ponta2 INT
);

CREATE TABLE mao_rodada (
                            partida_id INT NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
                            jogador_id INT NOT NULL REFERENCES jogador(id),
                            peca_id INT NOT NULL REFERENCES peca(id),
                            PRIMARY KEY (partida_id, jogador_id, peca_id)
);

CREATE TABLE monte (
                       partida_id INT NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
                       peca_id INT NOT NULL REFERENCES peca(id),
                       PRIMARY KEY (partida_id, peca_id)
);

CREATE TABLE movimento (
                           id SERIAL PRIMARY KEY,
                           partida_id INT NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
                           turno INT NOT NULL,
                           jogador_id INT NOT NULL REFERENCES jogador(id),
                           peca_id INT REFERENCES peca(id),
                           lado VARCHAR(10),
                           acao VARCHAR(20) NOT NULL,
                           data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);