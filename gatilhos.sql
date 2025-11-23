CREATE OR REPLACE FUNCTION calcular_pontos_partida()
RETURNS TRIGGER AS $$
DECLARE
  pontos_perdedores INT := 0;
  rec_jogador RECORD;
  v_jogo_id INT;
  v_equipe_vencedora INT;
BEGIN
  -- Verifica se a partida acabou agora
  IF NEW.data_fim IS NOT NULL AND OLD.data_fim IS NULL THEN

    v_jogo_id := NEW.jogo_id;
    v_equipe_vencedora := NEW.vencedor_equipe;

    -- Soma os pontos das peças restantes nas mãos dos perdedores
    -- (Se for jogo de 4 pessoas, soma as mãos da equipe adversária)
    -- (Se for jogo de 2/3 pessoas, soma as mãos de todos os adversários)

    SELECT SUM(p.lado1 + p.lado2)
    INTO pontos_perdedores
    FROM mao_rodada m
    JOIN peca p ON p.id = m.peca_id
    JOIN jogo_jogador jj ON jj.jogador_id = m.jogador_id AND jj.jogo_id = v_jogo_id
    WHERE m.partida_id = NEW.id
      AND (jj.equipe <> v_equipe_vencedora OR v_equipe_vencedora IS NULL);
      -- Nota: Se vencedor_equipe for NULL (jogo individual), soma de todos os outros.

    -- Atualiza a pontuação no jogo global para a equipe/jogador vencedor
    UPDATE jogo_jogador
    SET pontos = pontos + COALESCE(pontos_perdedores, 0)
    WHERE jogo_id = v_jogo_id
      AND (equipe = v_equipe_vencedora OR jogador_id = NEW.vencedor_jogador_id);

    -- Verifica se alguém atingiu 50 pontos para fechar o JOGO
    IF EXISTS (SELECT 1 FROM jogo_jogador WHERE jogo_id = v_jogo_id AND pontos >= 50) THEN
        UPDATE jogo
        SET data_fim = CURRENT_TIMESTAMP,
            status = 'finalizado',
            vencedor_equipe = NEW.vencedor_equipe,
            vencedor_jogador_id = NEW.vencedor_jogador_id
        WHERE id = v_jogo_id;
    END IF;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calcular_pontos
AFTER UPDATE OF data_fim ON partida
FOR EACH ROW
EXECUTE FUNCTION calcular_pontos_partida();