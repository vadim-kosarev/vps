#!/bin/bash
# Firewall/NAT точки доступа: интернет через UPLINK_IFACE получают только клиенты
# из ipset AUTH_SET (туда их добавляет back.py после нажатия кнопки на портале).
# Остальным (неавторизованным) DNS подменяется на портальный dnsmasq, HTTP уходит на портал,
# всё остальное наружу режется. В локальные сети за uplink не пускаем никого.
#
# Использование: wifi-fw.sh up|down
set -euo pipefail

AP_IFACE=${AP_IFACE:-wlan1}
AP_IP=${AP_IP:-192.168.50.1}
AP_NET=${AP_NET:-192.168.50.0/24}
UPLINK_IFACE=${UPLINK_IFACE:-wlan0}
AUTH_SET=${AUTH_SET:-wifi_authed}
AUTH_TTL=${AUTH_TTL:-86400}
PORTAL_DNS_PORT=${PORTAL_DNS_PORT:-5354}
FW_PREFIX=${FW_PREFIX:-WIFI}

CAPTIVE_CHAIN="${FW_PREFIX}_CAPTIVE"
FWD_CHAIN="${FW_PREFIX}_FWD"
PRIVATE_NETS="10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 100.64.0.0/10"

ipt() { iptables -w 5 "$@"; }

# Правила Docker для FORWARD начинаются с цепочки DOCKER-USER — вешаемся туда, чтобы
# наши решения принимались раньше Docker и переживали его перезапуск.
forward_parent() {
  if ipt -S DOCKER-USER >/dev/null 2>&1; then echo DOCKER-USER; else echo FORWARD; fi
}

fw_up() {
  echo 1 > /proc/sys/net/ipv4/ip_forward
  ipset create "$AUTH_SET" hash:ip timeout "$AUTH_TTL" -exist

  # NAT клиентов точки доступа наружу через uplink
  ipt -t nat -C POSTROUTING -s "$AP_NET" -o "$UPLINK_IFACE" -j MASQUERADE 2>/dev/null ||
    ipt -t nat -A POSTROUTING -s "$AP_NET" -o "$UPLINK_IFACE" -j MASQUERADE

  # nat/PREROUTING: неавторизованные клиенты
  ipt -t nat -N "$CAPTIVE_CHAIN" 2>/dev/null || ipt -t nat -F "$CAPTIVE_CHAIN"
  ipt -t nat -A "$CAPTIVE_CHAIN" -m set --match-set "$AUTH_SET" src -j RETURN
  ipt -t nat -A "$CAPTIVE_CHAIN" -p udp --dport 53 -j REDIRECT --to-ports "$PORTAL_DNS_PORT"
  ipt -t nat -A "$CAPTIVE_CHAIN" -p tcp --dport 53 -j REDIRECT --to-ports "$PORTAL_DNS_PORT"
  ipt -t nat -A "$CAPTIVE_CHAIN" -d "$AP_IP" -j RETURN
  ipt -t nat -A "$CAPTIVE_CHAIN" -p tcp --dport 80 -j DNAT --to-destination "$AP_IP:80"
  ipt -t nat -C PREROUTING -i "$AP_IFACE" -j "$CAPTIVE_CHAIN" 2>/dev/null ||
    ipt -t nat -I PREROUTING 1 -i "$AP_IFACE" -j "$CAPTIVE_CHAIN"

  # filter/FORWARD: что пропускаем между точкой доступа и uplink
  ipt -N "$FWD_CHAIN" 2>/dev/null || ipt -F "$FWD_CHAIN"
  local net
  for net in $PRIVATE_NETS; do
    ipt -A "$FWD_CHAIN" -i "$AP_IFACE" -o "$UPLINK_IFACE" -d "$net" -j REJECT
  done
  ipt -A "$FWD_CHAIN" -i "$AP_IFACE" -o "$UPLINK_IFACE" -m set --match-set "$AUTH_SET" src -j ACCEPT
  ipt -A "$FWD_CHAIN" -i "$UPLINK_IFACE" -o "$AP_IFACE" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ipt -A "$FWD_CHAIN" -i "$AP_IFACE" -o "$UPLINK_IFACE" -p tcp -j REJECT --reject-with tcp-reset
  ipt -A "$FWD_CHAIN" -i "$AP_IFACE" -o "$UPLINK_IFACE" -j REJECT
  local parent
  parent=$(forward_parent)
  ipt -C "$parent" -j "$FWD_CHAIN" 2>/dev/null || ipt -I "$parent" 1 -j "$FWD_CHAIN"
}

fw_down() {
  local parent
  parent=$(forward_parent)
  ipt -D "$parent" -j "$FWD_CHAIN" 2>/dev/null || true
  ipt -F "$FWD_CHAIN" 2>/dev/null || true
  ipt -X "$FWD_CHAIN" 2>/dev/null || true
  ipt -t nat -D PREROUTING -i "$AP_IFACE" -j "$CAPTIVE_CHAIN" 2>/dev/null || true
  ipt -t nat -F "$CAPTIVE_CHAIN" 2>/dev/null || true
  ipt -t nat -X "$CAPTIVE_CHAIN" 2>/dev/null || true
  ipt -t nat -D POSTROUTING -s "$AP_NET" -o "$UPLINK_IFACE" -j MASQUERADE 2>/dev/null || true
}

case "${1:-}" in
  up) fw_up ;;
  down) fw_down ;;
  *) echo "usage: $0 up|down" >&2; exit 2 ;;
esac
