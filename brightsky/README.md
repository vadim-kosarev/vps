# brightsky

Домашний хост (Windows, Docker Desktop, `192.168.55.43`) — не VPS. Держит Immich и
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
- `portainer` — полная панель, UI `https://192.168.55.43:9443`.
- `portainer_agent` — агент на порту 9001, чтобы этот хост был виден из панели на starlight.
- `cadvisor` — метрики контейнеров для Prometheus на luigi (порт 8080).
- `dns` — Technitium DNS Server, локальный DNS для домашней сети (порт 53, web-консоль
  5380). Настройка зон/форвардеров — см. комментарий у сервиса `dns` в `docker-compose.yml`.

## Двусторонняя регистрация

**brightsky → видеть starlight** (в панели `https://192.168.55.43:9443`):
Environments → Add environment → Docker Standalone → Agent → `192.168.55.99:9001` → Connect.

**starlight → видеть brightsky** (в панели `https://192.168.55.99:9443`):
Environments → Add environment → Docker Standalone → Agent → `192.168.55.43:9001` → Connect.

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

### Health-check и автоперезапуск frpc

Известная проблема: когда на хосте что-то делают с другими контейнерами, встроенный DNS Docker
(`127.0.0.11`) периодически перестаёт резолвить `brightsky.home`; в логе frpc —
`lookup brightsky.home on 127.0.0.11:53: no such host`. Процесс при этом жив, поэтому
`restart: always` не срабатывает, а туннели не работают.

- У `brightsky_frpc` есть `healthcheck`: `nslookup brightsky.home && nslookup luigi`
  (каждые 30 с, 3 неудачи подряд → `unhealthy`).
- Сервис `frpc_autoheal` (`willfarrell/autoheal`, docker.sock) перезапускает контейнеры с label
  `autoheal=true` в состоянии `unhealthy` — docker сам unhealthy-контейнеры не рестартует.
- Статус: `docker ps --filter name=brightsky_frpc`; рестарты autoheal — в `docker logs brightsky_frpc_autoheal`.
- Ограничение: если DNS сломан у самого Docker Desktop (или `brightsky_dns` лежит), рестарт frpc
  не поможет — он будет перезапускаться каждые ~90 с, пока резолв не восстановится.

### DNS на хосте: порт 53 и NRPT для `.home`

Две настройки, без которых `brightsky.home` не резолвится (ни на хосте, ни в контейнерах frpc):

1. **Порт 53 привязан к LAN-IP** (`192.168.55.43:53` в сервисе `dns`). На `0.0.0.0:53` (IPv4 UDP)
   сидит Windows ICS (`svchost`, сервис `SharedAccess`) — он нужен Hyper-V/WSL, отключить его
   не получается (сервис сам поднимается и сбрасывает тип запуска), и Docker не мог занять порт:
   запросы на `192.168.55.43:53` уходили в ICS и таймаутились. При смене IP хоста — поправить
   `docker-compose.yml`.
2. **Правило NRPT**: Windows шлёт запросы для `.home` только на Technitium. Без него Windows
   (и Docker Desktop, который берёт DNS у хоста) опрашивал и роутер `192.168.55.1`, а тот отвечал
   NXDOMAIN (зон `.home` у него нет) — отсюда `lookup brightsky.home ... no such host` в frpc.
   Остальные запросы идут на обычные DNS (DHCP: Technitium, затем роутер), поэтому при
   остановленном `brightsky_dns` интернет работает, пропадают только имена `.home`.
   Правило хранится в реестре Windows (не в git), переживает перезагрузку.

PowerShell от администратора:

```powershell
# восстановить правило (например, после переустановки Windows)
Add-DnsClientNrptRule -Namespace ".home" -NameServers 192.168.55.43 -Comment "brightsky technitium"
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ResetServerAddresses   # DNS на Wi-Fi — от DHCP
Clear-DnsClientCache

# проверка
Get-DnsClientNrptRule | Where-Object Namespace -eq ".home"
Resolve-DnsName brightsky.home -DnsOnly
docker exec brightsky_frpc nslookup brightsky.home

# откат
Get-DnsClientNrptRule | Where-Object Namespace -eq ".home" | Remove-DnsClientNrptRule -Force
```

Не прописывать на Wi-Fi статический единственный DNS `192.168.55.43` (так было на время отладки):
при остановленном `brightsky_dns` (в т.ч. после перезагрузки, пока не стартовал Docker Desktop)
у хоста пропадает интернет по именам.
