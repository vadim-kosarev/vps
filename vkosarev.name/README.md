# vkosarev.name — восстановление хоста с нуля

Снимок состояния сервера снят вручную **2026-07-14** (Ubuntu 24.04.4 LTS, AWS, регион — Польша,
ядро `6.8.0-134-generic`). Инструкция ниже описывает **всё, что не лежит в git** и что нужно
воссоздать руками после полного сноса и переустановки VPS. То, что уже в репозитории
(`docker-compose.yml`, `nginx/`, `frps/frps.toml`) — само подтянется через `git clone`/`git pull`,
здесь не дублируется.

> ⚠️ **Перед тем как сносить VPS** — скачай `/backup/*.tar.gz` себе локально (см. раздел
> «Бэкапы» ниже). Они хранятся **на том же диске**, что и всё остальное, и погибнут вместе с
> сервером.

---

## 0. Внешние зависимости (вне сервера)

- **DNS**: `vkosarev.name` должен указывать (A-запись) на новый IP сервера — правится у
  регистратора домена, не на сервере.
- **AWS Security Group**: firewall самого хоста открыт полностью (`iptables INPUT` — `policy
  ACCEPT`, никаких ограничений) — единственное, что реально фильтрует трафик снаружи, это
  Security Group в AWS-консоли. Список портов, которые должны быть разрешены на `0.0.0.0/0`,
  см. раздел «Порты» ниже. Из сервера это не проверить (IMDS недоступен из этой сессии) —
  сверять руками в консоли AWS.
- **TLS-сертификат** `vkosarev.name` — куплен на CheapSSL (не Let's Encrypt, автопродления
  через certbot на сервере нет). Файлы `vkosarev.name_fullchain.crt` +
  `vkosarev.name_privatekey.key` нужно либо перевыпустить, либо достать из архива/менеджера
  паролей — на сервере их копии нет нигде, кроме `/root/cert`.

---

## 1. Базовая настройка хоста

```bash
git clone https://github.com/vadim-kosarev/vps.git /root/vps
cd /root/vps
sudo bash setup.sh
```

`setup.sh` делает автоматически:
- ставит `docker-compose-v2`, `sqlite3`;
- настраивает `git remote` с токеном из `~/.github.token` (нужен только если планируешь `git
  push` прямо с сервера — при обычной работе пушим локально, так что можно пропустить);
- ставит `node_exporter` v1.8.2 как systemd-сервис (`/etc/systemd/system/node_exporter.service`,
  слушает `:9100`, юзер `node_exporter`, `ProtectSystem=strict`) — **порт 9100 не должен
  быть открыт наружу** (только для Prometheus внутри хоста);
- добавляет в root-crontab ежедневный бэкап в 03:00 МСК:
  `0 3 * * * /usr/bin/systemd-cat -t backup /root/vps/backup.sh /root/vps/vkosarev.name/backup.list`

### Чего `setup.sh` НЕ делает (нужно руками)

#### a. Cron: чистка старых Docker-образов

`setup.sh` его не создаёт — добавлен вручную в какой-то момент, в git не входит:

```
# /etc/cron.d/docker-image-prune
45 0 * * * root docker image prune -af --filter "until=24h" > /dev/null 2>&1
```

#### b. iptables DNAT — проброс frps-туннелей наружу

`frps` слушает туннели только на `127.0.0.1` хоста (`proxyBindAddr = "127.0.0.1"` в
`frps/frps.toml` — сделано специально, чтобы НЕ публиковать все туннели разом). Наружу
пробрасываются только конкретные порты через iptables DNAT — вручную, точечно:

```bash
sysctl -w net.ipv4.conf.all.route_localnet=1
echo "net.ipv4.conf.all.route_localnet=1" >> /etc/sysctl.conf

# luigi-sync (Resilio Sync), добавлено 2026-06-12
iptables -t nat -A PREROUTING -p tcp --dport 41404 -j DNAT --to-destination 127.0.0.1:41404
iptables -A FORWARD -p tcp -d 127.0.0.1 --dport 41404 -j ACCEPT

# starlight-vnc (TightVNC, парольная аутентификация в TightVNC включена), добавлено 2026-07-14
iptables -t nat -A PREROUTING -p tcp --dport 5900 -j DNAT --to-destination 127.0.0.1:5900
iptables -A FORWARD -p tcp -d 127.0.0.1 --dport 5900 -j ACCEPT

apt-get install -y iptables-persistent   # если ещё не стоит — даст netfilter-persistent
netfilter-persistent save
```

> ⚠️ `luigi-sync-udp` (UDP 41404) зарегистрирован на стороне frpc, но DNAT-правило на этом
> сервере есть только для TCP — если понадобится именно UDP-проброс, DNAT-правило для него
> нужно добавить отдельно (`-p udp`).

#### c. TLS-сертификаты

```bash
mkdir -p /root/cert
# положить сюда vkosarev.name_fullchain.crt и vkosarev.name_privatekey.key
chown root:root /root/cert/*
chmod 644 /root/cert/vkosarev.name_fullchain.crt
chmod 600 /root/cert/vkosarev.name_privatekey.key
```

На текущем сервере файлы лежат с группой `grafanagroup` (GID 472 — штатный UID/GID образа
Grafana) и правами `640`, но это не обязательно: сервис `grafana` в `docker-compose.yml`
запущен с `user: "0:0"` (root внутри контейнера), так что достаточно `root:root` с обычными
правами выше.

#### d. `.env` — переменные окружения

```bash
cd /root/vps/vkosarev.name
cp .env.example .env
# заполнить пароли/секреты
```

Актуальный список переменных, которые реально читает `docker-compose.yml` (часть из них
отсутствовала в старом `.env.example` — файл обновлён этим коммитом):

| Переменная | Назначение | Дефолт если не задана |
|---|---|---|
| `CERT_DIR` | Путь к папке с TLS-сертификатами | `/root/cert` |
| `NODE_NAME` | Метка хоста в метриках Prometheus | — |
| `XUI_PORT` | Порт веб-панели 3x-ui | `2055` (для справки — фактически задаётся внутри панели) |
| `GRAFANA_ADMIN_PASSWORD` | Пароль admin в Grafana | `changeme` |
| `GRAFANA_DATA` | Путь к данным Grafana | `./grafana/data` |
| `PROMETHEUS_DATA` | Путь к данным Prometheus | `./prometheus/data` |
| `PORTAINER_DATA` | Путь к данным Portainer | `./portainer/data` |
| `MTPROXY_DATA` | Путь к данным MTProxy (секрет прокси) | `./mtproxy/data` |
| `XUI_EXPORTER_ORIGIN` | URL панели 3x-ui для экспортёра метрик | `https://host.docker.internal:2055/vkosarev.name.eu/` |
| `XUI_EXPORTER_USERNAME` | Логин 3x-ui для экспортёра | `vkosarev` |
| `XUI_EXPORTER_PASSWORD` | Пароль 3x-ui для экспортёра | `changeme` |
| `XUI_EXPORTER_PORT` | Порт, на котором отдаются метрики экспортёра | `3001` |
| `BACKUP_KEEP_DAYS` | Сколько дней хранить локальные бэкапы (`backup.sh`) | — |

---

## 2. Запуск

```bash
cd /root/vps/vkosarev.name
docker compose up -d
```

Если есть бэкап (см. ниже) — распаковать его в `/root/vps/vkosarev.name` **до** `docker compose
up -d`, тогда поднимутся с уже существующими данными (Grafana dashboards, Prometheus TSDB,
Portainer users, 3x-ui inbound-конфиги, секрет MTProxy).

---

## 3. Бэкапы

- `backup.sh` (корень репозитория) архивирует директории из `backup.list`
  (`/root/vps/vkosarev.name` — все bind-mount данные контейнеров, и `/data` — легаси-каталог,
  не используется текущим `docker-compose.yml`, оставлен как есть) в `/backup/backup-<host>-
  <дата>.tar.gz`, хранит последние `BACKUP_KEEP_DAYS` дней.
- Крутится ежедневно в 03:00 МСК через cron (см. выше), логи — `journalctl -t backup`.
- **Бэкапы лежат локально на том же диске, никуда не выгружаются** (ни в S3, ни куда-либо ещё).
  Если планируешь сносить сервер — забери `/backup/*.tar.gz` к себе заранее (`pscp`/`scp` —
  это разовое скачивание твоих данных, не деплой конфигурации, так что общее правило «только
  через git» сюда не относится).

---

## 4. Порты, которые должны быть открыты в Security Group (0.0.0.0/0)

| Порт(ы) | Сервис | Примечание |
|---|---|---|
| 443, 2055, 8080, 8443, 34819, 10126 | 3x-ui (`network_mode: host`) | VLESS+Reality inbounds + панель + HTTP-прокси |
| 3001 | 3x-ui-exporter | метрики Prometheus |
| 7401 | frps | TCP + KCP/UDP, приём frpc-клиентов |
| 7599 | frps dashboard | `webServer.addr = 0.0.0.0` — авторизация Basic Auth в самом frps |
| 9090 | Prometheus | |
| 3000 | Grafana | |
| 2443 | MTProxy | |
| 5201 | iperf3 | |
| 3200 | Mermaid Live | |
| 8000, 9443 | Portainer | |
| 88, 11966 | myip | |
| 80, 1443, 3181, 5001, 981, 4041, 3021, 11444, 8766, 8768, 3010, 5902 | nginx (`network_mode: host`) | список = все `listen` в `nginx/conf.d/vkosarev.name.conf` |
| 41404 (TCP; UDP не пробрасывается, см. выше) | iptables DNAT → 127.0.0.1:41404 | luigi-sync |
| 5900 | iptables DNAT → 127.0.0.1:5900 | starlight-vnc (сырой TCP, см. также noVNC на 5902) |

**НЕ открывать наружу:** `9100` (node_exporter — только для Prometheus внутри хоста).

---

## 5. Хосты, зависящие от этого сервера

- **starlight** (`../starlight/`) — отдельный домашний хост со своим frpc-клиентом,
  регистрирует туннели `starlight-vnc` (5900) и `starlight-ollama` (11434) на этот frps.
  Ничего разворачивать здесь не нужно, просто учитывать, что после переустановки
  `vkosarev.name` frpc на starlight сам переподключится (тот же `server_addr`/`token` в
  `starlight/frpc.toml`).
- Прочие frps-клиенты (luigi, frigate, cam1 и т.д., см. `local/tools/immich/docker/frpc.ini`)
  подключаются тем же образом — их поднимать не нужно, они сами переподключатся к frps как
  только тот появится на прежнем адресе с тем же `token`.
