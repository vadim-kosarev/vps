# brightsky

Домашний хост (Windows, Docker Desktop, `192.168.1.43`) — не VPS. Держит Immich и
сопутствующие сервисы (см. `immich/` в репозитории [tools](https://github.com/vadim-kosarev/tools)),
сюда добавлен Portainer (полная панель + agent) для двусторонней связки со **starlight**:
с любого из двух хостов можно управлять docker'ом обоих.

## Перед первым деплоем

На brightsky **уже был поднят `portainer-ce` вручную** (не через compose), слушает те же
порты 8000/9443. Перед `docker compose up -d` останови и удали старый контейнер:

```bash
docker ps                    # найти имя старого portainer-контейнера
docker rm -f <имя>
```

Админ-аккаунт/данные из старого контейнера не переносятся автоматически — при первом заходе
на новый `:9443` создашь admin-аккаунт заново.

## Деплой

```bash
cd /путь/к/vps/brightsky   # или где склонирован репозиторий на brightsky
git pull
docker compose up -d
```

Поднимет:
- `portainer` — полная панель, UI `https://192.168.1.43:9443`.
- `portainer_agent` — агент на порту 9001, чтобы этот хост был виден из панели на starlight.
- `cadvisor` — метрики контейнеров для Prometheus на luigi (порт 8080).
- `dns` — Technitium DNS Server, локальный DNS для домашней сети (порт 53, web-консоль
  5380). Настройка зон/форвардеров — см. комментарий у сервиса `dns` в `docker-compose.yml`.

## Двусторонняя регистрация

**brightsky → видеть starlight** (в панели `https://192.168.1.43:9443`):
Environments → Add environment → Docker Standalone → Agent → `192.168.1.99:9001` → Connect.

**starlight → видеть brightsky** (в панели `https://192.168.1.99:9443`):
Environments → Add environment → Docker Standalone → Agent → `192.168.1.43:9001` → Connect.

После этого с любой из двух панелей управляются контейнеры обоих хостов.

## Существующие сервисы brightsky

Immich и остальное — вне этого репозитория/директории на данный момент (см. `immich/README.md`
в репозитории [tools](https://github.com/vadim-kosarev/tools)), этот `docker-compose.yml` их
не трогает и не заменяет.
