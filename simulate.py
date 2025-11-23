import psycopg2
import random
import sys
from collections import deque

# --- CONFIGURAÇÃO DO BANCO ---
DB_CONFIG = {
    "dbname": "capivaragame",
    "user": "postgres",
    "password": "marinezpadilhaA1",
    "host": "localhost",
    "port": "5432"
}

def get_conn():
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = True
    return conn

def load_sql_file(filename, cursor):
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            cursor.execute(f.read())
            print(f"✅ {filename} carregado.")
    except FileNotFoundError:
        print(f"⚠️ {filename} não encontrado (pulando).")
    except Exception as e:
        print(f"❌ Erro em {filename}: {e}")

def setup_database():
    conn = get_conn()
    cur = conn.cursor()
    print("--- Configurando Banco (PostgreSQL) ---")
    arquivos = ['schema.sql', 'funcoes.sql', 'procedimentos.sql', 'gatilhos.sql', 'visoes.sql']
    for arq in arquivos:
        load_sql_file(arq, cur)
    conn.close()
    print("---------------------------------------")

# --- VISUALIZAÇÃO ---

def mostrar_maos(partida_id, cur):
    sql = """
        SELECT j.nome, p.lado1, p.lado2 
        FROM mao_rodada m 
        JOIN jogador j ON j.id = m.jogador_id 
        JOIN peca p ON p.id = m.peca_id 
        WHERE m.partida_id = %s 
        ORDER BY j.nome, p.lado1
    """
    cur.execute(sql, (partida_id,))
    maos = {}
    for nome, l1, l2 in cur.fetchall():
        if nome not in maos: maos[nome] = []
        maos[nome].append(f"[{l1}-{l2}]")

    print("\n=== ✋ MÃOS DOS JOGADORES ===")
    for nome, pecas in maos.items():
        print(f"{nome}: {', '.join(pecas)}")
    print("=============================\n")

def mostrar_mesa_visual(partida_id, cur):
    sql = """
        SELECT m.lado, p.lado1, p.lado2 
        FROM movimento m 
        JOIN peca p ON p.id = m.peca_id 
        WHERE m.partida_id = %s AND m.acao = 'jogou' 
        ORDER BY m.turno ASC
    """
    cur.execute(sql, (partida_id,))
    movimentos = cur.fetchall()

    if not movimentos:
        print("\n=== 🎲 MESA: [ VAZIA ] ===\n")
        return

    cobra = deque()
    p_esq, p_dir = None, None

    for i, (lado, l1, l2) in enumerate(movimentos):
        if i == 0:
            cobra.append(f"[{l1}|{l2}]")
            p_esq, p_dir = l1, l2
        elif lado == 'esquerda':
            if l2 == p_esq:
                cobra.appendleft(f"[{l1}|{l2}]"); p_esq = l1
            else:
                cobra.appendleft(f"[{l2}|{l1}]"); p_esq = l2
        elif lado == 'direita':
            if l1 == p_dir:
                cobra.append(f"[{l1}|{l2}]"); p_dir = l2
            else:
                cobra.append(f"[{l2}|{l1}]"); p_dir = l1

    print(f"\n=== 🎲 MESA ===\n{''.join(cobra)}\n===============\n")

def mostrar_resumo_rodada(partida_id, cur):
    cur.execute("SELECT vencedor_equipe, pontos_ganhos FROM partida WHERE id=%s", (partida_id,))
    row = cur.fetchone()
    if row and row[0] is not None:
        equipe_venc = row[0]
        pontos = row[1]

        # Conta membros da equipe para mostrar a matemática
        cur.execute("""
            SELECT COUNT(*) FROM jogo_jogador jj 
            JOIN partida p ON p.jogo_id = jj.jogo_id 
            WHERE p.id = %s AND jj.equipe = %s
        """, (partida_id, equipe_venc))
        n_membros = cur.fetchone()[0]

        print(f"\n💰 RESULTADO DA RODADA: Equipe {equipe_venc} venceu +{pontos} pontos! 💰")
        if n_membros > 0:
            pts_div = pontos / n_membros
            print(f"   Matemática: {pontos} pontos ÷ {n_membros} jogador(es) = {pts_div} para cada.")

def mostrar_placar_individual_acumulado(cur):
    """Mostra o ranking individual acumulado de TODA a sessão."""
    sql = """
        SELECT j.nome, COALESCE(SUM(jj.pontos), 0) as total
        FROM jogador j
        LEFT JOIN jogo_jogador jj ON jj.jogador_id = j.id
        GROUP BY j.nome
        ORDER BY total DESC, j.nome ASC
    """
    cur.execute(sql)
    rows = cur.fetchall()

    print("\n=== 🏆 PLACAR GERAL ACUMULADO (SESSÃO) ===")
    if not rows:
        print("Nenhum ponto marcado ainda.")
    else:
        for i, (nome, total) in enumerate(rows, 1):
            # Formata float bonitinho
            total_fmt = int(total) if total % 1 == 0 else total
            print(f"{i}º {nome}: {total_fmt} pts")
    print("==========================================\n")

def mostrar_ranking_vitorias(cur):
    sql = """
        SELECT j.nome, COUNT(p.id) as vitorias
        FROM jogador j
        JOIN jogo_jogador jj ON jj.jogador_id = j.id
        JOIN partida p ON p.jogo_id = jj.jogo_id AND p.vencedor_equipe = jj.equipe
        WHERE p.data_fim IS NOT NULL
        GROUP BY j.nome
        ORDER BY vitorias DESC, j.nome ASC;
    """
    cur.execute(sql)
    rows = cur.fetchall()
    print("\n=== 🥇 PARTIDAS VENCIDAS (RODADAS) ===")
    if not rows: print("Nenhuma rodada finalizada ainda.")
    else:
        for i, (nome, vitorias) in enumerate(rows, 1):
            print(f"{i}º {nome}: {vitorias} vitórias")
    print("========================================\n")

def limpar_banco_dados(conn, cur):
    print("\n⚠️  ATENÇÃO ⚠️")
    escolha = input("Deseja DELETAR todo o histórico do banco de dados? (s/n): ").lower().strip()
    if escolha == 's':
        try:
            print("Limpando tabelas...")
            cur.execute("TRUNCATE TABLE movimento, mao_rodada, monte, mesa, partida, jogo_jogador, jogo, jogador CASCADE;")
            print("✅ Banco de dados limpo com sucesso!")
        except Exception as e:
            print(f"❌ Erro ao limpar banco: {e}")
    else:
        print("Dados mantidos.")

def mostrar_formacao_equipes(jogo_id, cur):
    cur.execute("""
        SELECT jj.equipe, ARRAY_AGG(j.nome)
        FROM jogo_jogador jj JOIN jogador j ON j.id = jj.jogador_id
        WHERE jj.jogo_id = %s GROUP BY jj.equipe ORDER BY jj.equipe
    """, (jogo_id,))
    rows = cur.fetchall()
    print("\n📢 FORMAÇÃO DAS EQUIPES DESTA RODADA:")
    for eq, membros in rows:
        print(f"   Equipe {eq}: {' & '.join(membros)}")
    print("")

# --- MOTOR DO JOGO ---

def run_game():
    setup_database()
    conn = get_conn()
    cur = conn.cursor()

    # --- 1. INICIALIZAÇÃO ---
    print("--- Inicializando Jogadores ---")
    lista_nomes_full = ['Ana', 'Bruno', 'Carlos', 'Daniela']
    ids_jogadores_map = {}

    for nome in lista_nomes_full:
        cur.execute("SELECT id FROM jogador WHERE nome = %s", (nome,))
        res = cur.fetchone()
        if res: ids_jogadores_map[nome] = res[0]
        else:
            cur.execute("INSERT INTO jogador (nome) VALUES (%s) RETURNING id", (nome,))
            ids_jogadores_map[nome] = cur.fetchone()[0]

    print(f"Jogadores Disponíveis: {', '.join(lista_nomes_full)}")

    current_jogo_id = None
    last_n_players = 0
    num_rodada_sessao = 0
    simulacao_ativa = True

    while simulacao_ativa:
        print("\n" + "="*40)
        print(f"PREPARAÇÃO PARA A RODADA {num_rodada_sessao + 1}")
        print("="*40)

        # --- ESCOLHA ---
        while True:
            try:
                inp = input("Quantos jogadores participarão DESTA rodada (2, 3 ou 4)? [s p/ sair]: ").strip().lower()
                if inp == 's': simulacao_ativa = False; break
                n = int(inp)
                if 2 <= n <= 4:
                    n_jogadores = n
                    break
                print("Escolha 2, 3 ou 4.")
            except ValueError: pass

        if not simulacao_ativa: break

        nomes_da_rodada = lista_nomes_full[:n_jogadores]
        ids_da_rodada = [ids_jogadores_map[n] for n in nomes_da_rodada]

        # --- SETUP DO PLACAR ---
        # Cria novo jogo se mudou o número de jogadores (pois muda a lógica de equipes)
        if current_jogo_id is None or n_jogadores != last_n_players:
            cur.execute("INSERT INTO jogo (pontos_alvo) VALUES (50) RETURNING id")
            current_jogo_id = cur.fetchone()[0]

            for i, pid in enumerate(ids_da_rodada):
                if n_jogadores == 4: equipe = 1 if i % 2 == 0 else 2
                else: equipe = i + 1 # INDIVIDUAL
                cur.execute("INSERT INTO jogo_jogador (jogo_id, jogador_id, equipe) VALUES (%s, %s, %s)", (current_jogo_id, pid, equipe))
            last_n_players = n_jogadores
        else:
            # Verifica se jogo acabou
            cur.execute("SELECT status FROM jogo WHERE id=%s", (current_jogo_id,))
            st = cur.fetchone()
            if st and st[0] == 'finalizado':
                print("O jogo anterior acabou. Iniciando novo ciclo de 50 pontos...")
                cur.execute("INSERT INTO jogo (pontos_alvo) VALUES (50) RETURNING id")
                current_jogo_id = cur.fetchone()[0]
                for i, pid in enumerate(ids_da_rodada):
                    if n_jogadores == 4: equipe = 1 if i % 2 == 0 else 2
                    else: equipe = i + 1
                    cur.execute("INSERT INTO jogo_jogador (jogo_id, jogador_id, equipe) VALUES (%s, %s, %s)", (current_jogo_id, pid, equipe))

        num_rodada_sessao += 1
        print(f"\n>>> 🚩 INICIANDO RODADA {num_rodada_sessao} <<<")
        mostrar_formacao_equipes(current_jogo_id, cur)

        cur.execute("INSERT INTO partida (jogo_id, numero) VALUES (%s, %s) RETURNING id", (current_jogo_id, num_rodada_sessao))
        partida_id = cur.fetchone()[0]
        cur.execute("INSERT INTO mesa (partida_id) VALUES (%s)", (partida_id,))

        # Distribuir
        cur.execute("SELECT id FROM peca ORDER BY RANDOM()")
        pecas = [r[0] for r in cur.fetchall()]
        idx = 0
        for pid in ids_da_rodada:
            mao = pecas[idx:idx+7]
            idx += 7
            for p_id in mao: cur.execute("INSERT INTO mao_rodada VALUES (%s, %s, %s)", (partida_id, pid, p_id))
        for p_id in pecas[idx:]: cur.execute("INSERT INTO monte VALUES (%s, %s)", (partida_id, p_id))

        # Quem começa
        cur.execute("""
            SELECT m.jogador_id, m.peca_id, p.lado1, p.lado2 FROM mao_rodada m JOIN peca p ON p.id=m.peca_id 
            WHERE m.partida_id=%s 
            ORDER BY (p.lado1=6 AND p.lado2=6) DESC, (p.lado1=p.lado2) DESC, (p.lado1+p.lado2) DESC, GREATEST(p.lado1,p.lado2) DESC LIMIT 1
        """, (partida_id,))
        start_pid, start_peca_id, sl1, sl2 = cur.fetchone()

        idx_start = ids_da_rodada.index(start_pid)
        fila = ids_da_rodada[idx_start:] + ids_da_rodada[:idx_start]
        cur.execute("SELECT nome FROM jogador WHERE id=%s", (start_pid,))
        print(f"--- 🔔 SAÍDA: {cur.fetchone()[0]} com [{sl1}-{sl2}] ---")

        partida_rolando = True
        passes = 0
        t_idx = 0

        while partida_rolando:
            pid_atual = fila[t_idx % n_jogadores]
            cur.execute("SELECT nome FROM jogador WHERE id=%s", (pid_atual,))
            nome_atual = cur.fetchone()[0]

            print(f"\n>>> Vez de: {nome_atual}")
            while True:
                prompt = "(Enter) Jogar" + (" [OBRIGATÓRIO]" if t_idx==0 else "") + " | (m) Mãos | (d) Mesa | (p) Placar | (r) Ranking | (s) Sair: "
                cmd = input(prompt).strip().lower()
                if cmd=='m': mostrar_maos(partida_id, cur)
                elif cmd=='d': mostrar_mesa_visual(partida_id, cur)
                elif cmd=='p': mostrar_placar_individual_acumulado(cur)
                elif cmd=='r': mostrar_ranking_vitorias(cur)
                elif cmd=='s': conn.close(); sys.exit()
                elif cmd=='': break
                else: print("Inválido.")

            cur.execute("SELECT ponta1, ponta2 FROM mesa WHERE partida_id=%s", (partida_id,))
            p1, p2 = (cur.fetchone() or (None, None))

            cur.execute("SELECT m.peca_id, p.lado1, p.lado2 FROM mao_rodada m JOIN peca p ON p.id = m.peca_id WHERE m.jogador_id=%s AND m.partida_id=%s", (pid_atual, partida_id))
            mao = cur.fetchall()

            jogada = None
            if t_idx == 0:
                for p in mao:
                    if p[0] == start_peca_id: jogada=(p, 'esquerda'); break
            elif p1 is None:
                jogada=(mao[0], 'esquerda')
            else:
                cands = []
                for p in mao:
                    if p[1]==p1 or p[2]==p1: cands.append((p, 'esquerda'))
                    elif p[1]==p2 or p[2]==p2: cands.append((p, 'direita'))
                if cands:
                    cands.sort(key=lambda x: x[0][1]+x[0][2], reverse=True)
                    jogada = cands[0]

            if jogada:
                peca, lado = jogada
                print(f"ACTION: {nome_atual} joga [{peca[1]}-{peca[2]}] na {lado}")
                try:
                    cur.execute("CALL jogar_peca(%s, %s, %s, %s)", (pid_atual, partida_id, peca[0], lado))
                    passes = 0
                    cur.execute("SELECT data_fim FROM partida WHERE id=%s", (partida_id,))
                    if cur.fetchone()[0]:
                        print(f"\n🎉 VITÓRIA DE {nome_atual} (Bateu)!")
                        partida_rolando = False
                except Exception as e: print(f"Erro: {e}")
            else:
                cur.execute("SELECT COUNT(*) FROM monte WHERE partida_id=%s", (partida_id,))
                if cur.fetchone()[0]>0:
                    print(f"ACTION: {nome_atual} compra do monte...")
                    cur.execute("CALL comprar_do_monte(%s, %s)", (pid_atual, partida_id))
                else:
                    print(f"ACTION: {nome_atual} PASSOU a vez.")
                    cur.execute("INSERT INTO movimento (partida_id, turno, jogador_id, acao) VALUES (%s, (SELECT COALESCE(MAX(turno), 0)+1 FROM movimento WHERE partida_id=%s), %s, 'passou')", (partida_id, partida_id, pid_atual))
                    passes += 1

            if partida_rolando:
                cur.execute("SELECT verificar_se_trancou(%s)", (partida_id,))
                if cur.fetchone()[0] or passes >= n_jogadores:
                    print("\n🔒 JOGO TRANCOU 🔒")
                    cur.execute("SELECT * FROM calcular_vencedor_tranca(%s)", (partida_id,))
                    res = cur.fetchone()
                    if res:
                        v_id, v_eq, pts = res
                        print(f"Vence Equipe {v_eq} (Leva {pts} pontos).")
                        cur.execute("UPDATE partida SET data_fim=CURRENT_TIMESTAMP, vencedor_jogador_id= %s, vencedor_equipe= %s, trancou=TRUE WHERE id=%s", (v_id, v_eq, partida_id))
                    partida_rolando = False
            t_idx += 1

        mostrar_mesa_visual(partida_id, cur)
        mostrar_resumo_rodada(partida_id, cur)
        mostrar_placar_individual_acumulado(cur)
        mostrar_ranking_vitorias(cur)

        cur.execute("SELECT status, vencedor_equipe FROM jogo WHERE id=%s", (current_jogo_id,))
        st = cur.fetchone()
        if st and st[0] == 'finalizado':
            print(f"\n🏆🏆🏆 JOGO ENCERRADO (50 pts)! Vencedor: Equipe {st[1]} 🏆🏆🏆")
            limpar_banco_dados(conn, cur)
            current_jogo_id = None
        else:
            input("Enter para próxima rodada...")

    conn.close()
    print("Fim.")

if __name__ == "__main__":
    try: run_game()
    except KeyboardInterrupt: print("\nFim.")
    except Exception as e: print(f"\nERRO: {e}")