CREATE OR REPLACE FUNCTION verificar_se_trancou(p_partida_id INT)
    RETURNS BOOLEAN AS $$
DECLARE
    v_ponta1 INT;
    v_ponta2 INT;
    v_jogadas_possiveis INT;
BEGIN
    SELECT ponta1, ponta2 INTO v_ponta1, v_ponta2 FROM mesa WHERE partida_id = p_partida_id;

    IF v_ponta1 IS NULL THEN RETURN FALSE; END IF;

    IF EXISTS (SELECT 1 FROM monte WHERE partida_id = p_partida_id) THEN
        RETURN FALSE;
    END IF;

    SELECT COUNT(*) INTO v_jogadas_possiveis
    FROM mao_rodada m
             JOIN peca p ON p.id = m.peca_id
    WHERE m.partida_id = p_partida_id
      AND (p.lado1 = v_ponta1 OR p.lado2 = v_ponta1 OR p.lado1 = v_ponta2 OR p.lado2 = v_ponta2);

    RETURN v_jogadas_possiveis = 0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calcular_vencedor_tranca(p_partida_id INT)
    RETURNS TABLE(vencedor_jogador_id INT, vencedor_equipe INT, pontos_adversario BIGINT) AS $$
DECLARE
    pts_eq1 BIGINT := 0;
    pts_eq2 BIGINT := 0;
    quem_trancou_id INT;
    equipe_trancou INT;
BEGIN
    SELECT COALESCE(SUM(p.lado1 + p.lado2), 0) INTO pts_eq1
    FROM mao_rodada m
             JOIN peca p ON p.id = m.peca_id
             JOIN jogo_jogador jj ON jj.jogador_id = m.jogador_id
             JOIN partida part ON part.id = m.partida_id AND part.jogo_id = jj.jogo_id
    WHERE m.partida_id = p_partida_id AND jj.equipe = 1;

    SELECT COALESCE(SUM(p.lado1 + p.lado2), 0) INTO pts_eq2
    FROM mao_rodada m
             JOIN peca p ON p.id = m.peca_id
             JOIN jogo_jogador jj ON jj.jogador_id = m.jogador_id
             JOIN partida part ON part.id = m.partida_id AND part.jogo_id = jj.jogo_id
    WHERE m.partida_id = p_partida_id AND jj.equipe = 2;

    SELECT jogador_id INTO quem_trancou_id
    FROM movimento
    WHERE partida_id = p_partida_id AND acao = 'jogou'
    ORDER BY turno DESC LIMIT 1;

    SELECT jj.equipe INTO equipe_trancou
    FROM jogo_jogador jj
             JOIN partida part ON part.id = p_partida_id AND part.jogo_id = jj.jogo_id
    WHERE jj.jogador_id = quem_trancou_id;


    IF pts_eq1 < pts_eq2 THEN
        RETURN QUERY SELECT NULL::INT, 1, pts_eq2;
    ELSIF pts_eq2 < pts_eq1 THEN
        RETURN QUERY SELECT NULL::INT, 2, pts_eq1;
    ELSE
        IF equipe_trancou = 1 THEN

            RETURN QUERY SELECT NULL::INT, 2, pts_eq1;
        ELSE

            RETURN QUERY SELECT NULL::INT, 1, pts_eq2;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;