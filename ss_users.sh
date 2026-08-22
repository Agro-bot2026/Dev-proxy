#!/bin/bash
# 🕶️ Gestión de Shadowsocks (Xray) — PASSWORD ÚNICA (SS clásico aes-256-gcm)
# NOTA: SS clásico usa UNA password para todos (como Psiphon). Para expirar
#       a un cliente se REGENERA la password (invalida todos los links).
# Uso:
#   ss_users.sh show     → muestra la password actual + link
#   ss_users.sh new      → genera password nueva (kill-switch) + recarga Xray
#   ss_users.sh set <pw> → fija password específica + recarga Xray
set -e

CONFIG=/usr/local/etc/xray/config.json
PWFILE=/etc/ctmanager/config/ss_password
METHOD="aes-256-gcm"
ACTION="$1"
VALUE="$2"

get_pass() {
    python3 - << 'PYEOF'
import json
cfg = json.load(open('/usr/local/etc/xray/config.json'))
for i in cfg['inbounds']:
    if i.get('protocol') == 'shadowsocks':
        s = i.get('settings', {})
        print(s.get('password') or s.get('clients', [{}])[0].get('password', ''))
        break
PYEOF
}

set_pass() {
    local PW="$1"
    python3 - "$PW" "$METHOD" << 'PYEOF'
import json, sys
pw, method = sys.argv[1], sys.argv[2]
cfg = json.load(open('/usr/local/etc/xray/config.json'))
for i in cfg['inbounds']:
    if i.get('protocol') == 'shadowsocks':
        # SS clásico: password única a nivel settings (clients[] rompe aes-256-gcm clásico)
        i['settings'] = {"method": method, "password": pw, "network": "tcp,udp"}
        json.dump(cfg, open('/usr/local/etc/xray/config.json', 'w'), indent=2)
        print(f"Password SS actualizada: {pw}")
        break
PYEOF
    echo "$PW" > "$PWFILE"
    chmod 600 "$PWFILE" 2>/dev/null || true
    systemctl restart xray
    sleep 1
    if systemctl is-active xray > /dev/null; then
        echo "✅ Xray recargado"
    else
        echo "❌ Xray falló"
        exit 1
    fi
}

show_link() {
    local PW IP B64 PORT
    PW="$(get_pass)"
    IP="$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
    PORT="$(python3 -c "import json; c=json.load(open('/etc/ctmanager/websocket/config.json')); print(c.get('ss_port', 8388))" 2>/dev/null)"
    PORT="${PORT:-8388}"
    B64=$(printf "%s:%s" "$METHOD" "$PW" | base64 -w0 2>/dev/null || printf "%s:%s" "$METHOD" "$PW" | base64)
    echo "ss://${B64}@${IP}:${PORT}#Ghost-SS"
    echo "  (server: $IP:$PORT  password: $PW  metodo: $METHOD)"
}

case "$ACTION" in
    show) show_link ;;
    new)
        NEWPW="ss$(openssl rand -hex 8 2>/dev/null || echo $(date +%s))"
        set_pass "$NEWPW"
        echo ""
        show_link
        ;;
    set)
        [ -z "$VALUE" ] && { echo "Uso: $0 set <password>"; exit 1; }
        set_pass "$VALUE"
        echo ""
        show_link
        ;;
    *) echo "Uso: $0 {show|new|set}"; exit 1 ;;
esac
