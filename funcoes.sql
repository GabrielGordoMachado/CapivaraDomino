CREATE OR REPLACE FUNCTION verificar_se_trancou(p_partida_id INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_ponta1 INT;
    v_ponta2 INT;
    v_tem_jogada INT;
BEGIN
    SELECT ponta1, ponta2 INTO v_ponta1, v_ponta2 FROM mesa WHERE partida_id = p_partida_id;

    -- Conta quantas peças nas mãos dos jogadores servem nas pontas atuais
    SELECT COUNT(*) INTO v_tem_jogada
    FROM mao_rodada m
    JOIN peca p ON p.id = m.peca_id
    WHERE m.partida_id = p_partida_id
      AND (p.lado1 = v_ponta1 OR p.lado2 = v_ponta1 OR p.lado1 = v_ponta2 OR p.lado2 = v_ponta2);

    -- Verifica se o monte está vazio
    IF EXISTS (SELECT 1 FROM monte WHERE partida_id = p_partida_id) THEN
        -- Se tem monte, tecnicamente não está trancado, podem comprar
        RETURN FALSE;
    END IF;

    IF v_tem_jogada = 0 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION possiveis_pecas(p_partida_id INT, p_jogador_id INT)
RETURNS TABLE(peca_id INT, lado1 INT, lado2 INT) AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.lado1, p.lado2
    FROM peca p
    JOIN mao_rodada m ON p.id = m.peca_id
    JOIN mesa ms ON ms.partida_id = p_partida_id
    WHERE m.partida_id = p_partida_id
      AND m.jogador_id = p_jogador_id
      -- Se a mesa estiver vazia (início), qualquer peça serve?
      -- Não, no início apenas o 6-6 ou a maior dobra começa, mas assumindo jogo em andamento:
      AND (
          ms.ponta1 IS NULL -- Caso mesa vazia (lógica tratada no procedure)
          OR p.lado1 = ms.ponta1 OR p.lado2 = ms.ponta1
          OR p.lado1 = ms.ponta2 OR p.lado2 = ms.ponta2
      );
END;
$$ LANGUAGE plpgsql;