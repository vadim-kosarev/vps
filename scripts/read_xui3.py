import sqlite3, json

for host, path in [
    ('vkosarev.name', r'C:\dev\github.com\vadim-kosarev\vps\vkosarev.name\3x-ui\db\x-ui.db'),
    ('agghhh.click',  r'C:\dev\github.com\vadim-kosarev\vps\agghhh.click\3x-ui\db\x-ui.db'),
]:
    print(f'\n{"="*60}')
    print(f'HOST: {host}')
    print(f'{"="*60}')
    con = sqlite3.connect(path)
    con.row_factory = sqlite3.Row  # <-- ключевое: row_factory для именованных колонок
    cur = con.cursor()

    print('\n[INBOUNDS]')
    rows = cur.execute('SELECT * FROM inbounds').fetchall()
    for row in rows:
        d = dict(row)
        print(f"\n  id={d.get('id')} remark={d.get('remark')} protocol={d.get('protocol')} port={d.get('port')} enable={d.get('enable')}")
        for key in ('settings', 'stream_settings', 'sniffing'):
            val = d.get(key, '')
            if val:
                try:
                    parsed = json.loads(val)
                    print(f"  {key}:")
                    print('    ' + json.dumps(parsed, indent=2, ensure_ascii=False).replace('\n', '\n    '))
                except Exception:
                    print(f"  {key}: {val}")

    con.close()

