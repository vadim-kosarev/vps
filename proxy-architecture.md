# Архитектура прокси-инфраструктуры

> Сгенерировано на основе анализа SQLite-баз данных 3x-ui.  
> Скрипты анализа: [`scripts/`](scripts/)

## Сервера

| Сервер | Провайдер | Роль |
|---|---|---|
| **agghhh.click** | Yandex Cloud | Entry node — RU-фронт, принимает клиентов |
| **vkosarev.name** | AWS (EU/Poland) | Exit node — EU-выход в интернет |

---

## 1. Telegram MTProto Proxy (telemt)

```
Telegram App
    │  MTProto TLS, port 8443
    │  secret: 0a9575dbddd96549971e23f597083667
    │  TLS-маскировка: browser.yandex.ru:443
    ▼
agghhh.click:8443   ← telemt v3.3.28 (Docker)
    │  SOCKS5 upstream tunnel
    ▼
vkosarev.name:8443  ← 3x-ui inbound "mixed -msk MTProxy"
                       protocol: mixed (SOCKS5+HTTP), noauth, UDP=true
    │
    ▼
Telegram Servers (Internet)
```

**Параметры telemt** (`agghhh.click/telemt/data/config.toml`):
- Режим: `tls = true` (classic/secure отключены)
- Маскировка: `tls_domain = "browser.yandex.ru"`, `mask_port = 443`
- Пользователь: `0a9575dbddd96549971e23f597083667`
- Upstream: `vkosarev.name:8443` via SOCKS5

---

## 2. VLESS+Reality двойная цепочка (msk, natasha-17)

```
VPN Client
    │  VLESS+Reality, port 443
    │  camouflage SNI: browser.yandex.com
    ▼
agghhh.click:443   ← 3x-ui inbound "MSK-PL:443" (id=4)
    │  Routing: users msk/natasha-17 → outbound "to-poland-reality"
    │  VLESS+Reality outbound
    │    → vkosarev.name:8080
    │    → UUID: 58318fd0-e8b9-40dd-a2d4-3292a0b5dc5d
    │    → flow: xtls-rprx-vision, SNI: yahoo.com, shortId: d6a74304
    ▼
vkosarev.name:8080  ← 3x-ui inbound "RU-PL" (id=8)
                       VLESS+Reality, camouflage: yahoo.com:443
    │
    ▼
Internet (EU exit)
```

---

## 3. VLESS+Reality прямой выход (VK)

```
VPN Client
    │  VLESS+Reality, port 40404
    │  camouflage SNI: browser.yandex.ru
    ▼
agghhh.click:40404  ← 3x-ui inbound "RU-RU:40404" (id=5)
    │  Routing: user VK → outbound "direct"
    ▼
Internet (прямо с agghhh.click)
```

---

## 4. Прямые EU-подключения к vkosarev.name

| Inbound | Protocol | Port | Camouflage | Пользователи |
|---|---|---|---|---|
| EU.443 *(disabled)* | VLESS+Reality | 443 | www.icloud.com | eu.vk.8888, EU.DEXP.Баня, projector, yandex, ya-pl, ma |
| EU.AMAZON | VLESS+Reality | 34819 | www.apple.com | vk-EU.amazon, natasha.eu, TV-SAMSUNG, vlad, seva → **YouTube/EU** |
| http-proxy | HTTP proxy | 10126 | — | user1 — **YouTube/браузер через HTTP proxy** |
| mixed MTProxy | mixed (SOCKS5) | 8443 | — | ← upstream для telemt |
| mtproxy (Docker) | MTProto orig | 2443 | — | стандартный Telegram MTProxy |

---

## Полная топология

```
                ┌──────────────────────────────────────┐
                │           agghhh.click               │
                │     (RU entry / Yandex Cloud)        │
                │                                      │
TG App ─8443──► │  telemt:8443 (TLS, yandex.ru mask)  │─SOCKS5─►┐
VPN msk ─443──► │  3x-ui:443  (VLESS+Reality MSK-PL)  │─VLESS──►│
VPN natasha─443►│  3x-ui:443  (VLESS+Reality MSK-PL)  │─VLESS──►│
VPN VK ─40404──►│  3x-ui:40404 (VLESS+Reality RU-RU) ─►Internet  │
                └──────────────────────────────────────┘         │
                                                                  ▼
                ┌──────────────────────────────────────┐
                │          vkosarev.name               │
                │      (EU exit / AWS Poland)          │
                │                                      │
TG App ─2443──► │  mtproxy:2443                        │──────►──┐
                │  3x-ui:8443 (mixed SOCKS5) ◄── telemt           │
                │  3x-ui:8080 (RU-PL VLESS)  ◄── agghhh chain ───┤
EU Client─34819►│  3x-ui:34819 (EU.AMAZON)            │──────►──┤
YT Client─10126►│  3x-ui:10126 (HTTP proxy)            │──────►──┤
                └──────────────────────────────────────┘         │
                               │                                  │
                               ▼                                  ▼
                      Internet / Telegram                  ▶️ YouTube
```

---

## Заметки по безопасности

- **VLESS+Reality** — трафик неотличим от HTTPS к легитимному сайту, не нужен собственный TLS-сертификат
- **telemt TLS-mode** — маскируется под TLS к `browser.yandex.ru:443`, защита от replay (65k записей / 30 мин окно)
- **Двойная цепочка** для msk/natasha-17: RU-сервер видит только трафик на Poland, EU-сервер не видит реальный IP клиента
- **Разные camouflage-домены** на каждом inbound для диверсификации SNI-отпечатков

