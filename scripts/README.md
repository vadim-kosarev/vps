# scripts/ — Вспомогательные скрипты анализа БД

## Что здесь

Скрипты анализа SQLite-баз данных **3x-ui** (Xray VPN панель) для двух хостов:
- `vkosarev.name/3x-ui/db/x-ui.db`
- `agghhh.click/3x-ui/db/x-ui.db`

---

## Скрипты

### `read_xui.py`
Первоначальный скрипт — читает все таблицы обеих БД и печатает их содержимое.  
**Баг:** `PRAGMA table_info` возвращал числовые индексы вместо имён колонок (`d[0]` вместо `d[1]`), поэтому inbounds отображались с `None` в полях.

### `read_xui2.py`
Доработанная версия (исправлен баг с PRAGMA).  
Читает:
- таблицу `inbounds` (протоколы, порты, settings, stream_settings, sniffing)
- таблицу `settings` (конфигурация xrayTemplateConfig — outbounds, routing rules)

**Метод:** используется `sqlite3.Row` для именованного доступа к колонкам.

### `read_xui3.py`
Финальная версия, сфокусированная только на `inbounds` с использованием `row_factory = sqlite3.Row`.  
Выводит подробный JSON для каждого inbound.

---

## Файлы результатов

| Файл | Содержимое |
|---|---|
| `tmp_xui_dump.txt` | Дамп из `read_xui.py` (частичный, из-за бага с колонками) |
| `xui_out.txt` | Дамп из `read_xui2.py` — settings + xrayTemplateConfig обоих хостов |
| `xui_inbounds.txt` | Дамп из `read_xui3.py` — полные inbounds с JSON-конфигами |

---

## Результат анализа

На основе данных из БД составлена архитектурная схема прокси-инфраструктуры:

📄 **[`../proxy-architecture.md`](../proxy-architecture.md)**

Схема описывает три режима работы:
1. **Telegram MTProto** — двухузловая цепочка `agghhh.click → vkosarev.name → Telegram`
2. **VLESS+Reality двойная цепочка** — для пользователей `msk`, `natasha-17`
3. **VLESS+Reality прямой выход** — для пользователя `VK` (direct с agghhh.click)

---

## Запуск

```bash
# Требует Python 3 и доступ к файлам БД
python scripts/read_xui3.py
```

