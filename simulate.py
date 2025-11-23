from collections import deque

import psycopg2
import random
import time

# --- CONFIGURAÇÃO DO BANCO DE DADOS ---
DB_CONFIG = {
    "dbname": "capivaragame",  # Nome do seu banco
    "user": "postgres",  # Seu usuário
    "password": "marinezpadilhaA1",  # Sua senha
    "host": "localhost",
    "port": "5432"
}


def get_db_connection():
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = True
    return conn


# --- FUNÇÕES DE VISUALIZAÇÃO ---

def mostrar_maos(partida_id):
    """Consulta e printa as mãos atuais de todos os jogadores."""
    conn = get_db_connection()
    cur = conn.cursor()

    # Busca nome do jogador e suas peças
    sql = """
        SELECT j.nome, p.lado1, p.lado2
        FROM mao_rodada m
        JOIN jogador j ON j.id = m.jogador_id
        JOIN peca p ON p.id = m.peca_id
        WHERE m.partida_id = %s
        ORDER BY j.nome, p.lado1
    """
    cur.execute(sql, (partida_id,))
    rows = cur.fetchall()
    conn.close()

    if not rows:
        print("\n--- Mãos Vazias ou Erro ---")
        return

    maos = {}
    for nome, l1, l2 in rows:
        if nome not in maos:
            maos[nome] = []
        maos[nome].append(f"[{l1}-{l2}]")

    print("\n=== MÃOS DOS JOGADORES ===")
    for nome, pecas in maos.items():
        print(f"{nome}: {', '.join(pecas)}")
    print("==========================\n")


def mostrar_mesa_visual(partida_id):
    """Reconstroi a linha do dominó baseado no histórico de movimentos."""
    conn = get_db_connection()
    cur = conn.cursor()

    # Pega todos os movimentos de JOGADA (ignora compras/passos para visualização da mesa)
    # Retorna 4 colunas: lado, lado1, lado2, turno
    sql = """
        SELECT m.lado, p.lado1, p.lado2, m.turno
        FROM movimento m
        JOIN peca p ON p.id = m.peca_id
        WHERE m.partida_id = %s AND m.acao = 'jogou'
        ORDER BY m.turno 
    """
    cur.execute(sql, (partida_id,))
    movimentos = cur.fetchall()
    conn.close()

    if not movimentos:
        print("\n=== MESA: [ VAZIA ] ===\n")
        return

    # Deque para montar a cobra: (lado_esquerdo, lado_direito)
    cobra = deque()

    # Variaveis para rastrear as pontas atuais da visualização
    ponta_esq_atual = None
    ponta_dir_atual = None

    # CORREÇÃO AQUI: Adicionado '_turno' (ou apenas 'turno') para receber o 4º valor
    for i, (direcao, p1, p2, turno) in enumerate(movimentos):
        peca = (p1, p2)

        if i == 0:
            # Primeira peça (geralmente jogada na 'esquerda' ou 'direita' tecnicamente,
            # mas visualmente é o centro)
            cobra.append(peca)
            ponta_esq_atual = p1
            ponta_dir_atual = p2
        else:
            if direcao == 'esquerda':
                # Precisamos conectar na ponta_esq_atual
                l1, l2 = peca

                # Se a peça é (3,4) e a ponta atual é 4:
                # [3|4] - [4|X]...
                if l2 == ponta_esq_atual:
                    cobra.appendleft((l1, l2))
                    ponta_esq_atual = l1
                else:
                    # Inverte para conectar: [4|3] - [3|X]...
                    cobra.appendleft((l2, l1))
                    ponta_esq_atual = l2

            elif direcao == 'direita':
                # Conectar na ponta_dir_atual
                l1, l2 = peca

                # ...[X|4] - [4|3]
                if l1 == ponta_dir_atual:
                    cobra.append((l1, l2))
                    ponta_dir_atual = l2
                else:
                    # Inverte: ...[X|3] - [3|4]
                    cobra.append((l2, l1))
                    ponta_dir_atual = l1

    # Formata string
    visual = ",".join([f"[{p[0]}|{p[1]}]" for p in cobra])
    print(f"\n=== MESA ===\n{visual}\n============\n")


# --- FUNÇÕES DO JOGO (SETUP E LÓGICA) ---

def setup_game():
    conn = get_db_connection()
    cur = conn.cursor()

    print("--- 1. Preparando o Ambiente ---")
    cur.execute("TRUNCATE TABLE movimento, mao_rodada, monte, mesa, partida, jogo_jogador, jogo CASCADE;")

    nomes = ['Ana', 'Bruno', 'Carlos', 'Daniela']
    ids_jogadores = []
    print(f"Criando jogadores: {nomes}")
    for i, nome in enumerate(nomes):
        cur.execute("INSERT INTO jogador (nome) VALUES (%s) RETURNING id", (nome,))
        pid = cur.fetchone()[0]
        ids_jogadores.append(pid)

    cur.execute("INSERT INTO jogo (pontos_alvo) VALUES (50) RETURNING id")
    jogo_id = cur.fetchone()[0]

    for i, pid in enumerate(ids_jogadores):
        equipe = 1 if i % 2 == 0 else 2
        cur.execute("INSERT INTO jogo_jogador (jogo_id, jogador_id, equipe) VALUES (%s, %s, %s)",
                    (jogo_id, pid, equipe))

    print("Iniciando Partida 1...")
    cur.execute("INSERT INTO partida (jogo_id, numero) VALUES (%s, 1) RETURNING id", (jogo_id,))
    partida_id = cur.fetchone()[0]

    cur.execute("INSERT INTO mesa (partida_id) VALUES (%s)", (partida_id,))

    conn.commit()
    conn.close()
    return jogo_id, partida_id, ids_jogadores


def distribuir_pecas(partida_id, ids_jogadores):
    conn = get_db_connection()
    cur = conn.cursor()

    print("--- 2. Embaralhando e Distribuindo ---")

    cur.execute("SELECT id FROM peca")
    todas_pecas = [row[0] for row in cur.fetchall()]
    random.shuffle(todas_pecas)

    indice_peca = 0
    mao_jogador_inicial = None

    for pid in ids_jogadores:
        mao = todas_pecas[indice_peca: indice_peca + 7]
        indice_peca += 7

        for peca_id in mao:
            cur.execute("INSERT INTO mao_rodada (partida_id, jogador_id, peca_id) VALUES (%s, %s, %s)",
                        (partida_id, pid, peca_id))
            cur.execute("SELECT lado1, lado2 FROM peca WHERE id = %s", (peca_id,))
            l1, l2 = cur.fetchone()
            if l1 == 6 and l2 == 6:
                mao_jogador_inicial = pid

    sobras = todas_pecas[indice_peca:]
    for peca_id in sobras:
        cur.execute("INSERT INTO monte (partida_id, peca_id) VALUES (%s, %s)", (partida_id, peca_id))

    conn.commit()
    conn.close()
    return mao_jogador_inicial


def simular_rodada(partida_id, ids_jogadores, quem_comeca):
    conn = get_db_connection()
    cur = conn.cursor()

    idx_atual = ids_jogadores.index(quem_comeca)

    # Pega nome do inicial
    cur.execute("SELECT nome FROM jogador WHERE id = %s", (quem_comeca,))
    nome_inicial = cur.fetchone()[0]
    print(f"--- 3. Jogo Começou! {nome_inicial} tem o 6-6 (ou saída) ---")

    jogo_rolando = True
    consecutive_passes = 0

    while jogo_rolando:
        jogador_atual = ids_jogadores[idx_atual]

        # Obter nome
        cur.execute("SELECT nome FROM jogador WHERE id = %s", (jogador_atual,))
        nome_atual = cur.fetchone()[0]

        # --- PAUSA INTERATIVA ---
        print(f"\n>>> Vez de: {nome_atual}")
        while True:
            cmd = input("(enter) Jogar | (m) Ver Mãos | (d) Ver Mesa/Dominó | (s) Sair: ").strip().lower()

            if cmd == 'm':
                mostrar_maos(partida_id)
            elif cmd == 'd':
                mostrar_mesa_visual(partida_id)
            elif cmd == 's':
                print("Saindo da simulação...")
                conn.close()
                exit()
            elif cmd == '':
                # Prosseguir com a jogada (Enter)
                break
            else:
                print("Comando inválido.")

        # --- LÓGICA DE JOGO ORIGINAL ---

        cur.execute("SELECT ponta1, ponta2 FROM mesa WHERE partida_id = %s", (partida_id,))
        mesa = cur.fetchone()
        ponta1, ponta2 = mesa if mesa else (None, None)

        cur.execute("""
            SELECT m.peca_id, p.lado1, p.lado2 
            FROM mao_rodada m 
            JOIN peca p ON p.id = m.peca_id 
            WHERE m.jogador_id = %s AND m.partida_id = %s
        """, (jogador_atual, partida_id))
        mao = cur.fetchall()

        peca_escolhida = None
        lado_escolhido = None

        # IA Simples
        if ponta1 is None:
            peca_escolhida = mao[0]
            lado_escolhido = 'esquerda'
            for p in mao:
                if p[1] == 6 and p[2] == 6:
                    peca_escolhida = p
                    break
        else:
            candidatas = []
            for p in mao:
                pid, l1, l2 = p
                # Lógica ajustada para a procedure (ela aceita a peça e o lado, o banco valida)
                if l1 == ponta1 or l2 == ponta1:
                    candidatas.append((p, 'esquerda'))
                elif l1 == ponta2 or l2 == ponta2:
                    candidatas.append((p, 'direita'))

            if candidatas:
                escolha = random.choice(candidatas)
                peca_escolhida = escolha[0]
                lado_escolhido = escolha[1]

        if peca_escolhida:
            try:
                # Feedback visual do que vai acontecer
                l1, l2 = peca_escolhida[1], peca_escolhida[2]
                print(f"ACTION: {nome_atual} joga [{l1}-{l2}] na {lado_escolhido}")

                cur.execute("CALL jogar_peca(%s, %s, %s, %s)",
                            (jogador_atual, partida_id, peca_escolhida[0], lado_escolhido))
                consecutive_passes = 0

                cur.execute("SELECT COUNT(*) FROM mao_rodada WHERE jogador_id = %s AND partida_id = %s",
                            (jogador_atual, partida_id))
                if cur.fetchone()[0] == 0:
                    print(f"\n!!! VITÓRIA DE {nome_atual} !!!")
                    jogo_rolando = False
            except Exception as e:
                print(f"Erro ao jogar: {e}")
                jogo_rolando = False
        else:
            cur.execute("SELECT COUNT(*) FROM monte WHERE partida_id = %s", (partida_id,))
            monte_qtd = cur.fetchone()[0]

            if monte_qtd > 0:
                print(f"ACTION: {nome_atual} comprou do monte...")
                cur.execute("CALL comprar_do_monte(%s, %s)", (jogador_atual, partida_id))
            else:
                print(f"ACTION: {nome_atual} PASSOU a vez.")
                cur.execute(
                    "INSERT INTO movimento (partida_id, turno, jogador_id, acao) VALUES (%s, (SELECT COUNT(*)+1 FROM movimento WHERE partida_id=%s), %s, 'passou')",
                    (partida_id, partida_id, jogador_atual))
                consecutive_passes += 1

        cur.execute("SELECT verificar_se_trancou(%s)", (partida_id,))
        trancou = cur.fetchone()[0]

        if trancou or consecutive_passes >= 4:
            print("\n--- JOGO TRANCADO ---")
            cur.execute("UPDATE partida SET data_fim = CURRENT_TIMESTAMP, trancou = TRUE WHERE id = %s", (partida_id,))
            jogo_rolando = False

        idx_atual = (idx_atual + 1) % 4

    conn.close()


if __name__ == "__main__":
    try:
        jid, pid, jogadores = setup_game()
        quem_comeca = distribuir_pecas(pid, jogadores)
        if quem_comeca is None:
            quem_comeca = jogadores[0]

        simular_rodada(pid, jogadores, quem_comeca)

        print("\n--- FIM DA SIMULAÇÃO ---")

        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT * FROM partidas_com_vencedores WHERE partida_id = %s", (pid,))
        res = cur.fetchone()
        if res:
            print(f"Resultado DB: {res}")

    except Exception as e:
        print(f"Erro fatal: {e}")