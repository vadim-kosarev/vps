import sqlite3, json, sys

for host, path in [
    ('vkosarev.name', r'C:\dev\github.com\vadim-kosarev\vps\vkosarev.name\3x-ui\db\x-ui.db'),
    ('agghhh.click',  r'C:\dev\github.com\vadim-kosarev\vps\agghhh.click\3x-ui\db\x-ui.db'),
]:
    print(f'\n{"="*60}')
    print(f'HOST: {host}')
    print(f'{"="*60}')
    con = sqlite3.connect(path)
    cur = con.cursor()

    # --- inbounds ---
    print('\n[INBOUNDS]')
    cols = [d[0] for d in cur.execute('PRAGMA table_info(inbounds)').fetchall()]
    print('columns:', cols)
    rows = cur.execute('SELECT * FROM inbounds').fetchall()
    for row in rows:
        d = dict(zip(cols, row))
        print(f"\n  id={d.get('id')} remark={d.get('remark')} protocol={d.get('protocol')} port={d.get('port')} enable={d.get('enable')}")
        for key in ('settings', 'stream_settings', 'sniffing', 'listen'):
            val = d.get(key, '')
            if val:
                try:
                    parsed = json.loads(val)
                    print(f"  {key}:")
                    print('    ' + json.dumps(parsed, indent=2, ensure_ascii=False).replace('\n', '\n    '))
                except Exception:
                    print(f"  {key}: {val}")

    # --- outbounds / settings for telegram proxy ---
    print('\n[SETTINGS (xray config)]')
    rows2 = cur.execute("SELECT * FROM settings").fetchall()
    cols2 = [d[0] for d in cur.execute('PRAGMA table_info(settings)').fetchall()]
    for row in rows2:
        d = dict(zip(cols2, row))
        for k, v in d.items():
            if v and len(str(v)) > 100:
                try:
                    parsed = json.loads(v)
                    print(f"  {k}:")
                    print('    ' + json.dumps(parsed, indent=2, ensure_ascii=False).replace('\n', '\n    '))
                except Exception:
                    print(f"  {k}: {str(v)[:1000]}")
            else:
                print(f"  {k}: {v}")

    con.close()

sys.stdout.flush()

