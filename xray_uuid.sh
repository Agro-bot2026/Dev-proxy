#!/bin/bash
# 🦇 Gestión de UUIDs de Xray (V2Ray con expiración por usuario)
# Uso:
#   xray_add_uuid.sh <UUID>          → agrega el UUID al inbound
#   xray_remove_uuid.sh <UUID>       → quita el UUID del inbound
#   xray_reload.sh                   → recarga Xray (después de cambios)
# Los UUIDs viven en /usr/local/etc/xray/config.json (inbound vless 8443)
set -e

CONFIG=/usr/local/etc/xray/config.json
ACTION="$1"
UUID="$2"

add_uuid() {
    python3 - "$UUID" << 'PYEOF'
import json, sys
uuid = sys.argv[1]
cfg = json.load(open('/usr/local/etc/xray/config.json'))
clients = cfg['inbounds'][0]['settings']['clients']
ids = [c['id'] for c in clients]
if uuid not in ids:
    clients.append({'id': uuid, 'flow': ''})
    json.dump(cfg, open('/usr/local/etc/xray/config.json', 'w'), indent=2)
    print(f"✅ UUID {uuid} agregado ({len(clients)} total)")
else:
    print(f"ℹ️ UUID {uuid} ya existía")
PYEOF
}

remove_uuid() {
    python3 - "$UUID" << 'PYEOF'
import json, sys
uuid = sys.argv[1]
cfg = json.load(open('/usr/local/etc/xray/config.json'))
clients = cfg['inbounds'][0]['settings']['clients']
antes = len(clients)
cfg['inbounds'][0]['settings']['clients'] = [c for c in clients if c['id'] != uuid]
json.dump(cfg, open('/usr/local/etc/xray/config.json', 'w'), indent=2)
print(f"✅ UUID {uuid} quitado ({antes} → {len(cfg['inbounds'][0]['settings']['clients'])} total)")
PYEOF
}

reload() {
    systemctl restart xray
    sleep 1
    if systemctl is-active xray > /dev/null; then
        echo "✅ Xray recargado"
    else
        echo "❌ Xray falló al reiniciar"
        exit 1
    fi
}

case "$ACTION" in
    add)    add_uuid ;;
    remove) remove_uuid ;;
    reload) reload ;;
    *) echo "Uso: $0 {add|remove|reload} [UUID]"; exit 1 ;;
esac