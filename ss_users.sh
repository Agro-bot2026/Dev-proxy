#!/bin/bash
# 🕶️ Gestión de usuarios Shadowsocks (Xray) — passwords individuales por cliente
# Uso:
#   ss_users.sh add <password>            → agrega un cliente SS al inbound
#   ss_users.sh remove <password>         → quita un cliente SS del inbound
#   ss_users.sh reload                    → recarga Xray (después de cambios)
#   ss_users.sh list                      → lista los clientes SS
set -e

CONFIG=/usr/local/etc/xray/config.json
SS_METHOD="aes-256-gcm"
ACTION="$1"
VALUE="$2"

add_user() {
    python3 - "$VALUE" "$SS_METHOD" << 'PYEOF'
import json, sys
password = sys.argv[1]
method = sys.argv[2]
cfg = json.load(open('/usr/local/etc/xray/config.json'))
for inbound in cfg['inbounds']:
    if inbound.get('protocol') == 'shadowsocks':
        settings = inbound.setdefault('settings', {})
        # Migrar de password única a clients[] (AEAD con varios usuarios)
        if 'clients' not in settings:
            old_pass = settings.pop('password', None)
            old_method = settings.pop('method', method)
            settings['clients'] = []
            if old_pass:
                settings['clients'].append({'method': old_method, 'password': old_pass, 'email': 'principal'})
        passwords = [c.get('password') for c in settings['clients']]
        if password not in passwords:
            settings['clients'].append({'method': method, 'password': password, 'email': f'ss_{len(settings["clients"])}'})
            json.dump(cfg, open('/usr/local/etc/xray/config.json', 'w'), indent=2)
            print(f"✅ Cliente SS agregado ({len(settings['clients'])} total)")
        else:
            print(f"ℹ️  Password ya existía")
        break
PYEOF
}

remove_user() {
    python3 - "$VALUE" << 'PYEOF'
import json, sys
password = sys.argv[1]
cfg = json.load(open('/usr/local/etc/xray/config.json'))
for inbound in cfg['inbounds']:
    if inbound.get('protocol') == 'shadowsocks':
        settings = inbound.setdefault('settings', {})
        clients = settings.get('clients', [])
        antes = len(clients)
        settings['clients'] = [c for c in clients if c.get('password') != password]
        despues = len(settings['clients'])
        if antes != despues:
            json.dump(cfg, open('/usr/local/etc/xray/config.json', 'w'), indent=2)
            print(f"✅ Cliente SS quitado ({antes} → {despues})")
        else:
            print("ℹ️  Password no encontrada")
        break
PYEOF
}

list_users() {
    python3 << 'PYEOF'
import json
cfg = json.load(open('/usr/local/etc/xray/config.json'))
for inbound in cfg['inbounds']:
    if inbound.get('protocol') == 'shadowsocks':
        settings = inbound.get('settings', {})
        clients = settings.get('clients', [])
        if clients:
            for c in clients:
                print(f"  {c.get('email','?')}: {c.get('password','?')} ({c.get('method','?')})")
        elif settings.get('password'):
            print(f"  principal: {settings.get('password')} ({settings.get('method','?')})")
        break
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
    add)    add_user ;;
    remove) remove_user ;;
    list)   list_users ;;
    reload) reload ;;
    *) echo "Uso: $0 {add|remove|list|reload} [password]"; exit 1 ;;
esac
