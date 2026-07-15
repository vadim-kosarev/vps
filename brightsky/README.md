# brightsky

Домашний хост (Windows, Docker Desktop, `192.168.1.43`) — не VPS. Держит Immich и
сопутствующие сервисы (см. `local/tools/immich/`), сюда добавлен только Portainer Agent
для удалённого управления docker'ом этого хоста с **starlight**.

## Деплой

```bash
cd /путь/к/vps/brightsky   # или где склонирован репозиторий на brightsky
git pull
docker compose up -d
```

## Регистрация в Portainer на starlight

1. Открыть `https://192.168.1.99:9443` (Portainer на starlight).
2. Environments → Add environment → Docker Standalone → **Agent**.
3. Адрес: `192.168.1.43:9001`.
4. Connect — после этого контейнеры brightsky видны и управляются прямо из панели на starlight.

Полноценный `portainer-ce` на brightsky (`https://brightsky:9443`) при этом никуда не делся —
им можно продолжать пользоваться локально, agent из этого docker-compose.yml работает
параллельно и с ним не конфликтует (разные порты: 9443/8000 у portainer-ce, 9001 у agent).

## Существующие сервисы brightsky

Immich и остальное — вне этого репозитория/директории на данный момент (см.
`local/tools/immich/README.md`), этот `docker-compose.yml` их не трогает и не заменяет.