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
- `frpc` — FRP-клиент, пробрасывает сервисы brightsky на `vkosarev.name` (см. раздел ниже).
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

Immich, Frigate и остальное — вне этого репозитория/директории на данный момент (см.
`immich/README.md` и `frigate/README.md` в репозитории
[tools](https://github.com/vadim-kosarev/tools)), этот `docker-compose.yml` их не трогает и не
заменяет.

## frpc (туннели наружу через vkosarev.name)

brightsky пробрасывает свои сервисы на `vkosarev.name` через `frpc` (`brightsky_frpc`, конфиг —
`./frpc.toml`, формат TOML) — по образцу `starlight/docker-compose.yml` + `starlight/frpc.toml`.
До 2026-08-29 жил как `immich_frpc` в стеке Immich
(`tools/immich/docker/docker-compose.prod.yml`, конфиг `frpc.ini`) — перенесён сюда: сервисы в
[tools](https://github.com/vadim-kosarev/tools) (Immich, Frigate, Face Search/Finder, Video
Search) не должны ничего знать про то, что их публикуют наружу — это забота хоста
(brightsky), не утилиты. Публикация настраивается здесь, утилиты просто слушают локально.

Адресация в `frpc.toml`: сервисы на самом brightsky — по `brightsky.home` (host-published
порты, не docker-network/container-name — `frpc` теперь в отдельном compose-проекте и не
делит сеть с Immich/Frigate); голое `brightsky` из контейнера на самом brightsky не резолвится
(self-lookup баг Docker Desktop DNS-прокси, см. сервис `dns` выше) — только `.home`-суффикс.
luigi (NAS, LAN) и cam1 (Hikvision-камера, LAN) — по своим адресам напрямую.

Текущие туннели (см. `frpc.toml`): immich-server, face-search, face-finder, frigate-ui,
frigate-rtsp, video-search, luigi-grafana, luigi-torrent, luigi-subsonic, luigi-sync,
cam1 (HikCam). Соответствие внешних портов на `vkosarev.name` —
`vkosarev.name/nginx/conf.d/vkosarev.name.conf` в этом репозитории.
