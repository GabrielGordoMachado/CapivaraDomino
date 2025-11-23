-- View 1: Placar Geral de Jogadores (Vitórias em Jogos Completos e Partidas Individuais)
CREATE OR REPLACE VIEW ranking_por_usuario AS
SELECT
    j.id AS jogador_id,
    j.nome,
    COUNT(DISTINCT jogo.id) AS jogos_vencidos, -- Jogos inteiros (50pts) ganhos pela EQUIPE do jogador
    COUNT(DISTINCT partida.id) AS partidas_vencidas -- Mãos individuais que o jogador bateu/trancou
FROM jogador j
         LEFT JOIN jogo_jogador jj ON jj.jogador_id = j.id
         LEFT JOIN jogo ON jogo.id = jj.jogo_id AND jogo.vencedor_equipe = jj.equipe
         LEFT JOIN partida ON partida.vencedor_jogador_id = j.id
GROUP BY j.id, j.nome
ORDER BY jogos_vencidos DESC, partidas_vencidas DESC;

-- View 2: Histórico Detalhado
CREATE OR REPLACE VIEW historico_partidas AS
SELECT
    p.id as partida_id,
    p.numero as rodada_numero,
    j1.nome as vencedor_nome,
    CASE WHEN p.trancou THEN 'Sim' ELSE 'Não' END as trancou,
    p.data_fim
FROM partida p
         LEFT JOIN jogador j1 ON j1.id = p.vencedor_jogador_id
WHERE p.data_fim IS NOT NULL
ORDER BY p.data_fim DESC;