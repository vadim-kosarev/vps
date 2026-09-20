#!/bin/bash
set -euo pipefail

log() { echo "[/entyrpoint.sh] [$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

retry_cmd() {
  local tries=$1; shift
  local delay=$1; shift
  local i
  for i in $(seq 1 "$tries"); do
    if "$@"; then
      return 0
    fi
    log "Retry $i/$tries failed: $*" >&2
    sleep "$delay"
  done
  return 1
}

if [ "${PROFILE:-}" == "dev" ]; then
  log "DEV mode (PROFILE=dev) - skipping WiFi AP setup"
else
  log "Starting in 30 seconds..."
  sleep 30
  log "Starting..."
  IFACE=${AP_IFACE:-wlan1}
  IPADDR=${AP_IP:-192.168.50.1}

  if ! ip link show "$IFACE" &>/dev/null; then
    log "Interface $IFACE not found. Existing interfaces:"
    ip link show | awk -F: '/^[0-9]+: /{print $2}'
    exit 1
  fi

  # Предупреждение если host процессы могут конфликтовать
  if pgrep -fa wpa_supplicant >/dev/null 2>&1; then
    log "WARN: wpa_supplicant process detected (может мешать AP)";
    pgrep -fa wpa_supplicant || true
  fi
  if pgrep -fa NetworkManager >/dev/null 2>&1; then
    log "WARN: NetworkManager process detected (отключите управление $IFACE)";
  fi

  # Разблокировать радио (на случай rfkill)
  if command -v rfkill &>/dev/null; then
    rfkill unblock all || true
  fi

  log "Preparing interface $IFACE for AP mode"
  retry_cmd 5 1 ip link set "$IFACE" down || true
  # Попытаться установить тип AP (игнорируем ошибку если уже __ap)
  if command -v iw &>/dev/null; then
    iw dev "$IFACE" set type __ap || true
  fi
  retry_cmd 5 1 ip link set "$IFACE" up || {
    log "Failed to bring $IFACE up after retries";
    exit 1;
  }

  # Сбросить старые адреса и назначить новый
  ip addr flush dev "$IFACE" || true
  ip addr add "$IPADDR/24" dev "$IFACE" || {
    log "Failed to assign IP to $IFACE"; exit 1; }

  # Включить форвардинг IPv4 (нужен для выхода клиентов в интернет)
  echo 1 > /proc/sys/net/ipv4/ip_forward || true

  # Небольшая задержка чтобы интерфейс стабилизировался
  sleep 1

  log "Starting hostapd"
  /usr/sbin/hostapd -B /etc/hostapd/hostapd.conf || { \
    log "hostapd failed to start"; \
    exit 1; }

  # Проверить что интерфейс в UP и имеет IP
  if ! ip addr show dev "$IFACE" | grep -q "$IPADDR"; then
    log "IP $IPADDR not present on $IFACE after configuration";
  fi
fi

# ВАЖНО: --keep-in-foreground, а не --no-daemon. --no-daemon = режим отладки (-d): dnsmasq не создаёт
# дочерних процессов для TCP-запросов, и любой клиент, открывший TCP на :53 и замолчавший, вешает
# весь DNS+DHCP навсегда. --log-facility=- пишет лог в stderr (в docker logs).
log "Starting dnsmasq"
dnsmasq --keep-in-foreground --log-facility=- --conf-file=/etc/dnsmasq.conf &
DNSMASQ_PID=$!

PORTAL_DNSMASQ_PID=""
if [ "${PROFILE:-}" != "dev" ]; then
  log "Starting portal dnsmasq (DNS для неавторизованных клиентов)"
  dnsmasq --keep-in-foreground --log-facility=- --conf-file=/etc/dnsmasq-portal.conf &
  PORTAL_DNSMASQ_PID=$!

  log "Setting up NAT/firewall (интернет через ${UPLINK_IFACE:-wlan0} только после авторизации на портале)"
  /wifi-fw.sh up || log "WARN: wifi-fw.sh up failed - интернет клиентам не выдаётся"
fi

cleanup() {
  local ec=$?
  log "Cleanup (exit code $ec) - stopping dnsmasq and firewall rules"
  if [ "${PROFILE:-}" != "dev" ]; then
    /wifi-fw.sh down || true
  fi
  kill "$DNSMASQ_PID" ${PORTAL_DNSMASQ_PID:+"$PORTAL_DNSMASQ_PID"} 2>/dev/null || true
}
trap cleanup EXIT INT TERM

log "Starting nginx"
nginx

log "Starting Python API in background"
python3 ./back.py &

# wait вместо foreground tail: иначе bash не выполнит trap по SIGTERM до выхода tail
tail -f /dev/null &
wait $!
