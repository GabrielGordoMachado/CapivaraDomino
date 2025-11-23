-- Ranking por usuário
CREATE OR REPLACE VIEW ranking_por_usuario AS
SELECT j.id AS jogador_id, j.nome,
       COALESCE(g.games_won, 0) AS jogos_vencidos,
       COALESCE(p.matches_won, 0) AS partidas_vencidas
FROM jogador j
LEFT JOIN (
    SELECT vencedor_jogador_id AS jogador_id, COUNT(*) AS games_won
    FROM jogo
    WHERE vencedor_jogador_id IS NOT NULL
    GROUP BY vencedor_jogador_id
) g ON g.jogador_id = j.id
LEFT JOIN (
    SELECT vencedor_jogador_id AS jogador_id, COUNT(*) AS matches_won
    FROM partida
    WHERE vencedor_jogador_id IS NOT NULL
    GROUP BY vencedor_jogador_id
) p ON p.jogador_id = j.id;

-- Listagem de Partidas e Vencedores
CREATE OR REPLACE VIEW partidas_com_vencedores AS
SELECT pr.id AS partida_id, pr.jogo_id,
       CASE
         WHEN pr.vencedor_equipe IS NOT NULL THEN
            CONCAT('Equipe ', pr.vencedor_equipe)
         ELSE
           (SELECT nome FROM jogador WHERE id = pr.vencedor_jogador_id)
       END AS vencedor_desc
FROM partida pr
WHERE pr.data_fim IS NOT NULL;