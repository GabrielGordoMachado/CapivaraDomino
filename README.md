\
# Capivara Domino - Python starter project

Conteúdo:
- `schema.sql` — DDL simplificado para PostgreSQL 12+ (tabelas e inserção das 28 peças).
- `simulate.py` — Simulador em Python que distribui peças, joga uma partida simples e imprime o resultado.
  - Optionally connects to PostgreSQL and applies `schema.sql` when run with `--db` (requires `psycopg2-binary` and PG env vars).
\n
## Como usar (local)
1. Clone/baixe os arquivos deste zip.
2. Tenha Python 3.8+ instalado.
3. Para rodar apenas a simulação (sem PostgreSQL):
   ```
   python simulate.py
   ```
4. Para aplicar o schema em um banco PostgreSQL (ex.: para testar triggers/procedures):
   - Instale driver: `pip install psycopg2-binary`
   - Configure variáveis de ambiente: `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`
   - Execute: `python simulate.py --db`
\n
## Próximos passos (sugestões)
- Implementar `proc_buy_from_boneyard`, `fn_possible_moves` e triggers no Postgres conforme enunciado.
- Adicionar CLI para criar partidas, cadastrar usuários e salvar movimentos no banco (psycopg2).
- Transformar o simulador em uma ferramenta de testes unitários para as funções PL/pgSQL.
\n
---\n
Boa sorte — se quiser, eu já gero:
- DDL mais completo com funções e triggers em PL/pgSQL;
- Código Python que grava cada movimento direto no banco (com transações e locks);
- Scripts de teste automatizados para cenários (bate, tranca, compra do monte).\n
Diga qual você prefere que eu gere agora.
