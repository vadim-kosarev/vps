import sqlite3, json

for host, path in [
    ('vkosarev.name', r'C:\dev\github.com\vadim-kosarev\vps\vkosarev.name\3x-ui\db\x-ui.db'),
    ('agghhh.click',  r'C:\dev\github.com\vadim-kosarev\vps\agghhh.click\3x-ui\db\x-ui.db'),
]:
    print(f'\n========== {host} ==========')
    con = sqlite3.connect(path)
    cur = con.cursor()

    tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
    print('tables:', tables)

    for t in tables:
        cols = [d[0] for d in cur.execute(f'PRAGMA table_info({t})').fetchall()]
        rows = cur.execute(f'SELECT * FROM {t}').fetchall()
        print(f'\n--- {t} ({len(rows)} rows) ---')
        for row in rows:
            for c, v in zip(cols, row):
                if v and len(str(v)) > 200:
                    try:
                        parsed = json.loads(v)
                        print(f'  {c}: [JSON {len(str(v))} chars]')
                        print(json.dumps(parsed, indent=2, ensure_ascii=False)[:2000])
                    except Exception:
                        print(f'  {c}: {str(v)[:400]}...')
                else:
                    print(f'  {c}: {v}')
    con.close()

