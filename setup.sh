#!/usr/bin/env bash
# =============================================================================
# setup.sh — минимальная настройка хоста VPS
# Запускать: sudo bash setup.sh  (из директории репозитория)
# Всё остальное разворачивается через docker compose.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && die "Запускать от root: sudo bash $0"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Docker Compose plugin (v2)
# =============================================================================
if docker compose version &>/dev/null; then
  warn "docker compose plugin уже установлен ($(docker compose version --short))"
else
  log "Устанавливаем docker-compose-v2..."
  apt-get update -qq
  apt-get install -y docker-compose-v2
  log "docker compose plugin установлен ($(docker compose version --short))"
fi

# =============================================================================
# Git — настройка remote с GitHub token
# Токен хранится в ~/.github.token (не коммитить!)
# =============================================================================
if [[ -f ~/.github.token ]]; then
  TOKEN=$(cat ~/.github.token)
  git -C "$REPO_DIR" remote set-url origin "https://${TOKEN}@github.com/vadim-kosarev/vps.git"
  git -C "$REPO_DIR" config --global user.email "root@$(hostname)"
  git -C "$REPO_DIR" config --global user.name "$(hostname)"
  log "git remote настроен с токеном из ~/.github.token"
else
  warn "~/.github.token не найден — git push работать не будет. Создайте файл с GitHub PAT."
fi

# =============================================================================
# node_exporter — экспортёр метрик хоста для Prometheus
# Снимает: CPU, RAM, диски, сеть (rx/tx байт, пакеты, ошибки)
# Должен работать на хосте (не в Docker), чтобы видеть реальные интерфейсы
# =============================================================================
NODE_EXPORTER_VERSION="1.8.2"

case "$(uname -m)" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l)  ARCH="armv7" ;;
  *)       die "Неизвестная архитектура: $(uname -m)" ;;
esac

if [[ -x /usr/local/bin/node_exporter ]]; then
  warn "node_exporter уже установлен, пропускаем установку"
  # Убедиться что сервис включён и запущен
  systemctl enable node_exporter &>/dev/null
  systemctl is-active --quiet node_exporter || systemctl start node_exporter
else
  log "Устанавливаем node_exporter v${NODE_EXPORTER_VERSION} (${ARCH})..."

  apt-get install -y wget ca-certificates

  TARBALL="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
  URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${TARBALL}"

  cd /tmp
  wget -q --show-progress "${URL}"
  tar xzf "${TARBALL}"
  mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/node_exporter
  chmod +x /usr/local/bin/node_exporter
  rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}" "${TARBALL}"

  id node_exporter &>/dev/null || useradd --no-create-home --shell /bin/false node_exporter

  cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.processes \
  --web.listen-address=:9100
Restart=always
RestartSec=5
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable node_exporter
  systemctl start node_exporter
  log "node_exporter запущен на порту 9100"
fi

# Проверка
sleep 1
if curl -sf http://localhost:9100/metrics | grep -q 'node_network_receive_bytes_total'; then
  log "Метрики сети доступны: http://localhost:9100/metrics"
else
  warn "node_exporter запущен, но метрики пока недоступны — проверьте: systemctl status node_exporter"
fi

# =============================================================================
# Итог
# =============================================================================
echo ""
log "Готово! Следующий шаг:"
echo "  cd $REPO_DIR/<хостинг>"
echo "  docker compose up -d"
echo ""
warn "Порт 9100 (node_exporter) должен быть закрыт для внешнего мира — Prometheus обращается к нему внутри хоста."

