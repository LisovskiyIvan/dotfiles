#!/bin/bash

SERVERS=(
)

SINGBOX="sing-box"
CONFIG="/tmp/sing-box-runtime.json"

generate_config() {
  local server="$1" port="$2" uuid="$3" sni="$4" pubkey="$5"
  cat > "$CONFIG" <<EOF
{
  "log": {"level": "warn"},
  "dns": {
    "servers": [{"type": "https", "tag": "dns", "server": "1.1.1.1", "detour": "proxy"}],
    "final": "dns", "strategy": "ipv4_only"
  },
  "inbounds": [{
    "type": "tun", "tag": "tun-in",
    "address": ["172.19.0.1/30"], "mtu": 1400,
    "auto_route": true, "strict_route": true, "stack": "gvisor"
  }],
  "outbounds": [
    {
      "type": "vless", "tag": "proxy",
      "server": "$server", "server_port": $port,
      "uuid": "$uuid", "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true, "server_name": "$sni",
        "utls": {"enabled": true, "fingerprint": "chrome"},
        "reality": {"enabled": true, "public_key": "$pubkey"}
      },
      "packet_encoding": "xudp"
    },
    {"type": "direct", "tag": "direct"},
    {"type": "block", "tag": "block"}
  ],
  "route": {
    "rules": [{"action": "sniff"}, {"protocol": "dns", "action": "hijack-dns"}, {"ip_is_private": true, "outbound": "direct"}],
    "final": "proxy", "auto_detect_interface": true, "default_domain_resolver": "dns"
  }
}
EOF
}

case "$1" in
  on|start)
    idx=${2:-0}
    if [ "$idx" = "list" ]; then
      for i in "${!SERVERS[@]}"; do
        IFS=':' read -r ip port _ _ _ <<< "${SERVERS[$i]}"
        echo "  [$i] $ip:$port"
      done
      exit 0
    fi
    IFS=':' read -r server port uuid sni pubkey <<< "${SERVERS[$idx]}"
    sudo killall sing-box 2>/dev/null
    generate_config "$server" "$port" "$uuid" "$sni" "$pubkey"
    sudo "$SINGBOX" run -c "$CONFIG" &
    echo "VPN: $server:$port"
    ;;
  off|stop)
    sudo killall sing-box 2>/dev/null
    echo "VPN off"
    ;;
  status)
    if pgrep -x sing-box >/dev/null; then
      curl -s --max-time 3 https://api.ipify.org 2>/dev/null && echo " (connected)" || echo "running, no internet"
    else
      echo "off"
    fi
    ;;
  switch)
    vpn on "$2"
    ;;
  *)
    echo "Usage: vpn {on [0|1]|off|status|list}"
    echo "Servers:"
    vpn on list
    ;;
esac
