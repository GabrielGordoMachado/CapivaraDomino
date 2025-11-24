-- Procedimento de Jogar Peça
CREATE OR REPLACE PROCEDURE jogar_peca(
    p_jogador_id INT,
    p_partida_id INT,
    p_peca_id INT,
    p_direcao VARCHAR -- 'esquerda' ou 'direita'
)
    LANGUAGE plpgsql AS $$
DECLARE
    v_ponta1 INT; v_ponta2 INT;
    v_l1 INT; v_l2 INT;
    v_nova_ponta INT;
    v_jogo_id INT;
    v_equipe INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM mao_rodada WHERE partida_id = p_partida_id AND jogador_id = p_jogador_id AND peca_id = p_peca_id) THEN
        RAISE EXCEPTION 'Peça não pertence ao jogador.';
    END IF;

    SELECT lado1, lado2 INTO v_l1, v_l2 FROM peca WHERE id = p_peca_id;
    SELECT ponta1, ponta2 INTO v_ponta1, v_ponta2 FROM mesa WHERE partida_id = p_partida_id;


    IF v_ponta1 IS NULL THEN

        UPDATE mesa SET ponta1 = v_l1, ponta2 = v_l2 WHERE partida_id = p_partida_id;
    ELSE
        IF p_direcao = 'esquerda' THEN
            IF v_l1 = v_ponta1 THEN v_nova_ponta := v_l2;
            ELSIF v_l2 = v_ponta1 THEN v_nova_ponta := v_l1;
            ELSE RAISE EXCEPTION 'Jogada inválida na esquerda: %-% não encaixa em %', v_l1, v_l2, v_ponta1; END IF;
            UPDATE mesa SET ponta1 = v_nova_ponta WHERE partida_id = p_partida_id;
        ELSIF p_direcao = 'direita' THEN
            IF v_l1 = v_ponta2 THEN v_nova_ponta := v_l2;
            ELSIF v_l2 = v_ponta2 THEN v_nova_ponta := v_l1;
            ELSE RAISE EXCEPTION 'Jogada inválida na direita: %-% não encaixa em %', v_l1, v_l2, v_ponta2; END IF;
            UPDATE mesa SET ponta2 = v_nova_ponta WHERE partida_id = p_partida_id;
        END IF;
    END IF;


    DELETE FROM mao_rodada WHERE partida_id = p_partida_id AND jogador_id = p_jogador_id AND peca_id = p_peca_id;

    INSERT INTO movimento (partida_id, turno, jogador_id, peca_id, lado, acao)
    VALUES (p_partida_id, (SELECT COALESCE(MAX(turno),0)+1 FROM movimento WHERE partida_id=p_partida_id), p_jogador_id, p_peca_id, p_direcao, 'jogou');

    IF NOT EXISTS (SELECT 1 FROM mao_rodada WHERE partida_id = p_partida_id AND jogador_id = p_jogador_id) THEN

        SELECT jogo_id INTO v_jogo_id FROM partida WHERE id = p_partida_id;
        SELECT equipe INTO v_equipe FROM jogo_jogador WHERE jogador_id = p_jogador_id AND jogo_id = v_jogo_id;

        UPDATE partida
        SET data_fim = CURRENT_TIMESTAMP,
            vencedor_jogador_id = p_jogador_id,
            vencedor_equipe = v_equipe,
            trancou = FALSE
        WHERE id = p_partida_id;
    END IF;
END;
$$;

-- Procedimento de Compra do Monte
CREATE OR REPLACE PROCEDURE comprar_do_monte(p_jogador_id INT, p_partida_id INT)
    LANGUAGE plpgsql AS $$
DECLARE
    v_peca_id INT;
BEGIN
    SELECT peca_id INTO v_peca_id FROM monte WHERE partida_id = p_partida_id ORDER BY RANDOM() LIMIT 1;

    IF v_peca_id IS NULL THEN RAISE NOTICE 'Monte vazio.'; RETURN; END IF;

    DELETE FROM monte WHERE partida_id = p_partida_id AND peca_id = v_peca_id;
    INSERT INTO mao_rodada (partida_id, jogador_id, peca_id) VALUES (p_partida_id, p_jogador_id, v_peca_id);

    INSERT INTO movimento (partida_id, turno, jogador_id, peca_id, acao)
    VALUES (p_partida_id, (SELECT COALESCE(MAX(turno),0)+1 FROM movimento WHERE partida_id=p_partida_id), p_jogador_id, v_peca_id, 'comprou');
END;
$$;