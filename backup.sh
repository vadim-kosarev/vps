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

# Имя хоста для имени файла
HOSTNAME=$(hostname)

# Путь к репозиторию VPS конфигураций
VPS_REPO_PATH="/root/vps"

# Читаем настройки из .env файла соответствующего хоста
HOST_ENV_FILE="${VPS_REPO_PATH}/${HOSTNAME}/.env"

# Если точного совпадения нет — ищем по маске HOSTNAME.* (напр. vkosarev → vkosarev.link)
if [[ ! -f "$HOST_ENV_FILE" ]]; then
    HOST_ENV_FILE_ALT=$(ls "${VPS_REPO_PATH}/${HOSTNAME}."*"/.env" 2>/dev/null | head -1)
    if [[ -n "$HOST_ENV_FILE_ALT" ]]; then
        HOST_ENV_FILE="$HOST_ENV_FILE_ALT"
        log INFO "Найден .env по маске: ${HOST_ENV_FILE}"
    fi
fi

# Значение по умолчанию
KEEP_DAYS=1

if [[ -f "$HOST_ENV_FILE" ]]; then
    log INFO "Загружаем настройки из файла: ${HOST_ENV_FILE}"
    # Загружаем только переменную BACKUP_KEEP_DAYS, игнорируя остальные
    if grep -q "^BACKUP_KEEP_DAYS=" "$HOST_ENV_FILE"; then
        KEEP_DAYS=$(grep "^BACKUP_KEEP_DAYS=" "$HOST_ENV_FILE" | cut -d'=' -f2)
        log INFO "Настройка BACKUP_KEEP_DAYS=${KEEP_DAYS} из .env файла"
    else
        log WARN "BACKUP_KEEP_DAYS не найден в .env файле, используем значение по умолчанию: ${KEEP_DAYS}"
    fi
else
    log WARN "Файл настроек не найден: ${HOST_ENV_FILE}, используем значение по умолчанию: ${KEEP_DAYS}"
fi
# ===============================================
DATE=$(date +%Y-%m-%d)
BACKUP_FILE="${TARGET_DIR}/backup-${HOSTNAME}-${DATE}.tar.gz"

# Создаём целевую папку
mkdir -p "$TARGET_DIR"

log INFO "=== БЭКАП ЗАПУЩЕН: ${DATE} ==="
log INFO "Директории: ${BACKUP_DIRS[*]}"
log INFO "Архив будет сохранён как: ${BACKUP_FILE}"

# Автоочистка старых бэкапов ДО создания нового (освобождаем место заранее)
# Правила хранения:
#   - хранить бэкапы за последние KEEP_DAYS дней
#   - хранить бэкапы от 1-го числа каждого месяца (YYYY-MM-01)
log INFO "Очистка старых бэкапов (хранить: последние ${KEEP_DAYS} дней + 1-е числа месяцев)..."

# Граничная дата: KEEP_DAYS дней назад в формате YYYY-MM-DD
CUTOFF_DATE=$(date -d "-${KEEP_DAYS} days" +%Y-%m-%d)

# Получаем все бэкапы текущего хоста
mapfile -t ALL_BACKUPS < <(
    find "$TARGET_DIR" -maxdepth 1 -name "backup-${HOSTNAME}-*.tar.gz" \
    | sort -r
)

for f in "${ALL_BACKUPS[@]}"; do
    fname=$(basename "$f")
    # Извлекаем дату из имени файла: backup-HOSTNAME-YYYY-MM-DD.tar.gz
    file_date=$(echo "$fname" | grep -oP '\d{4}-\d{2}-\d{2}')
    file_day=$(echo "$file_date" | cut -d'-' -f3)

    # Оставляем: бэкап за последние KEEP_DAYS дней
    if [[ "$file_date" > "$CUTOFF_DATE" || "$file_date" == "$CUTOFF_DATE" ]]; then
        log INFO "Сохраняем (последние ${KEEP_DAYS} дней): ${fname}"
        continue
    fi

    # Оставляем: 1-е число каждого месяца
    if [[ "$file_day" == "01" ]]; then
        log INFO "Сохраняем (1-е число месяца): ${fname}"
        continue
    fi

    # Удаляем остальное
    rm -f "$f"
    log WARN "Удалён старый бэкап: ${fname}"
done

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

log INFO "=== БЭКАП ЗАВЕРШЁН УСПЕШНО ==="