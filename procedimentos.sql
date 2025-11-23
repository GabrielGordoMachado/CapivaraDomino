CREATE OR REPLACE PROCEDURE jogar_peca(
    p_jogador_id INT,
    p_partida_id INT,
    p_peca_id INT,
    p_direcao VARCHAR -- 'esquerda', 'direita' ou 'inicio'
)
LANGUAGE plpgsql AS $$
DECLARE
    v_ponta1 INT;
    v_ponta2 INT;
    v_peca_l1 INT;
    v_peca_l2 INT;
    v_nova_ponta INT;
    v_turno INT;
    v_equipe INT;
BEGIN
    -- 1. Verificar se a partida ainda está rolando
    IF EXISTS (SELECT 1 FROM partida WHERE id = p_partida_id AND data_fim IS NOT NULL) THEN
        RAISE EXCEPTION 'Partida já finalizada.';
    END IF;

    -- 2. Verificar se peça está na mão
    IF NOT EXISTS (SELECT 1 FROM mao_rodada WHERE partida_id = p_partida_id AND jogador_id = p_jogador_id AND peca_id = p_peca_id) THEN
        RAISE EXCEPTION 'Peça não pertence ao jogador ou não está na mão.';
    END IF;

    -- Pegar valores da peça
    SELECT lado1, lado2 INTO v_peca_l1, v_peca_l2 FROM peca WHERE id = p_peca_id;

    -- Pegar estado da mesa
    SELECT ponta1, ponta2 INTO v_ponta1, v_ponta2 FROM mesa WHERE partida_id = p_partida_id;

    -- 3. Lógica de Encaixe
    IF v_ponta1 IS NULL THEN
        -- MESA VAZIA (Primeira jogada)
        UPDATE mesa SET ponta1 = v_peca_l1, ponta2 = v_peca_l2 WHERE partida_id = p_partida_id;
    ELSE
        IF p_direcao = 'esquerda' THEN
            IF v_peca_l1 = v_ponta1 THEN v_nova_ponta := v_peca_l2;
            ELSIF v_peca_l2 = v_ponta1 THEN v_nova_ponta := v_peca_l1;
            ELSE RAISE EXCEPTION 'Peça não encaixa na ponta esquerda (Valor: %)', v_ponta1;
            END IF;
            UPDATE mesa SET ponta1 = v_nova_ponta WHERE partida_id = p_partida_id;

        ELSIF p_direcao = 'direita' THEN
            IF v_peca_l1 = v_ponta2 THEN v_nova_ponta := v_peca_l2;
            ELSIF v_peca_l2 = v_ponta2 THEN v_nova_ponta := v_peca_l1;
            ELSE RAISE EXCEPTION 'Peça não encaixa na ponta direita (Valor: %)', v_ponta2;
            END IF;
            UPDATE mesa SET ponta2 = v_nova_ponta WHERE partida_id = p_partida_id;
        ELSE
            RAISE EXCEPTION 'Direção inválida. Use esquerda ou direita.';
        END IF;
    END IF;

    -- 4. Registrar Movimento e Remover da Mão
    DELETE FROM mao_rodada WHERE partida_id = p_partida_id AND jogador_id = p_jogador_id AND peca_id = p_peca_id;

    SELECT COALESCE(MAX(turno), 0) + 1 INTO v_turno FROM movimento WHERE partida_id = p_partida_id;

    INSERT INTO movimento (partida_id, turno, jogador_id, peca_id, lado, acao)
    VALUES (p_partida_id, v_turno, p_jogador_id, p_peca_id, p_direcao, 'jogou');

    -- 5. Verificar Vitória (Bateu?)
    IF NOT EXISTS (SELECT 1 FROM mao_rodada WHERE partida_id = p_partida_id AND jogador_id = p_jogador_id) THEN
        -- Bateu!
        SELECT equipe INTO v_equipe FROM jogo_jogador
        WHERE jogador_id = p_jogador_id AND jogo_id = (SELECT jogo_id FROM partida WHERE id = p_partida_id);

        UPDATE partida
        SET data_fim = CURRENT_TIMESTAMP,
            vencedor_jogador_id = p_jogador_id,
            vencedor_equipe = v_equipe
        WHERE id = p_partida_id;
    END IF;

END;
$$;


CREATE OR REPLACE PROCEDURE comprar_do_monte(
    p_jogador_id INT,
    p_partida_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_peca_id INT;
    v_turno INT;
BEGIN
    -- Pega uma peça aleatória do monte
    SELECT peca_id INTO v_peca_id
    FROM monte
    WHERE partida_id = p_partida_id
    ORDER BY RANDOM() LIMIT 1;

    IF v_peca_id IS NULL THEN
        RAISE NOTICE 'Monte vazio! Jogador deve passar a vez se não tiver jogada.';
        RETURN;
    END IF;

    -- Remove do monte e põe na mão
    DELETE FROM monte WHERE partida_id = p_partida_id AND peca_id = v_peca_id;

    INSERT INTO mao_rodada (partida_id, jogador_id, peca_id)
    VALUES (p_partida_id, p_jogador_id, v_peca_id);

    -- Registra movimento
    SELECT COALESCE(MAX(turno), 0) + 1 INTO v_turno FROM movimento WHERE partida_id = p_partida_id;

    INSERT INTO movimento (partida_id, turno, jogador_id, peca_id, lado, acao)
    VALUES (p_partida_id, v_turno, p_jogador_id, v_peca_id, NULL, 'comprou');
END;
$$;