#!/bin/bash
# =============================================
# Ночной автодеплой: git pull + docker compose pull + up -d
# =============================================

set -o errexit
set -o pipefail

log() {
    local level="$1"
    shift
    local message="$*"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')

    local color="" reset="\033[0m"
    if [ -t 1 ]; then
        case "$level" in
            INFO)  color="\033[0;32m" ;;
            WARN)  color="\033[0;33m" ;;
            ERROR) color="\033[0;31m" ;;
            SUCCESS) color="\033[0;32m" ;;
            *)     color="" ;;
        esac
    fi

    echo -e "${color}[${ts}] [${level}] ${message}${reset}"
}

# ================== НАСТРОЙКИ ==================
VPS_REPO_PATH="/root/vps"
LOCK_FILE="/tmp/auto-deploy.lock"

HOST_DIR="$1"
if [[ -z "$HOST_DIR" ]]; then
    log ERROR "Использование: $0 <директория-хоста> (например: vkosarev.name)"
    exit 1
fi

HOST_PATH="${VPS_REPO_PATH}/${HOST_DIR}"
if [[ ! -d "$HOST_PATH" ]]; then
    log ERROR "Директория хоста не найдена: ${HOST_PATH}"
    exit 1
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log WARN "Другой запуск auto-deploy.sh уже выполняется, выходим"
    exit 0
fi
# ===============================================

log INFO "=== АВТОДЕПЛОЙ ЗАПУЩЕН: ${HOST_DIR} ==="

cd "$VPS_REPO_PATH"

OLD_REV=$(git rev-parse HEAD)
log INFO "Текущий коммит: ${OLD_REV}"

git pull --recurse-submodules
NEW_REV=$(git rev-parse HEAD)

if [[ "$OLD_REV" != "$NEW_REV" ]]; then
    log INFO "Репозиторий обновлён: ${OLD_REV} -> ${NEW_REV}"
else
    log INFO "Репозиторий без изменений"
fi

cd "$HOST_PATH"

log INFO "Проверяем свежие образы (docker compose pull)..."
docker compose pull

log INFO "Применяем обновления (docker compose up -d) — Docker Compose сам пересоздаст только изменившиеся сервисы"
docker compose up -d --remove-orphans

log SUCCESS "=== АВТОДЕПЛОЙ ЗАВЕРШЁН: ${HOST_DIR} ==="
