#!/bin/bash
# =============================================
# Скрипт ежедневного бэкапа с красивыми логами
# =============================================

set -o errexit          # выход при любой ошибке
set -o pipefail         # ловим ошибки в пайпах

# Красивая функция логирования (цвета только в терминале)
log() {
    local level="$1"
    shift
    local message="$*"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')

    local color="" reset="\033[0m"
    if [ -t 1 ]; then  # только если запущено в терминале
        case "$level" in
            INFO)  color="\033[0;32m" ;;   # зелёный
            WARN)  color="\033[0;33m" ;;   # жёлтый
            ERROR) color="\033[0;31m" ;;   # красный
            SUCCESS) color="\033[0;32m" ;;
            *)     color="" ;;
        esac
    fi

    echo -e "${color}[${ts}] [${level}] ${message}${reset}"
}

# ================== НАСТРОЙКИ ==================
# Список директорий, которые нужно бэкапить
BACKUP_DIRS=(
  "/data"
)

# Если передан аргумент (файл), читаем директории из него
if [[ -n "$1" && -f "$1" ]]; then
    log INFO "Чтение списка директорий для бэкапа из файла: $1"
    # Читаем только непустые строки, игнорируем комментарии
    mapfile -t BACKUP_DIRS < <(grep -vE '^\s*#|^\s*$' "$1")
    log INFO "Директории из файла: ${BACKUP_DIRS[*]}"
fi


# Куда складывать архивы
TARGET_DIR="/backup"

# Сколько дней хранить старые бэкапы (автоочистка)
KEEP_DAYS=30
# ===============================================

# Имя хоста для имени файла
HOSTNAME=$(hostname)
DATE=$(date +%Y-%m-%d)
BACKUP_FILE="${TARGET_DIR}/backup-${HOSTNAME}-${DATE}.tar.gz"

# Создаём целевую папку
mkdir -p "$TARGET_DIR"

log INFO "=== БЭКАП ЗАПУЩЕН: ${DATE} ==="
log INFO "Директории: ${BACKUP_DIRS[*]}"
log INFO "Архив будет сохранён как: ${BACKUP_FILE}"

# Проверка свободного места (минимум 10 ГБ)
FREE=$(df -BG "$TARGET_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
if [ "${FREE:-0}" -lt 10 ]; then
    log WARN "Мало свободного места! Осталось только ${FREE}G"
fi

# Сам бэкап
log INFO "Начинаем архивирование..."

if tar -czf "$BACKUP_FILE" "${BACKUP_DIRS[@]}" 2>&1; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log SUCCESS "БЭКАП УСПЕШНО ЗАВЕРШЁН! Размер: ${SIZE}"
else
    log ERROR "ОШИБКА при создании архива!"
    exit 1
fi

# Автоочистка старых бэкапов
log INFO "Очистка старых бэкапов старше ${KEEP_DAYS} дней..."
find "$TARGET_DIR" -name "backup-*.tar.gz" -mtime +${KEEP_DAYS} -delete -print0 | while read -r -d $'\0' oldfile; do
    log WARN "Удалён старый бэкап: $(basename "$oldfile")"
done

log INFO "=== БЭКАП ЗАВЕРШЁН УСПЕШНО ==="