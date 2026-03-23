# CLAUDE.md — Инструкции для AI-агента

## Контекст проекта

Этот репозиторий предназначен для управления конфигурациями VPS хостингов.  
Каждая директория верхнего уровня соответствует отдельному серверу или домену.

## Правила работы агента

- **Не делать `git commit` и `git push` без явной команды пользователя.**

## Git — просмотр изменений перед коммитом

Всегда использовать эту команду перед коммитом (неинтерактивная, без pager):

```powershell
git --no-pager status && git --no-pager diff && git --no-pager diff --cached
```

- `diff` — unstaged изменения
- `diff --cached` — staged (уже добавленные через `git add`)

Коммит после просмотра:

```powershell
git add -A && git commit -m "сообщение"
```

## Принципы работы

### Развёртывание
- **Предпочтительный способ деплоя — Docker / Docker Compose.**
- Основной файл конфигурации в каждой директории хостинга — `docker-compose.yml`.
- При добавлении нового сервиса описывать его в `docker-compose.yml` соответствующего хостинга.
- Использовать `docker compose up -d` для запуска в фоновом режиме.
- Использовать `docker compose pull && docker compose up -d` для обновления образов.

### Структура директорий
- Новый хостинг — новая директория в корне репозитория (название = домен или псевдоним сервера).
- Внутри директории хостинга хранятся только файлы конфигурации (compose, nginx-конфиги, скрипты).

### Секреты и переменные окружения
- Файлы `.env` **не коммитить** в репозиторий (они в `.gitignore`).
- Можно хранить `.env.example` с описанием необходимых переменных без реальных значений.
- Пароли, токены и ключи передавать только через переменные окружения или Docker secrets.

### Код и конфигурации
- Комментировать нетривиальные решения в `docker-compose.yml` и других конфигах.
- Указывать конкретные версии образов (не использовать тег `latest` в продакшне).
- По возможности указывать `restart: unless-stopped` для сервисов.

## Стек
- **Docker** + **Docker Compose** (плагин, команда `docker compose`)
- IDE: **IntelliJ IDEA** / JetBrains (`.idea/` и `*.iml` в `.gitignore`)

## Подключение к серверам по SSH

Рабочая машина — Windows. SSH-клиент — **PuTTY / plink**.  
Приватный ключ хранится локально: `Z:\MY\vk-amazon-2023-private.ppk`

### Выполнение команд на удалённом хосте

Всегда использовать **inline-команду** (без временных файлов):

```powershell
plink -load "vkosarev.name" -i "Z:\MY\vk-amazon-2023-private.ppk" -batch "команда"
```

Пример:

```powershell
plink -load "vkosarev.name" -i "Z:\MY\vk-amazon-2023-private.ppk" -batch "docker compose -f /root/vps/vkosarev.name/docker-compose.yml ps"
```

### Экранирование `$` в PowerShell

PowerShell раскрывает `$()` и `$var` внутри двойных кавычек локально.  
Чтобы передать `$` в bash на сервере — экранировать через backtick `` ` ``:

```powershell
# Неправильно — PowerShell выполнит $(cat ...) локально:
plink ... -batch "TOKEN=$(cat ~/.github.token) && git push"

# Правильно — `$ экранирует знак доллара, bash получит $(...) как есть:
plink ... -batch "TOKEN=`$(cat ~/.github.token) && git push"
```

### PuTTY Session

Настройки подключения хранятся в PuTTY Session с именем хоста (например, `vkosarev.name`).  
Сессия содержит: hostname/IP, порт, пользователя (`root`).

### Путь к репозиторию на сервере

```
/root/vps/
```

Деплой на сервере:

```bash
cd /root/vps/vkosarev.name
docker compose pull && docker compose up -d
```


