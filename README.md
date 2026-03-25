# vps

Репозиторий содержит конфигурации сервисов для двух VPS-хостингов, управляемых через Docker Compose.

## Серверы

| Хостинг | Провайдер | Назначение |
|---|---|---|
| `vkosarev.name` | AWS | Основной сервер: Xray VPN, MTProxy, мониторинг |
| `agghhh.click` | Yandex Cloud | Фронтенд-узел: Xray VPN, MTProxy (multi-hop) |

---

## Схема прокси-инфраструктуры

Подробная архитектура со всеми режимами работы: **[proxy-architecture.md](proxy-architecture.md)**

### Telegram

```mermaid
flowchart TD
    TG["📱 Telegram App"]
    VPN_VK["💻 VPN Client\n(VK)"]
    VPN_MSK["💻 VPN Client\n(msk / natasha-17)"]
    EU_CLIENT["💻 EU Client\n(direct VLESS)"]

    subgraph agghhh ["agghhh.click — RU entry (Yandex Cloud)"]
        TELEMT["telemt:8443\nMTProto TLS\nmask: browser.yandex.ru"]
        XUI_40404["3x-ui:40404\nVLESS+Reality\nSNI: browser.yandex.ru"]
        XUI_443["3x-ui:443\nVLESS+Reality\nSNI: browser.yandex.com"]
    end

    subgraph vkosarev ["vkosarev.name — EU exit (AWS Poland)"]
        RU_PL["3x-ui:8080\nVLESS+Reality\nSNI: yahoo.com"]
        EU_AMAZON["3x-ui:34819\nVLESS+Reality\nSNI: apple.com"]
        MIXED["3x-ui:8443\nmixed SOCKS5\n(MTProxy upstream)"]
        MTPROXY["mtproxy:2443\nTG MTProxy classic"]
    end

    TELEGRAM(("📨 Telegram"))

    TG -->|"MTProto TLS :8443"| TELEMT
    TG -->|"MTProto :2443"| MTPROXY
    VPN_MSK -->|"VLESS+Reality :443"| XUI_443
    VPN_VK -->|"VLESS+Reality :40404"| XUI_40404
    EU_CLIENT -->|"VLESS+Reality :34819"| EU_AMAZON

    TELEMT -->|"SOCKS5"| MIXED
    XUI_443 -->|"VLESS+Reality chain"| RU_PL
    XUI_40404 -->|"direct"| TELEGRAM

    MIXED --> TELEGRAM
    RU_PL --> TELEGRAM
    MTPROXY --> TELEGRAM
    EU_AMAZON --> TELEGRAM
```

### YouTube

```mermaid
flowchart TD
    VPN_MSK["💻 VPN Client\n(msk / natasha-17)"]
    EU_CLIENT["💻 EU Client\n(direct VLESS)"]
    YT_CLIENT["📺 YouTube / Browser\n(HTTP proxy client)"]

    subgraph agghhh ["agghhh.click — RU entry (Yandex Cloud)"]
        XUI_443["3x-ui:443\nVLESS+Reality\nSNI: browser.yandex.com"]
    end

    subgraph vkosarev ["vkosarev.name — EU exit (AWS Poland)"]
        RU_PL["3x-ui:8080\nVLESS+Reality\nSNI: yahoo.com"]
        EU_AMAZON["3x-ui:34819\nVLESS+Reality\nSNI: apple.com"]
        HTTP_PROXY["3x-ui:10126\nHTTP proxy\nauth: user1"]
    end

    YOUTUBE(("▶️ YouTube"))

    VPN_MSK -->|"VLESS+Reality :443"| XUI_443
    EU_CLIENT -->|"VLESS+Reality :34819"| EU_AMAZON
    YT_CLIENT -->|"HTTP proxy :10126"| HTTP_PROXY

    XUI_443 -->|"VLESS+Reality chain"| RU_PL

    RU_PL --> YOUTUBE
    EU_AMAZON --> YOUTUBE
    HTTP_PROXY --> YOUTUBE
```


---

## Сервисы по хостингам

### vkosarev.name

| Сервис | Образ | Порты | Назначение |
|---|---|---|---|
| `3x-ui` | `ghcr.io/mhsanaei/3x-ui` | 443, 2055, 8080, 8443, 34819 | Xray VPN панель (VLESS+Reality) |
| `3x-ui` (http-proxy) | `ghcr.io/mhsanaei/3x-ui` | 10126 | HTTP-прокси для YouTube/браузера |
| `mtproxy` | `telegrammessenger/proxy` | 2443 | Telegram MTProxy (выходной узел) |
| `prometheus` | `prom/prometheus` | 9090 (localhost) | Сбор метрик |
| `grafana` | `grafana/grafana` | 3000 | Дашборды мониторинга |
| `portainer` | `portainer/portainer-ce` | 9443 | Управление Docker |
| `iperf3` | `networkstatic/iperf3` | 5201 | Замер пропускной способности |
| `mermaid` | `johnsinclair73/mermaid-live-editor` | 3200 | Редактор диаграмм |
| `node_exporter` | *(systemd, не Docker)* | 9100 | Метрики хоста для Prometheus |

### agghhh.click

| Сервис | Образ | Порты | Назначение |
|---|---|---|---|
| `3x-ui` | `ghcr.io/mhsanaei/3x-ui` | 443, 2077, 40404 | Xray VPN панель |
| `telemt` | *(собирается из Dockerfile)* | 8443, 9091 | MTProxy фронтенд (multi-hop) |
| `portainer` | `portainer/portainer-ce` | 9443 | Управление Docker |

---

## Структура репозитория

```
.
├── setup.sh                   # Общий скрипт начальной настройки хоста
│                              # (docker-compose-v2, node_exporter, git remote)
├── vkosarev.name/
│   ├── docker-compose.yml
│   ├── 3x-ui/db/              # БД панели Xray (x-ui.db)
│   ├── mtproxy/data/          # Данные MTProxy (секрет)
│   ├── portainer/data/        # Данные Portainer
│   ├── prometheus/            # Конфиг и данные Prometheus
│   └── grafana/data/          # Данные Grafana
└── agghhh.click/
    ├── docker-compose.yml
    ├── 3x-ui/db/              # БД панели Xray (x-ui.db)
    ├── telemt/
    │   ├── Dockerfile         # Собирает telemt из GitHub releases
    │   └── data/              # Конфиг и секрет telemt
    └── portainer/data/        # Данные Portainer
```

---

## Начальная настройка нового хоста

```bash
# 1. Положить GitHub PAT токен
echo "ghp_xxx" > ~/.github.token

# 2. Клонировать репозиторий
git clone https://github.com/vadim-kosarev/vps.git /root/vps
cd /root/vps

# 3. Запустить setup.sh (устанавливает docker-compose-v2, node_exporter, настраивает git)
sudo bash setup.sh

# 4. Запустить сервисы нужного хостинга
cd /root/vps/vkosarev.name   # или agghhh.click
cp .env.example .env          # заполнить переменные
docker compose up -d
```

---

## Переменные окружения

Каждая директория хостинга содержит `.env.example` — шаблон с описанием переменных.  
Реальный `.env` не коммитится в репозиторий.

Ключевые переменные:

| Переменная | Описание |
|---|---|
| `CERT_DIR` | Путь к папке с TLS-сертификатами (монтируется во все контейнеры) |
| `GRAFANA_ADMIN_PASSWORD` | Пароль администратора Grafana |

---

## SSH-подключение (Windows)

```powershell
# vkosarev.name
plink -load "vkosarev.name" -i "Z:\MY\vk-amazon-2023-private.ppk" -batch "команда"

# agghhh.click
plink -i "Z:\MY\vk-amazon-2023-private.ppk" -batch -l vaduhann `
  -hostkey "SHA256:IzR02mcCTg2YMg2ruQ0gNPpDfJZOK1UmrZ1L65530b8" agghhh.click "команда"
```
