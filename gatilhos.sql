CREATE OR REPLACE FUNCTION calcular_pontos_partida()
    RETURNS TRIGGER AS $$
DECLARE
    pontos_mesa INT := 0;
    v_jogo_id INT;
    v_equipe_vencedora INT;
    v_num_membros_equipe INT;
    v_pontos_por_jogador FLOAT;
BEGIN
    IF NEW.data_fim IS NOT NULL AND OLD.data_fim IS NULL THEN

        v_jogo_id := NEW.jogo_id;
        v_equipe_vencedora := NEW.vencedor_equipe;

        -- 1. Calcular a soma das mãos dos ADVERSÁRIOS
        SELECT COALESCE(SUM(p.lado1 + p.lado2), 0)
        INTO pontos_mesa
        FROM mao_rodada m
                 JOIN peca p ON p.id = m.peca_id
                 JOIN jogo_jogador jj ON jj.jogador_id = m.jogador_id AND jj.jogo_id = v_jogo_id
        WHERE m.partida_id = NEW.id
          AND jj.equipe <> v_equipe_vencedora;

        -- 2. Salvar quantos pontos valeu essa partida
        UPDATE partida SET pontos_ganhos = pontos_mesa WHERE id = NEW.id;

        -- 3. Contar quantos membros tem na equipe vencedora (geralmente 2, mas pode ser 1)
        SELECT COUNT(*) INTO v_num_membros_equipe
        FROM jogo_jogador
        WHERE jogo_id = v_jogo_id AND equipe = v_equipe_vencedora;

        -- 4. Dividir os pontos
        IF v_num_membros_equipe > 0 THEN
            v_pontos_por_jogador := pontos_mesa::FLOAT / v_num_membros_equipe::FLOAT;

            -- Atualiza Pontuação INDIVIDUAL
            UPDATE jogo_jogador
            SET pontos = pontos + v_pontos_por_jogador
            WHERE jogo_id = v_jogo_id
              AND equipe = v_equipe_vencedora;
        END IF;

        -- 5. Verifica Fim do Jogo (Soma da equipe >= 50)
        IF EXISTS (
            SELECT 1
            FROM jogo_jogador
            WHERE jogo_id = v_jogo_id
            GROUP BY equipe
            HAVING SUM(pontos) >= 50
        ) THEN
            UPDATE jogo
            SET data_fim = CURRENT_TIMESTAMP,
                status = 'finalizado',
                vencedor_equipe = v_equipe_vencedora,
                vencedor_jogador_id = NEW.vencedor_jogador_id
            WHERE id = v_jogo_id;
        END IF;

    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_fim_partida ON partida;
CREATE TRIGGER trg_fim_partida
    AFTER UPDATE OF data_fim ON partida
    FOR EACH ROW
EXECUTE FUNCTION calcular_pontos_partida();