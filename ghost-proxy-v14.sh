#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  🦇 GHOST PROXY v14 — Instalador Multi-Protocolo (estilo ePro)
#  Proxy :80 con detección automática:
#  SSH | Psiphon | V2Ray (RAW+TLS) | OpenVPN | WireGuard
#
#  USO:  bash ghost-proxy-v14.sh
#        (descarga el proxy.py automáticamente)
#  ═══════════════════════════════════════════════════════════════
set -euo pipefail

APP_NAME="Ghost Proxy v14 — Multi-Protocolo"
VERSION="14.0"

# ─── Rutas ───
INSTALL_DIR="/etc/ctmanager/websocket"
CONFIG_FILE="${INSTALL_DIR}/config.json"
SERVICE_NAME="pymanager"
DOMAIN_FILE="${INSTALL_DIR}/dominio"

# ─── De dónde baja el proxy.py (GitHub = fuente de verdad, VPS = fallback) ───
PROXY_URL="https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/proxy.py"
PROXY_FALLBACK="https://configs.charly-tricks.dev/configs/proxy.py"
BADVPN_URL="https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/badvpn-udpgw"
BADVPN_FALLBACK="https://configs.charly-tricks.dev/configs/badvpn-udpgw"

BANNER_COLOR='\033[1;36m'
GREEN='\033[1;32m'
BOLD='\033[1m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

ts(){ date +"%Y%m%d%H%M%S"; }
die(){ echo -e "${RED}❌ $*${NC}"; exit 1; }
ok(){ echo -e "${GREEN}✅ $*${NC}"; }
warn(){ echo -e "${YELLOW}⚠️  $*${NC}"; }
press_enter(){ echo; read -r -p "Presioná ENTER para volver..." _; }
need_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Ejecutá como root: sudo bash $0"; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

banner(){
  clear
  echo -e "${BANNER_COLOR}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║   ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗              ║"
  echo "║  ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝              ║"
  echo "║  ██║  ███╗███████║██║   ██║███████╗   ██║                 ║"
  echo "║  ██║   ██║██╔══██║██║   ██║╚════██║   ██║                 ║"
  echo "║  ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║                 ║"
  echo "║   ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝                 ║"
  echo "║  ┌────────────────────────────────────────────────────┐    ║"
  echo "║  │  $APP_NAME                                    │    ║"
  echo "║  │  SSH · Psiphon · V2Ray · OpenVPN · WireGuard      │    ║"
  echo "║  └────────────────────────────────────────────────────┘    ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ─── Detectar sistema (ADMRufu/VPS-MX/SSHPLUS/etc) ───
detect_system(){
  if [[ -d /etc/ADMRufu ]]; then echo "ADMRufu"; 
  elif [[ -d /etc/VPS-MX ]]; then echo "VPS-MX";
  elif [[ -d /etc/SSHPlus ]]; then echo "SSHPLUS";
  elif [[ -d /etc/LATAM ]]; then echo "LATAM";
  elif [[ -d /etc/VPS-AGN ]]; then echo "VPS-AGN";
  else echo "generico"; fi
}

# ─── Descargar proxy.py ───
download_proxy(){
  mkdir -p "$INSTALL_DIR"
  local SRC=""
  # 1) Si hay un proxy.py local (mismo dir / /root), usarlo
  for cand in "$(dirname "$0")/proxy.py" /root/proxy.py; do
    if [[ -f "$cand" ]]; then SRC="$cand"; break; fi
  done
  # 2) Si no, descargar (curl → wget → python3 → /dev/tcp)
  if [[ -z "$SRC" ]]; then
    warn "No hay proxy.py local — descargando..."
    for url in "$PROXY_URL" "$PROXY_FALLBACK"; do
      if download_file "$url" "$INSTALL_DIR/proxy.py"; then
        SRC="$INSTALL_DIR/proxy.py"
        ok "Descargado de $url"
        break
      fi
    done
  fi
  if [[ -z "$SRC" ]]; then
    die "No pude obtener proxy.py. Descargalo manualmente a $INSTALL_DIR/proxy.py"
  fi
  # Si el proxy.py ya está en el destino (descarga directa), no copiar sobre sí mismo
  if [[ "$SRC" != "$INSTALL_DIR/proxy.py" ]]; then
    cp -f "$SRC" "$INSTALL_DIR/proxy.py"
  fi
  chmod 755 "$INSTALL_DIR/proxy.py"
  # Verificar que es python válido
  head -1 "$INSTALL_DIR/proxy.py" | grep -q python || warn "El archivo no parece ser python (revisalo)"
  ok "proxy.py instalado en $INSTALL_DIR ($(wc -l < "$INSTALL_DIR/proxy.py") líneas)"
}

# ─── Config por defecto ───
write_config(){
  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" <<EOF
{
  "ws_port": 80,
  "wss_port": 443,
  "target_host": "127.0.0.1",
  "target_port": 22,
  "payload": "101",
  "enable_ws": true,
  "enable_wss": false,
  "max_connections_per_user": 50,
  "ovpn_host": "127.0.0.1",
  "ovpn_port": 1194,
  "v2ray_host": "127.0.0.1",
  "v2ray_port": 8443,
  "psiphon_host": "127.0.0.1",
  "psiphon_port": 2223,
  "wg_host": "127.0.0.1",
  "wg_port": 51821,
  "quota_gb": 200,
  "quota_dias": 30,
  "sshgo_host": "127.0.0.1",
  "sshgo_port": 2200,
  "brook_host": "127.0.0.1",
  "brook_port": 18999
}
EOF
    ok "Config creado: $CONFIG_FILE"
  else
    warn "Config ya existe (no se pisa): $CONFIG_FILE"
  fi
}

# ─── DETECCIÓN AUTOMÁTICA de servicios (SSH/V2Ray/Psiphon/OVPN/WG) ───
# Escanea los puertos LISTEN del VPS y mapea los destinos SOLO
detect_services(){
  echo "🔎 Detectando servicios del VPS..."
  local ssh_port=22 v2ray_port=8443 psiphon_port=2223 ovpn_port=1194 wg_port=51821
  local found_ssh=0 found_v2ray=0 found_psiphon=0 found_ovpn=0 found_wg=0

  # Escanear puertos LISTEN con su proceso (ss o netstat)
  local listeners=""
  if has_cmd ss; then
    listeners="$(ss -tlnp 2>/dev/null || true)"
  elif has_cmd netstat; then
    listeners="$(netstat -tlnp 2>/dev/null || true)"
  fi

  # 1) SSH (sshd o dropbear)
  local ssh_pid
  ssh_pid="$(pgrep -f 'sshd|dropbear' 2>/dev/null | head -1 || true)"
  if [[ -n "$ssh_pid" ]]; then
    ssh_port="$(echo "$listeners" | grep -E 'sshd|dropbear' | grep -oE ':[0-9]+' | head -1 | tr -d ':')" || true
    [[ -z "$ssh_port" ]] && ssh_port=22
    found_ssh=1
  else
    # sshd puede estar con otro nombre — probar puerto 22 directo
    echo "$listeners" | grep -qE ':22\s' && { ssh_port=22; found_ssh=1; }
  fi

  # 2) V2Ray / Xray
  local v2ray_pid
  v2ray_pid="$(pgrep -f 'xray|v2ray' 2>/dev/null | head -1 || true)"
  if [[ -n "$v2ray_pid" ]]; then
    v2ray_port="$(echo "$listeners" | grep -E 'xray|v2ray' | grep -oE ':[0-9]+' | head -1 | tr -d ':')" || true
    [[ -z "$v2ray_port" ]] && v2ray_port=8443
    found_v2ray=1
  elif echo "$listeners" | grep -qE ':8443\s'; then
    # Puerto 8443 ocupado por cualquier proceso → asumir V2Ray
    v2ray_port=8443
    found_v2ray=1
  fi

  # 3) Psiphon
  local psiphon_pid
  psiphon_pid="$(pgrep -f 'psiphon' 2>/dev/null | head -1 || true)"
  if [[ -n "$psiphon_pid" ]]; then
    psiphon_port="$(echo "$listeners" | grep -E 'psiphon' | grep -oE ':[0-9]+' | head -1 | tr -d ':')" || true
    [[ -z "$psiphon_port" ]] && psiphon_port=2223
    found_psiphon=1
  elif echo "$listeners" | grep -qE ':2223\s'; then
    # Puerto 2223 ocupado → asumir Psiphon
    psiphon_port=2223
    found_psiphon=1
  fi

  # 4) OpenVPN
  local ovpn_pid
  ovpn_pid="$(pgrep -f 'openvpn' 2>/dev/null | head -1 || true)"
  if [[ -n "$ovpn_pid" ]]; then
    ovpn_port="$(echo "$listeners" | grep -E 'openvpn' | grep -oE ':[0-9]+' | head -1 | tr -d ':')" || true
    [[ -z "$ovpn_port" ]] && ovpn_port=1194
    found_ovpn=1
  elif echo "$listeners" | grep -qE ':1194\s'; then
    # Puerto 1194 ocupado → asumir OpenVPN
    ovpn_port=1194
    found_ovpn=1
  fi

  # 5) WireGuard (interfaz wg* o puerto 51821)
  if ip link show 2>/dev/null | grep -qE '^[0-9]+: wg'; then
    wg_port=51821
    found_wg=1
  fi

  # IP pública del VPS (para los hosts de los servicios que bindean a la IP, ej: psiphon)
  local IP_PUB
  IP_PUB="$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')"
  [[ -z "$IP_PUB" ]] && IP_PUB="127.0.0.1"
  # El psiphon-server bindea a la IP pública (no a 127.0.0.1) → usar la IP
  local psiphon_host="$IP_PUB"
  local ssh_host="127.0.0.1"

  # Escribir config.json con los puertos DETECTADOS
  cat > "$CONFIG_FILE" <<EOF
{
  "ws_port": 80,
  "wss_port": 443,
  "target_host": "127.0.0.1",
  "target_port": ${ssh_port},
  "payload": "101",
  "enable_ws": true,
  "enable_wss": false,
  "max_connections_per_user": 50,
  "ovpn_host": "127.0.0.1",
  "ovpn_port": ${ovpn_port},
  "v2ray_host": "127.0.0.1",
  "v2ray_port": ${v2ray_port},
  "psiphon_host": "${psiphon_host}",
  "psiphon_port": ${psiphon_port},
  "wg_host": "127.0.0.1",
  "wg_port": ${wg_port}
}
EOF
  chmod 644 "$CONFIG_FILE"

  # Mostrar qué se detectó (solo lo encontrado, sin ruido)
  echo "  🔎 Servicios detectados:"
  local detectados=0
  [[ $found_ssh -eq 1 ]]      && { echo "    ✅ SSH → ${ssh_port}"; detectados=1; }
  [[ $found_v2ray -eq 1 ]]    && { echo "    ✅ V2Ray → ${v2ray_port}"; detectados=1; }
  [[ $found_psiphon -eq 1 ]]  && { echo "    ✅ Psiphon → ${psiphon_port}"; detectados=1; }
  [[ $found_ovpn -eq 1 ]]     && { echo "    ✅ OpenVPN → ${ovpn_port}"; detectados=1; }
  [[ $found_wg -eq 1 ]]       && { echo "    ✅ WireGuard → ${wg_port}"; detectados=1; }
  [[ $detectados -eq 0 ]]     && echo "    ⚠️  (ninguno — se usan los puertos default)"
  echo
}

# ─── Servicio systemd ───
write_service(){
  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl no disponible en este sistema (¿contenedor minimalista?)"
    warn "En un VPS normal con systemd esto no pasa. Creando servicio igual..."
  fi
  mkdir -p /etc/systemd/system
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Ghost Proxy WS (multi-protocolo :80)
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/python3 ${INSTALL_DIR}/proxy.py
Restart=on-failure
RestartSec=3
LimitNOFILE=65535
LimitNPROC=65535

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
}

# ─── Instalar ───
install_proxy(){
  need_root
  download_proxy
  write_config
  write_service
  # Intentar arrancar (si el :80 está ocupado, avisar)
  systemctl restart "$SERVICE_NAME" 2>/dev/null || true
  sleep 1
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "Servicio $SERVICE_NAME ACTIVO"
    ss -tlnp 2>/dev/null | grep -E ":80 " | head -1 || true
  else
    warn "El servicio no arrancó. Probablemente el :80 está ocupado."
    warn "Mirá: journalctl -u $SERVICE_NAME -n 30"
    warn "O usá la opción [2] Liberar puertos / [8] Editar config (cambiar a 443)"
  fi
  press_enter
}

# ─── Liberar puertos ───
free_ports(){
  need_root
  for svc in apache2 nginx httpd lighttpd caddy haproxy; do
    systemctl is-active --quiet "$svc" 2>/dev/null && {
      warn "Deteniendo $svc (ocupa 80/443)"
      systemctl stop "$svc" 2>/dev/null || true
      systemctl disable "$svc" 2>/dev/null || true
    }
  done
  # Si hay un proxy de ADMRufu/VPS-MX ocupando el 80, avisar (no matarlo sin permiso)
  local ocupante
  ocupante="$(ss -tlnp 2>/dev/null | grep ':80 ' | awk '{print $NF}' | head -1 || true)"
  if [[ -n "$ocupante" && "$ocupante" != *"python3"* && "$ocupante" != *"pymanager"* ]]; then
    warn "Puerto 80 ocupado por: $ocupante"
    warn "Si es el proxy de ADMRufu/VPS-MX, desactivalo desde su menú"
    warn "o editalo: nano $CONFIG_FILE → ws_port: 443"
  fi
  systemctl restart "$SERVICE_NAME" 2>/dev/null || true
  ok "Puertos 80/443 liberados (web servers)"
  press_enter
}

# ─── BadVPN UDPGW ───
install_badvpn(){
  need_root
  local BAD_BIN="/bin/badvpn-udpgw"
  local BAD_PORT="${1:-7300}"
  if has_cmd badvpn-udpgw || [[ -f "$BAD_BIN" ]]; then
    warn "badvpn-udpgw ya existe"
  else
    warn "Descargando badvpn-udpgw..."
    curl -fsSL --max-time 30 "https://raw.githubusercontent.com/Agro-bot2026/CloudRun/main/badvpn-udpgw" -o "$BAD_BIN" 2>/dev/null && chmod 755 "$BAD_BIN" \
      || warn "No pude descargar badvpn. Instalalo manual en /bin/badvpn-udpgw"
  fi
  if [[ -f "$BAD_BIN" ]]; then
    mkdir -p /etc/systemd/system
  cat > /etc/systemd/system/badvpn.service <<EOF
[Unit]
Description=BadVPN UDPGW (puerto ${BAD_PORT})
After=network.target

[Service]
Type=simple
ExecStart=/bin/badvpn-udpgw --listen-addr 127.0.0.1:${BAD_PORT} --max-clients 1000 --max-connections-for-client 5
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable badvpn >/dev/null 2>&1 || true
    systemctl restart badvpn
    ok "BadVPN activo en 127.0.0.1:${BAD_PORT}"
  fi
  press_enter
}

# ─── Estado ───
show_status(){
  # Detectar la distro (simple, sin funciones externas)
  local DISTRO
  DISTRO="$(grep -E '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | head -c 15)" || true
  [[ -z "$DISTRO" ]] && DISTRO="linux"
  echo
  echo "╔══════════════════════════════════════════════╗"
  echo "║  📊 ESTADO — Sistema: ${DISTRO}          ║"
  echo "╚══════════════════════════════════════════════╝"
  local st
  st="$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo inactive)"
  echo -e "  Proxy ${SERVICE_NAME}: ${GREEN}${st}${NC}"
  st="$(systemctl is-active badvpn 2>/dev/null || echo inactive)"
  echo -e "  BadVPN: ${GREEN}${st}${NC}"
  st="$(systemctl is-active psiphon 2>/dev/null || echo inactive)"
  echo -e "  Psiphon: ${GREEN}${st}${NC}"
  st="$(systemctl is-active xray 2>/dev/null || echo inactive)"
  echo -e "  Xray V2Ray: ${GREEN}${st}${NC}"
  st="$(systemctl is-active openvpn@server 2>/dev/null || echo inactive)"
  echo -e "  OpenVPN: ${GREEN}${st}${NC}"
  st="$(systemctl is-active wg-quick@wg0 2>/dev/null || echo inactive)"
  echo -e "  WireGuard: ${GREEN}${st}${NC}"
  if [[ -f "$CONFIG_FILE" ]]; then
    echo "  Config: $CONFIG_FILE"
  fi
  echo
}

# ─── Editar config ───
edit_config(){
  need_root
  if [[ -f "$CONFIG_FILE" ]]; then
    nano "$CONFIG_FILE" 2>/dev/null || vi "$CONFIG_FILE"
    systemctl restart "$SERVICE_NAME" 2>/dev/null || true
    ok "Config aplicada y servicio reiniciado"
  else
    warn "No existe $CONFIG_FILE"
  fi
  press_enter
}

# ─── Firewall ───
firewall_menu(){
  need_root
  if ! has_cmd ufw; then
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y ufw >/dev/null 2>&1 || die "No pude instalar ufw"
  fi
  echo "Firewall (UFW):"
  echo "  1) Permitir SSH(22) + habilitar UFW"
  echo "  2) Permitir TODOS los puertos LISTEN"
  echo "  3) Ver estado"
  echo "  4) Deshabilitar UFW"
  read -r -p "Opción: " f
  case "$f" in
    1) ufw allow 22/tcp >/dev/null 2>&1 || true; ufw --force enable >/dev/null 2>&1 || true; ok "UFW activo con SSH" ;;
    2)
      ufw allow 22/tcp >/dev/null 2>&1 || true
      local ports
      ports="$(ss -lnt 2>/dev/null | awk '$4 ~ /^0\.0\.0\.0:/ || $4 ~ /^:::/ {print $4}' | sed -E 's/.*:([0-9]+)$/\1/' | sort -n | uniq)"
      for p in $ports; do ufw allow "${p}/tcp" >/dev/null 2>&1 || true; done
      ufw --force enable >/dev/null 2>&1 || true
      ok "UFW activo con todos los puertos LISTEN"
      ;;
    3) ufw status verbose || true ;;
    4) ufw disable || true ;;
    *) warn "Opción inválida" ;;
  esac
  press_enter
}

# ─── Logs ───
do_logs(){
  journalctl -u "$SERVICE_NAME" --no-pager -n 60 || true
  press_enter
}

# ─── Desinstalar ───
do_uninstall(){
  need_root
  systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl disable "$SERVICE_NAME" 2>/dev/null || true
  systemctl stop badvpn 2>/dev/null || true
  systemctl disable badvpn 2>/dev/null || true
  rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
  rm -f "/etc/systemd/system/badvpn.service"
  systemctl daemon-reload
  ok "Servicios eliminados ($SERVICE_NAME, badvpn)"
  press_enter
}

# ─── SSL 443 → proxy WebSocket (método TLS, igual que en este VPS) ───
# En producción el TLS 443 lo termina CloudRun y reenvía DESEMPAQUETADO al :80
# del proxy. En un VPS propio el equivalente es stunnel: termina TLS en :443
# y reenvía al proxy WS :80 (el pymanager). Sin Caddy.
install_tls_443(){
  need_root
  local dom
  dom="$(cat "$DOMAIN_FILE" 2>/dev/null | tr -d ' ' || true)"
  if [[ -z "$dom" ]]; then
    warn "Sin dominio guardado — el SSL 443 necesita un dominio (no IP)"
    warn "Guardalo con: echo 'tu.dominio.com' > $DOMAIN_FILE"
    return 1
  fi
  echo ""
  echo -e "${CYAN}  🔒 Instalando SSL 443 → proxy WebSocket (método TLS, stunnel)...${NC}"
  # 1) stunnel
  if ! has_cmd stunnel4 && ! has_cmd stunnel; then
    apt-get install -y -qq stunnel4 >/dev/null 2>&1 || true
  fi
  local STUNNEL_BIN
  STUNNEL_BIN="$(command -v stunnel4 2>/dev/null || command -v stunnel 2>/dev/null || echo '')"
  if [[ -z "$STUNNEL_BIN" ]]; then
    warn "No pude instalar stunnel — el SSL 443 queda pendiente (podés instalarlo a mano)"
    return 1
  fi
  # 2) Certificado autofirmado para el dominio (método TLS usa allow_insecure)
  mkdir -p /etc/stunnel
  if [[ ! -f /etc/stunnel/eprohc.pem ]]; then
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
      -keyout /etc/stunnel/eprohc.pem -out /etc/stunnel/eprohc.pem \
      -subj "/CN=${dom}" >/dev/null 2>&1 || true
    chmod 600 /etc/stunnel/eprohc.pem
    ok "Certificado SSL creado para ${dom}"
  fi
  # 3) Config: 443 → 127.0.0.1:80 (el proxy WS) — bind IPv4 explícito (0.0.0.0)
  #    foreground=yes es GLOBAL (va al inicio, NO dentro del servicio) y es
  #    OBLIGATORIO bajo systemd Type=simple (si no, daemoniza y systemd lo ve
  #    'terminado' → reinicia en loop infinito)
  cat > /etc/stunnel/stunnel.conf <<EOF
foreground = yes

[eprohc-tls]
accept = 0.0.0.0:443
connect = 127.0.0.1:80
cert = /etc/stunnel/eprohc.pem
EOF
  # 3b) Liberar el 443 pase lo que pase: matar cualquier proceso que lo ocupe
  local ocupante_443
  ocupante_443="$(ss -tlnp 2>/dev/null | grep ':443 ' | sed -E 's/.*users:\(\(\"([^\"]+)\".*/\1/' | head -1 || true)"
  if [[ -n "$ocupante_443" ]]; then
    warn "Puerto 443 ocupado por: $ocupante_443 — liberándolo para stunnel"
  fi
  # Matar procesos conocidos que puedan ocupar el 443 (y el puerto mismo)
  systemctl stop caddy 2>/dev/null || true
  systemctl disable caddy 2>/dev/null || true
  systemctl stop nginx 2>/dev/null || true
  systemctl disable nginx 2>/dev/null || true
  systemctl stop apache2 2>/dev/null || true
  systemctl disable apache2 2>/dev/null || true
  # ⚠️ El paquete stunnel4 trae su propio servicio que bindea el 443 con la config:
  # hay que apagarlo o el stunnel-epro nuevo choca (Address already in use)
  systemctl stop stunnel4 2>/dev/null || true
  systemctl disable stunnel4 2>/dev/null || true
  pkill -f 'caddy run' 2>/dev/null || true
  pkill -f '/usr/bin/caddy' 2>/dev/null || true
  pkill -f stunnel4 2>/dev/null || true
  pkill -f 'stunnel' 2>/dev/null || true
  # Si el propio proxy bindea el 443 (enable_wss), sacarlo de ahí
  if command -v python3 >/dev/null 2>&1 && grep -q 'enable_wss.*true' "$CONFIG_FILE" 2>/dev/null; then
    warn "El proxy bindea el 443 (enable_wss) — lo apago para que stunnel use el puerto"
    sed -i 's/"enable_wss": true/"enable_wss": false/' "$CONFIG_FILE" 2>/dev/null || true
    systemctl restart "$SERVICE_NAME" 2>/dev/null || true
  fi
  sleep 1
  # 4) Servicio
  if has_cmd systemctl; then
    cat > /etc/systemd/system/stunnel-epro.service <<'EOF'
[Unit]
Description=SSL 443 → proxy WebSocket (método TLS)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/stunnel4 /etc/stunnel/stunnel.conf
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    # stunnel4 es /usr/bin/stunnel4 en Debian/Ubuntu; ajustar si es otro path
    sed -i "s|/usr/bin/stunnel4|$(command -v stunnel4 2>/dev/null || echo /usr/bin/stunnel4)|" /etc/systemd/system/stunnel-epro.service
    systemctl daemon-reload
    systemctl enable stunnel-epro >/dev/null 2>&1 || true
    systemctl restart stunnel-epro 2>/dev/null || true
    sleep 2
    if systemctl is-active --quiet stunnel-epro; then
      ok "SSL 443 ACTIVO — ${dom}:443 → proxy WS :80 (método TLS)"
    else
      warn "stunnel no arrancó — mirá: journalctl -u stunnel-epro -n 20"
    fi
  else
    # Sin systemd: correr en background
    pkill -f "stunnel.*eprohc" 2>/dev/null || true
    "$STUNNEL_BIN" /etc/stunnel/stunnel.conf 2>/dev/null &
    ok "SSL 443 ACTIVO — ${dom}:443 → proxy WS :80 (método TLS)"
  fi
  # 5) Abrir 443 en el firewall
  if has_cmd ufw; then ufw allow 443/tcp >/dev/null 2>&1 || true; fi
  if has_cmd firewall-cmd; then firewall-cmd --permanent --add-port=443/tcp >/dev/null 2>&1 || true; firewall-cmd --reload >/dev/null 2>&1 || true; fi
  echo ""
}

# ─── Abrir TODOS los puertos del stack en el firewall (ufw/firewalld/iptables) ───
open_all_ports(){
  need_root
  echo ""
  echo -e "${CYAN}  🔓 Abriendo puertos en el firewall...${NC}"
  # Puertos del stack: 80 (proxy), 22 (SSH), 2223 (Psiphon), 8443 (Xray),
  # 1194 (OpenVPN), 51820 (WG), 7300 (BadVPN UDP), 20128 (9Router AI)
  local puertos_tcp="80 22 2223 8443 1194 51820 20128"
  local puertos_udp="80 2223 8443 1194 51820 7300"

  if has_cmd ufw; then
    # UFW (Debian/Ubuntu)
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw 2>/dev/null || true
    for p in $puertos_tcp; do ufw allow "${p}/tcp" >/dev/null 2>&1 || true; done
    for p in $puertos_udp; do ufw allow "${p}/udp" >/dev/null 2>&1 || true; done
    # Si UFW está inactivo, no forzarlo (puede cortar la SSH del usuario si no tiene el 22)
    if ufw status 2>/dev/null | grep -q "Status: active"; then
      ok "UFW: puertos abiertos (TCP+UDP)"
    else
      ok "Puertos agregados a UFW (está inactivo — sin riesgo)"
    fi
  elif has_cmd firewall-cmd; then
    # firewalld (Rocky/CentOS/Alma)
    systemctl is-active --quiet firewalld 2>/dev/null && {
      for p in $puertos_tcp; do firewall-cmd --permanent --add-port="${p}/tcp" >/dev/null 2>&1 || true; done
      for p in $puertos_udp; do firewall-cmd --permanent --add-port="${p}/udp" >/dev/null 2>&1 || true; done
      firewall-cmd --permanent --add-masquerade >/dev/null 2>&1 || true
      firewall-cmd --reload >/dev/null 2>&1 || true
      ok "firewalld: puertos abiertos (TCP+UDP) + masquerade"
    } || ok "firewalld inactivo (no hizo falta)"
  elif has_cmd iptables; then
    # iptables puro (sin firewall manager)
    for p in $puertos_tcp; do iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null || true; done
    for p in $puertos_udp; do iptables -C INPUT -p udp --dport "$p" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$p" -j ACCEPT 2>/dev/null || true; done
    ok "iptables: puertos abiertos (TCP+UDP)"
  else
    warn "Sin firewall detectado (ufw/firewalld/iptables) — puertos ya están abiertos"
  fi
  echo ""
}

# ─── LIMPIEZA TOTAL (borra TODO lo anterior antes de instalar) ───
clean_all(){
  need_root
  echo -e "${YELLOW}🧹 LIMPIEZA TOTAL — borrando instalaciones previas...${NC}"
  # 1) Servicios
  systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl disable "$SERVICE_NAME" 2>/dev/null || true
  systemctl stop badvpn 2>/dev/null || true
  systemctl disable badvpn 2>/dev/null || true
  rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
  rm -f "/etc/systemd/system/badvpn.service"
  systemctl daemon-reload
  # 2) Archivos del proxy
  rm -rf "$INSTALL_DIR"
  # 2b) SSL viejo (Caddy de versiones anteriores del instalador) + stunnel
  systemctl stop caddy 2>/dev/null || true
  systemctl disable caddy 2>/dev/null || true
  systemctl stop stunnel-epro 2>/dev/null || true
  systemctl disable stunnel-epro 2>/dev/null || true
  rm -f /etc/systemd/system/stunnel-epro.service
  # 3) Ghost Manager
  rm -f /usr/local/bin/ghost-manager
  # 4) Binarios badvpn
  rm -f /bin/badvpn-udpgw
  echo -e "${GREEN}✅ Todo limpio — listo para instalar desde cero${NC}"
}

# ─── Dominio enlazado al VPS (para los links de usuarios) ───
get_domain(){
  if [[ -f "$DOMAIN_FILE" ]]; then
    cat "$DOMAIN_FILE"
  else
    # Sin dominio guardado → usar la IP pública
    curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}'
  fi
}

set_domain(){
  need_root
  echo ""
  echo -e "${BOLD}${YELLOW}  🌐 DOMINIO DEL VPS${NC}"
  echo -e "${CYAN}  ────────────────${NC}"
  echo -e "  El dominio que apunta a este VPS (ej: pinche.chauinforme.online)."
  echo -e "  Se usa para generar los links de usuarios (V2Ray, SSH, etc.)."
  local actual
  actual="$(get_domain)"
  echo ""
  read -p "  🌐 Dominio [actual: $actual]: " dom
  dom="${dom:-$actual}"
  # Limpiar espacios y http://
  dom="$(echo "$dom" | tr -d ' ' | sed 's|https\?://||')"
  if [[ -n "$dom" ]]; then
    mkdir -p "$INSTALL_DIR"
    echo "$dom" > "$DOMAIN_FILE"
    ok "Dominio guardado: $dom"
  else
    warn "Dominio vacío — se sigue usando la IP"
  fi
  press_enter
}

# ─── Detectar gestor de paquetes (multi-distro) ───
detect_pkg(){
  if has_cmd apt-get; then echo "apt"
  elif has_cmd dnf; then echo "dnf"
  elif has_cmd yum; then echo "yum"
  elif has_cmd apk; then echo "apk"
  elif has_cmd zypper; then echo "zypper"
  elif has_cmd pacman; then echo "pacman"
  else echo "none"; fi
}

pkg_install(){
  local pkgs=("$@")
  local pkgm
  pkgm="$(detect_pkg)"
  case "$pkgm" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq >/dev/null 2>&1 || true
      apt-get install -y -qq "${pkgs[@]}" >/dev/null 2>&1 || true
      ;;
    dnf) dnf install -y -q "${pkgs[@]}" >/dev/null 2>&1 || true ;;
    yum) yum install -y -q "${pkgs[@]}" >/dev/null 2>&1 || true ;;
    apk) apk add --no-cache "${pkgs[@]}" >/dev/null 2>&1 || true ;;
    zypper) zypper install -y "${pkgs[@]}" >/dev/null 2>&1 || true ;;
    pacman) pacman -S --noconfirm "${pkgs[@]}" >/dev/null 2>&1 || true ;;
    *) warn "Gestor de paquetes no detectado"; return 1 ;;
  esac
}

# ─── Descargar archivo (curl → wget → python3 → bash /dev/tcp) ───
download_file(){
  local url="$1" out="$2"
  if has_cmd curl; then curl -fsSL --max-time 30 "$url" -o "$out" 2>/dev/null && return 0; fi
  if has_cmd wget; then wget -q --timeout=30 -O "$out" "$url" 2>/dev/null && return 0; fi
  if has_cmd python3; then
    python3 -c "import urllib.request,sys; urllib.request.urlretrieve('$url','$out')" 2>/dev/null && return 0
  fi
  # Último recurso: /dev/tcp de bash
  if [[ -n "$(echo > /dev/tcp/configs.charly-tricks.dev/443 2>/dev/null && echo ok)" ]]; then
    exec 3<>/dev/tcp/configs.charly-tricks.dev/443
    echo -e "GET /configs/proxy.py HTTP/1.1\r\nHost: configs.charly-tricks.dev\r\nConnection: close\r\n\r\n" >&3
    cat <&3 > "$out" 2>/dev/null
    exec 3<&- 3>&-
    # Quitar headers HTTP
    sed -i '1,/^\r$/d' "$out" 2>/dev/null || true
    return 0
  fi
  return 1
}

# ─── Instalación de dependencias (TODO solo, multi-distro) ───
ensure_deps_auto(){
  local faltan=()
  # Si no hay ni curl ni wget ni python3, instalar curl con el gestor nativo
  if ! has_cmd curl && ! has_cmd wget && ! has_cmd python3; then
    warn "Sin curl/wget/python3 — instalando con el gestor nativo..."
    pkg_install curl python3 || true
  fi
  has_cmd curl || has_cmd wget || has_cmd python3 || faltan+=(curl)
  has_cmd python3 || faltan+=(python3)
  has_cmd systemctl || faltan+=(systemd systemd-sysv)
  has_cmd ss || has_cmd netstat || faltan+=(iproute2 net-tools)
  has_cmd pgrep || faltan+=(procps)
  has_cmd ip || faltan+=(iproute2)
  has_cmd sqlite3 || faltan+=(sqlite3)  # ghost-manager y ghost-panel la usan para las bases de usuarios
  [[ ${#faltan[@]} -eq 0 ]] && { ok "Dependencias OK (curl/wget, python3, systemd)"; return 0; }

  warn "Faltan: ${faltan[*]} — instalando automáticamente..."
  pkg_install "${faltan[@]}" || true
  # Intento específico por distro si falló
  case "$(detect_pkg)" in
    apt) pkg_install curl python3 systemd systemd-sysv iproute2 net-tools sqlite3 || true ;;
    dnf|yum) pkg_install curl python3 systemd iproute net-tools sqlite3 || true ;;
    apk) pkg_install curl python3 systemd iproute2 sqlite3 || true ;;
  esac
  has_cmd curl && has_cmd python3 && ok "Dependencias instaladas" || warn "Alguna dependencia no se instaló (revisá)"
}

# ─── Instalar Psiphon (binario + config + entry + servicio) ───
install_psiphon(){
  need_root
  echo "🔴 Instalando Psiphon server..."
  local PSI_BIN="/usr/local/bin/psiphon-server"
  local PSI_DIR="/etc/psiphon"

  # 1) Binario (si no existe)
  if [[ ! -x "$PSI_BIN" ]]; then
    if download_file "https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/psiphon-server" "$PSI_BIN"; then
      chmod 755 "$PSI_BIN"
      ok "Binario psiphon-server instalado"
    else
      warn "No pude bajar psiphon-server"
      press_enter
      return 1
    fi
  else
    ok "Binario psiphon-server ya existe"
  fi

  # 2) Generar config + server entry (claves NUEVAS por VPS)
  mkdir -p "$PSI_DIR"
  local IP_PUB
  IP_PUB="$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ ! -f "$PSI_DIR/psiphond.config" ]]; then
    warn "Generando config y server entry (claves únicas para este VPS)..."
    (cd "$PSI_DIR" && "$PSI_BIN" -ipaddress "$IP_PUB" -protocol SSH:2223 generate >/dev/null 2>&1)
    if [[ -f "$PSI_DIR/psiphond.config" && -f "$PSI_DIR/server-entry.dat" ]]; then
      ok "Config + server entry generados"
      # Copiar el entry donde lo espera el stack
      mkdir -p /etc/ghost-license
      cp -f "$PSI_DIR/server-entry.dat" /etc/ghost-license/psiphon-server-entry.dat 2>/dev/null
      chmod 600 /etc/ghost-license/psiphon-server-entry.dat 2>/dev/null
    else
      warn "La generación falló — revisá manualmente"
      press_enter
      return 1
    fi
  else
    ok "Config psiphond ya existe (se conserva)"
    [[ -f "$PSI_DIR/server-entry.dat" ]] && cp -f "$PSI_DIR/server-entry.dat" /etc/ghost-license/psiphon-server-entry.dat 2>/dev/null
  fi

  # 3) Servicio systemd
  mkdir -p /etc/systemd/system
  cat > /etc/systemd/system/psiphon.service <<EOF
[Unit]
Description=Psiphon Tunnel Server - puerto 2223 (via proxy WS ctmanager)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${PSI_DIR}
ExecStart=${PSI_BIN} -config ${PSI_DIR}/psiphond.config run
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  # 4) Forzar banner SSH-2.0-Go (el proxy lo detecta por ese banner)
  if grep -q '"SSHServerVersion"' "$PSI_DIR/psiphond.config" 2>/dev/null; then
    sed -i 's/"SSHServerVersion"[[:space:]]*:[[:space:]]*"[^"]*"/"SSHServerVersion": "SSH-2.0-Go"/' "$PSI_DIR/psiphond.config"
    ok "Banner SSH-2.0-Go configurado (detección Psiphon del proxy)"
  else
    # Si no existe el campo, agregarlo
    sed -i 's/"ServerIPAddress"[[:space:]]*:[[:space:]]*"[^"]*"/&\n    "SSHServerVersion": "SSH-2.0-Go",/' "$PSI_DIR/psiphond.config" 2>/dev/null || true
    ok "Banner SSH-2.0-Go agregado al config"
  fi
  systemctl daemon-reload
  systemctl enable psiphon >/dev/null 2>&1 || true
  systemctl restart psiphon 2>/dev/null || true
  sleep 3
  if systemctl is-active --quiet psiphon; then
    ok "Psiphon ACTIVO (:2223)"
  else
    warn "Psiphon no arrancó con la IP — probando con 0.0.0.0 (fallback)..."
    # Fallback: bindear a todas las interfaces (algunos VPS no asignan la IP al boot)
    sed -i "s/\"ServerIPAddress\": *\"[^\"]*\"/\"ServerIPAddress\": \"0.0.0.0\"/" "$PSI_DIR/psiphond.config" 2>/dev/null
    systemctl restart psiphon 2>/dev/null || true
    sleep 3
    if systemctl is-active --quiet psiphon; then
      ok "Psiphon ACTIVO (:2223)"
    else
      warn "Psiphon no arrancó — mirá: journalctl -u psiphon -n 20"
    fi
  fi
}


# ─── Instalar Xray (V2Ray: binario + config + servicio + uuid.sh) ───
install_xray(){
  need_root
  echo "🚀 Instalando Xray (V2Ray)..."
  local XRAY_BIN="/usr/local/bin/xray"
  local XRAY_DIR="/usr/local/etc/xray"
  local XRAY_CFG="$XRAY_DIR/config.json"
  local UUID_SH="/usr/local/bin/xray_uuid.sh"

  # 1) Binario
  if [[ ! -x "$XRAY_BIN" ]]; then
    if download_file "https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/xray" "$XRAY_BIN"; then
      chmod 755 "$XRAY_BIN"
      ok "Binario xray instalado"
    else
      warn "No pude bajar xray"
      press_enter
      return 1
    fi
  else
    ok "Binario xray ya existe"
  fi

  # 2) Config (con un UUID inicial aleatorio)
  mkdir -p "$XRAY_DIR"
  if [[ ! -f "$XRAY_CFG" ]]; then
    local UUID_INICIAL
    if [[ -x "$XRAY_BIN" ]]; then
      UUID_INICIAL="$("$XRAY_BIN" uuid 2>/dev/null)"
    fi
    [[ -z "$UUID_INICIAL" ]] && UUID_INICIAL="$(cat /proc/sys/kernel/random/uuid 2>/dev/null)"
    cat > "$XRAY_CFG" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "$UUID_INICIAL", "flow": "" } ],
        "decryption": "none"
      },
      "streamSettings": { "network": "tcp", "security": "none" }
    }
  ],
  "outbounds": [ { "protocol": "freedom", "tag": "direct" } ]
}
EOF
    ok "Config xray creado (UUID inicial: $UUID_INICIAL)"
  else
    ok "Config xray ya existe (se conserva)"
  fi

  # 3) xray_uuid.sh (gestión de UUIDs para el ghost-manager)
  if download_file "https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/xray_uuid.sh" "$UUID_SH"; then
    chmod 755 "$UUID_SH"
    ok "xray_uuid.sh instalado"
  fi

  # 4) Servicio systemd
  mkdir -p /etc/systemd/system
  cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable xray >/dev/null 2>&1 || true
  systemctl restart xray 2>/dev/null || true
  sleep 2
  if systemctl is-active --quiet xray; then
    ok "Xray ACTIVO (:8443)"
  else
    warn "Xray no arrancó — mirá: journalctl -u xray -n 20"
  fi
}

# ─── Habilitar EPEL en CentOS/Rocky/Alma (necesario para openvpn/wireguard) ───
ensure_epel(){
  local pkgm
  pkgm="$(detect_pkg)"
  if [[ "$pkgm" == "dnf" || "$pkgm" == "yum" ]]; then
    # CentOS Stream 9 / Rocky / Alma
    if [[ -f /etc/rocky-release || -f /etc/almalinux-release || -f /etc/centos-release ]]; then
      local ver
      ver="$(rpm -q --qf '%{VERSION}' centos-release 2>/dev/null || rpm -q --qf '%{VERSION}' rocky-release 2>/dev/null || rpm -q --qf '%{VERSION}' almalinux-release 2>/dev/null | cut -d. -f1)"
      if ! rpm -q epel-release >/dev/null 2>&1; then
        echo "  📦 Habilitando EPEL (necesario para OpenVPN/WireGuard)..."
        if [[ "$pkgm" == "dnf" ]]; then
          dnf install -y -q "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${ver}.noarch.rpm" >/dev/null 2>&1 || \
            dnf install -y -q epel-release >/dev/null 2>&1 || true
        else
          yum install -y -q "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${ver}.noarch.rpm" >/dev/null 2>&1 || \
            yum install -y -q epel-release >/dev/null 2>&1 || true
        fi
        rpm -q epel-release >/dev/null 2>&1 && ok "EPEL habilitado" || warn "No pude habilitar EPEL (instalá epel-release manual)"
      fi
    fi
  fi
}

# ─── Instalar OpenVPN (server :1194 + easy-rsa + auth contra sistema) ───
install_openvpn(){
  need_root
  echo "🛡️ Instalando OpenVPN server..."
  local OVPN_DIR="/etc/openvpn"
  local PKI="$OVPN_DIR/easy-rsa/pki"

  # 0) EPEL en CentOS/Rocky/Alma (openvpn y easy-rsa viven ahí)
  ensure_epel

  # 1) Paquetes
  if ! command -v openvpn >/dev/null 2>&1; then
    pkg_install openvpn easy-rsa >/dev/null 2>&1 || pkg_install openvpn >/dev/null 2>&1 || true
    apt-get install -y -qq openvpn easy-rsa openssl >/dev/null 2>&1 || true
  fi
  command -v openvpn >/dev/null 2>&1 || { warn "No pude instalar openvpn"; press_enter; return 1; }
  ok "openvpn instalado"

  # 2) Certificados (easy-rsa)
  if [[ ! -f "$PKI/ca.crt" || ! -f "$PKI/issued/server.crt" ]]; then
    warn "Generando certificados (easy-rsa)..."
    rm -rf /tmp/easyrsa-gen && mkdir -p /tmp/easyrsa-gen
    cd /tmp/easyrsa-gen
    if command -v easy-rsa >/dev/null 2>&1; then
      EASYRSA_BIN="$(command -v easy-rsa)"
    else
      EASYRSA_BIN="/usr/share/easy-rsa/easyrsa"
    fi
    if [[ -x "$EASYRSA_BIN" || -f "$EASYRSA_BIN" ]]; then
      export EASYRSA_BATCH=1 EASYRSA_ALGO=ec
      "$EASYRSA_BIN" init-pki >/dev/null 2>&1 || true
      "$EASYRSA_BIN" build-ca nopass >/dev/null 2>&1 || true
      "$EASYRSA_BIN" gen-dh >/dev/null 2>&1 || true
      "$EASYRSA_BIN" build-server-full server nopass >/dev/null 2>&1 || true
      unset EASYRSA_BATCH EASYRSA_ALGO
    else
      warn "easy-rsa no encontrado — intentando con openssl directo..."
    fi
    # Copiar el pki generado
    if [[ -d /tmp/easyrsa-gen/pki ]]; then
      mkdir -p "$PKI"
      cp -r /tmp/easyrsa-gen/pki/* "$PKI/" 2>/dev/null
    fi
  fi

  if [[ -f "$PKI/ca.crt" && -f "$PKI/issued/server.crt" ]]; then
    ok "Certificados listos"
  else
    warn "Certificados incompletos — revisá easy-rsa manualmente"
    press_enter
    return 1
  fi

  # 3) auth_check.sh (autenticación contra usuarios del sistema)
  cat > "$OVPN_DIR/auth_check.sh" <<'EOF'
#!/bin/bash
set -e
USER="${USERNAME:-$username}"
PASS="${PASSWORD:-$password}"
if [ -z "$USER" ] || [ -z "$PASS" ]; then exit 1; fi
python3 - "$USER" "$PASS" << 'PYEOF'
import sys, crypt, spwd, time
user, password = sys.argv[1], sys.argv[2]
try:
    shadow = spwd.getspnam(user)
except KeyError:
    sys.exit(1)
if shadow.sp_expire and shadow.sp_expire > 0 and shadow.sp_expire < int(time.time()//86400):
    sys.exit(1)
h = shadow.sp_pwdp
if h in ('!', '*', ''):
    sys.exit(1)
sys.exit(0 if crypt.crypt(password, h) == h else 1)
PYEOF
EOF
  chmod 755 "$OVPN_DIR/auth_check.sh"
  ok "auth_check.sh creado"

  # 4) server.conf
  cat > "$OVPN_DIR/server.conf" <<'EOF'
# 🦇 OpenVPN server - TCP 1194 (a través del proxy WS del ctmanager)
port 1194
proto tcp
dev tun

# Certificados
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem

# Autenticación por usuario/contraseña (contra usuarios del sistema)
auth-user-pass-verify /etc/openvpn/auth_check.sh via-env
verify-client-cert none
username-as-common-name
script-security 3

# Red interna
server 10.8.0.0 255.255.255.0
topology subnet
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

keepalive 10 120
persist-key
persist-tun

# Seguridad
cipher none
auth none

status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
verb 3
tun-mtu 1200
mssfix 1200
duplicate-cn
EOF
  ok "server.conf creado"

  # 5) Servicio + IP forwarding + NAT (MASQUERADE para que los clientes naveguen)
  sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf 2>/dev/null || true
  echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
  # NAT: los clientes OpenVPN (10.8.0.0/24) salen a internet con masquerade
  local IFACE_NAT
  IFACE_NAT="$(ip route 2>/dev/null | grep '^default' | awk '{print $5}' | head -1)" || true
  [[ -z "$IFACE_NAT" ]] && IFACE_NAT="eth0"
  iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "$IFACE_NAT" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$IFACE_NAT" -j MASQUERADE 2>/dev/null || true
  # ufw: permitir forwarding
  sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw 2>/dev/null || true
  systemctl daemon-reload
  systemctl enable openvpn@server >/dev/null 2>&1 || true
  systemctl restart openvpn@server 2>/dev/null || true
  sleep 2
  if systemctl is-active --quiet openvpn@server; then
    ok "OpenVPN ACTIVO (:1194)"
  else
    warn "OpenVPN no arrancó — mirá: journalctl -u openvpn@server -n 20"
  fi
}

# ─── Instalar WireGuard (wg0 + bridge TCP) ───
install_wireguard(){
  need_root
  echo "🔐 Instalando WireGuard..."
  # EPEL en CentOS/Rocky/Alma (wireguard-tools vive ahí)
  ensure_epel
  if ! command -v wg >/dev/null 2>&1; then
    pkg_install wireguard wireguard-tools >/dev/null 2>&1 || \
      apt-get install -y -qq wireguard wireguard-tools >/dev/null 2>&1 || true
  fi
  command -v wg >/dev/null 2>&1 || { warn "No pude instalar wireguard"; press_enter; return 1; }
  ok "wireguard instalado"

  # Config wg0 (claves nuevas por VPS)
  if [[ ! -f /etc/wireguard/wg0.conf ]]; then
    mkdir -p /etc/wireguard
    local PRIV WG_PUB
    PRIV="$(wg genkey 2>/dev/null)"
    WG_PUB="$(echo "$PRIV" | wg pubkey 2>/dev/null)" || true
    cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = ${PRIV}
Address = 10.9.0.1/24
ListenPort = 51820
SaveConfig = false
EOF
    chmod 600 /etc/wireguard/wg0.conf
    ok "wg0.conf creado (pubkey: ${WG_PUB:0:20}...)"
  else
    ok "wg0.conf ya existe (se conserva)"
  fi

  systemctl enable wg-quick@wg0 >/dev/null 2>&1 || true
  systemctl restart wg-quick@wg0 2>/dev/null || true
  sleep 2
  if systemctl is-active --quiet wg-quick@wg0; then
    ok "WireGuard ACTIVO (10.9.0.1, :51820)"
  else
    warn "WireGuard no arrancó — mirá: journalctl -u wg-quick@wg0 -n 15"
  fi
}

# ─── Instalar UDP Custom (binario + servicio) ───
install_udpcustom(){
  need_root
  echo "🛰️ Instalando UDP Custom..."
  local UDP_BIN="/usr/local/bin/udp-custom"
  local UDP_DIR="/root/udp"

  # El binario udp-custom es propietario — buscar local o avisar
  if [[ ! -x "$UDP_BIN" ]]; then
    if [[ -f /root/udp/udp-custom ]]; then
      cp /root/udp/udp-custom "$UDP_BIN" && chmod 755 "$UDP_BIN"
      ok "Binario udp-custom instalado (desde /root/udp)"
    else
      warn "No hay binario udp-custom en el VPS."
      warn "Ponelo en /root/udp/udp-custom y volvé a correr esta opción."
      press_enter
      return 1
    fi
  fi

  # Config
  mkdir -p "$UDP_DIR"
  if [[ ! -f "$UDP_DIR/config.json" ]]; then
    cat > "$UDP_DIR/config.json" <<'EOF'
{
  "listen": ":36712",
  "auth": "udpprueba2026",
  "dns": "8.8.8.8"
}
EOF
    ok "config.json creado (:36712)"
  fi

  # Servicio
  mkdir -p /etc/systemd/system
  cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=UDP Custom
After=network.target

[Service]
Type=simple
WorkingDirectory=${UDP_DIR}
ExecStart=${UDP_BIN} -config ${UDP_DIR}/config.json
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable udp-custom >/dev/null 2>&1 || true
  systemctl restart udp-custom 2>/dev/null || true
  sleep 2
  if systemctl is-active --quiet udp-custom; then
    ok "UDP Custom ACTIVO (:36712)"
  else
    warn "UDP Custom no arrancó — mirá: journalctl -u udp-custom -n 15"
  fi
}

# ─── Instalación AUTOMÁTICA (todo sin preguntar) ───
auto_install(){
  need_root
  echo -e "${BOLD}${GREEN}"
  echo "======================================================"
  echo "   🦇  GHOST PROXY v14 - AUTOINSTALL"
  echo ""
  echo "   Multi-Protocolo: SSH | Psiphon | V2Ray"
  echo "   OpenVPN | WireGuard | UDP Custom | BadVPN"
  echo "======================================================"
  echo -e "${NC}"
  echo -e "${CYAN}  [SISTEMAS COMPATIBLES]${NC}"
  echo -e "  ${GREEN}+${NC} Ubuntu ${BOLD}22${NC}->${BOLD}26${NC}          (apt)"
  echo -e "  ${GREEN}+${NC} Debian ${BOLD}12${NC}->${BOLD}13+${NC}         (apt)"
  echo -e "  ${GREEN}+${NC} Rocky / Alma / CentOS ${BOLD}9${NC}  (dnf + EPEL auto)"
  echo -e "  ${GREEN}+${NC} Fedora | Arch | Alpine | openSUSE"
  echo ""
  # 0) Actualizar el sistema (apt update + upgrade, como todos los scripts)
  if has_cmd apt-get; then
    echo -e "${CYAN}  🔄 Actualizando el sistema (apt update + upgrade)...${NC}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null 2>&1 || true
    apt-get upgrade -y -qq >/dev/null 2>&1 || apt-get upgrade -y >/dev/null 2>&1 || true
    ok "Sistema actualizado"
  fi
  # 0b) dependencias primero
  ensure_deps_auto
  # 1) proxy.py
  download_proxy
  # 2) config — detecta los servicios SOLO (backup si existe)
  if [[ -f "$CONFIG_FILE" ]]; then
    cp -f "$CONFIG_FILE" "${CONFIG_FILE}.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    warn "Config previa respaldada (.bak) — redetectando servicios..."
    detect_services
  else
    detect_services
  fi
  # 3) servicio
  write_service
  # 4) liberar puertos (web servers)
  for svc in apache2 nginx httpd lighttpd caddy haproxy; do
    systemctl is-active --quiet "$svc" 2>/dev/null && {
      systemctl stop "$svc" 2>/dev/null || true
      systemctl disable "$svc" 2>/dev/null || true
    }
  done
  # 5) badvpn (si existe binario o se puede bajar — GitHub primero)
  local BAD_BIN="/bin/badvpn-udpgw"
  if [[ ! -f "$BAD_BIN" ]]; then
    local bad_ok=0
    for url in "$BADVPN_URL" "$BADVPN_FALLBACK"; do
      if download_file "$url" "$BAD_BIN" 2>/dev/null && [[ -s "$BAD_BIN" ]]; then
        chmod 755 "$BAD_BIN"
        bad_ok=1
        break
      fi
    done
    [[ $bad_ok -eq 1 ]] && ok "BadVPN descargado" || warn "badvpn no disponible (opcional)"
  fi
  if [[ -f "$BAD_BIN" ]]; then
    mkdir -p /etc/systemd/system
  cat > /etc/systemd/system/badvpn.service <<EOF
[Unit]
Description=BadVPN UDPGW (puerto 7300)
After=network.target

[Service]
Type=simple
ExecStart=/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 5
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable badvpn >/dev/null 2>&1 || true
    systemctl restart badvpn 2>/dev/null || true
    ok "BadVPN UDPGW en :7300"
  fi
  # 6) Ghost Manager (menú de usuarios) — descargar siempre
  if download_file "https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-manager" "/usr/local/bin/ghost-manager" && [[ -s /usr/local/bin/ghost-manager ]]; then
    chmod 755 /usr/local/bin/ghost-manager
    ok "Ghost Manager instalado (/usr/local/bin/ghost-manager)"
  else
    warn "No pude bajar ghost-manager (opcional — el menú sigue funcionando sin usuarios)"
  fi
  # 6b) Psiphon server (si no está instalado)
  if ! systemctl is-active --quiet psiphon 2>/dev/null && [[ ! -x /usr/local/bin/psiphon-server ]]; then
    install_psiphon
  else
    ok "Psiphon ya instalado (se conserva)"
  fi
  # 6c) Xray V2Ray (si no está instalado)
  if ! systemctl is-active --quiet xray 2>/dev/null && [[ ! -x /usr/local/bin/xray ]]; then
    install_xray
  else
    ok "Xray (V2Ray) ya instalado (se conserva)"
  fi
  # 6d) OpenVPN (si no está instalado)
  if ! systemctl is-active --quiet openvpn@server 2>/dev/null; then
    install_openvpn
  else
    ok "OpenVPN ya instalado (se conserva)"
  fi
  # 6e) WireGuard (si no está instalado)
  if ! systemctl is-active --quiet wg-quick@wg0 2>/dev/null; then
    install_wireguard
  else
    ok "WireGuard ya instalado (se conserva)"
  fi
  # 6f) Ghost AI Help (mini asistente IA gratis)
  install_ai_help
  # 6g) SSHGO — servidor SSH con banner dinámico (USER/EXP/DAYS/TRF/LIMIT)
  install_sshgo
  # 6h) BROOK — proxy wsserver (útil fuera de zero-rating, casi ningún script lo trae)
  install_brook
  # 7) arrancar todo
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
  systemctl restart "$SERVICE_NAME" 2>/dev/null || true
  sleep 2
  # 8) Pedir el dominio (si no está guardado — pregunta siempre, con timeout si no hay tty)
  if [[ ! -f "$DOMAIN_FILE" ]]; then
    echo ""
    if [[ -t 0 ]]; then
      read -r -p "  🌐 ¿Dominio enlazado a este VPS? (ej: pinche.chauinforme.online) [Enter = IP]: " dom
    else
      # Sin tty (pipelines, cron): esperar 8s por si hay entrada, si no usar IP
      echo -e "  ${YELLOW}🌐 ¿Dominio enlazado a este VPS? (ej: pinche.chauinforme.online)${NC}"
      echo -e "  ${YELLOW}   [Enter = usar IP pública]${NC}"
      read -r -t 8 -p "  🌐 Dominio: " dom || true
    fi
    if [[ -n "$dom" ]]; then
      dom="$(echo "$dom" | tr -d ' ' | sed 's|https\?://||')"
      mkdir -p "$INSTALL_DIR"
      echo "$dom" > "$DOMAIN_FILE"
      ok "Dominio guardado: $dom"
    else
      warn "Sin dominio — se usará la IP pública para los links"
    fi
  else
    # Ya existe: mostrar el actual y ofrecer cambiarlo
    local actual_dom
    actual_dom="$(cat "$DOMAIN_FILE" 2>/dev/null || echo '')"
    echo ""
    echo -e "  ${CYAN}🌐 Dominio actual: ${BOLD}${GREEN}${actual_dom:-IP del VPS}${NC}"
    if [[ -t 0 ]]; then
      read -r -p "  ¿Cambiarlo? (s/N): " cambia
    else
      read -r -t 5 -p "  ¿Cambiarlo? (s/N): " cambia || cambia="n"
    fi
    if [[ "$cambia" == "s" || "$cambia" == "S" ]]; then
      read -r -p "  🌐 Nuevo dominio: " dom2
      if [[ -n "$dom2" ]]; then
        dom2="$(echo "$dom2" | tr -d ' ' | sed 's|https\?://||')"
        echo "$dom2" > "$DOMAIN_FILE"
        ok "Dominio actualizado: $dom2"
      fi
    fi
  fi
  echo
  # 9) Abrir TODOS los puertos del stack en el firewall (ufw/firewalld/iptables)
  open_all_ports
  # 10) SSL 443 → proxy WS (método TLS tipo CloudRun) — si hay dominio
  if [[ -f "$DOMAIN_FILE" ]]; then
    echo -e "  ${CYAN}🌐 ¿Instalar SSL 443 → proxy (método TLS)? [s/N]${NC}"
    if [[ -t 0 ]]; then
      read -r -p "  → " q_tls
    else
      read -r -t 5 -p "  → " q_tls || q_tls="n"
    fi
    if [[ "$q_tls" == "s" || "$q_tls" == "S" ]]; then
      install_tls_443
    fi
  fi
  echo "══════════════════════════════════════════════"
  echo " 🦇 INSTALACIÓN COMPLETADA"
  echo "══════════════════════════════════════════════"
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "Proxy WS :80"
  else
    warn "Proxy WS :80 no arrancó (puerto ocupado?)"
  fi
  if systemctl is-active --quiet psiphon 2>/dev/null; then
    ok "Psiphon :2223"
  fi
  if systemctl is-active --quiet xray 2>/dev/null; then
    ok "Xray V2Ray :8443"
  fi
  if systemctl is-active --quiet openvpn@server 2>/dev/null; then
    ok "OpenVPN :1194"
  fi
  if systemctl is-active --quiet wg-quick@wg0 2>/dev/null; then
    ok "WireGuard :51820"
  fi
  if systemctl is-active --quiet badvpn 2>/dev/null; then
    ok "BadVPN UDPGW :7300"
  fi
  [[ -x /usr/local/bin/ghost-manager ]] && ok "Ghost Manager (usuarios)"
  echo
  echo "💡 Escribí: ghost-manager   → para entrar al menú"
  echo
}

# ─── Actualización automática ───
SCRIPT_URL="https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh"
SCRIPT_LOCAL="${BASH_SOURCE[0]}"

check_update(){
  # Compara la versión local con la de GitHub (sin tocar nada)
  local remota
  remota="$(curl -s --max-time 8 "$SCRIPT_URL" 2>/dev/null | grep -m1 '^VERSION=' | cut -d'"' -f2)"
  if [[ -z "$remota" ]]; then
    return 1  # sin conexión / no se pudo verificar
  fi
  if [[ "$remota" != "$VERSION" ]]; then
    echo
    echo -e "${YELLOW}  ⚠️  ¡Hay una versión nueva disponible!${NC}"
    echo -e "  ${YELLOW}     Local: ${BOLD}$VERSION${NC}${YELLOW}  →  Remota: ${BOLD}${GREEN}$remota${NC}"
    echo
    return 0  # hay update
  fi
  return 1
}

do_update(){
  need_root
  echo
  echo -e "${BOLD}${CYAN}  🔄 ACTUALIZANDO GHOST PROXY...${NC}"
  local tmp="/tmp/ghost-proxy-update.sh"
  if download_file "$SCRIPT_URL" "$tmp" && [[ -s "$tmp" ]] && bash -n "$tmp" 2>/dev/null; then
    cp "$tmp" "$SCRIPT_LOCAL"
    chmod 755 "$SCRIPT_LOCAL"
    ok "¡Actualizado! (versión nueva instalada)"
    echo -e "  ${YELLOW}💡 Reiniciá el script para usar la versión nueva:${NC}"
    echo -e "     ${BOLD}bash $SCRIPT_LOCAL${NC}"
    echo
    read -p "  ⏎ Enter para continuar..."
    # Ejecutar la versión nueva directamente
    exec bash "$SCRIPT_LOCAL" 2>/dev/null || true
  else
    warn "No pude descargar/verificar la actualización"
    press_enter
  fi
}


# ─── Instalar Ghost AI Help (mini asistente — 3 opciones de IA) ───
# El 9Router central del dueño (157.250.202.243:20128) da servicio gratis a todos los VPS
AI_ROUTER_CENTRAL="157.250.202.243:20128"
install_ai_help(){
  step "🤖 Ghost AI Help — asistente en el menú"
  local AI_BIN="/usr/local/bin/ghost-ai-help"
  local CONFIG="/etc/ghost-license/ai-config"
  mkdir -p /etc/ghost-license

  # 1) Copiar el script (local primero, sino descargar)
  if [[ -f "$(dirname "$0")/ghost-ai-help" ]]; then
    cp -f "$(dirname "$0")/ghost-ai-help" "$AI_BIN"
  elif [[ -f /root/ghost-ai-help ]]; then
    cp -f /root/ghost-ai-help "$AI_BIN"
  else
    download_file "https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-ai-help" "$AI_BIN" 2>/dev/null || \
    warn "No pude bajar ghost-ai-help (opcional — el menú sigue funcionando sin IA)"
  fi
  chmod 755 "$AI_BIN" 2>/dev/null || true

  # 2) Si el VPS es el del dueño, guardar la key del router
  if [[ -f /root/.9router-router-key ]] && [[ ! -f /etc/ghost-license/ai-router.key ]]; then
    cp -f /root/.9router-router-key /etc/ghost-license/ai-router.key
    chmod 600 /etc/ghost-license/ai-router.key
  fi

  # 3) Preguntar qué IA usar (solo si hay tty; en autoinstal sin tty → router gratis)
  local eleccion="1"
  if [[ -t 0 ]]; then
    echo ""
    echo -e "  ${BOLD}${CYAN}  🤖 ¿Asistente IA en el menú?${NC}"
    echo -e "  ${BOLD}${FUCSIA}1${NC}) 🆓 Gratis (router del vendedor — DeepSeek, sin costo)"
    echo -e "  ${BOLD}${FUCSIA}2${NC}) 🔑 Usar MI propia API key (Anthropic/OpenAI/DeepSeek)"
    echo -e "  ${BOLD}${FUCSIA}3${NC}) ❌ No quiero IA"
    read -r -p "  ➤ Opción [1]: " eleccion
    eleccion="${eleccion:-1}"
  fi

  case "$eleccion" in
    2)
      # ── API propia del cliente ──
      echo -e "  ${BOLD}${CYAN}  🔑 ¿Qué proveedor?${NC}"
      echo -e "  ${BOLD}${FUCSIA}1${NC}) Anthropic (Claude)"
      echo -e "  ${BOLD}${FUCSIA}2${NC}) OpenAI (GPT)"
      echo -e "  ${BOLD}${FUCSIA}3${NC}) DeepSeek"
      echo -e "  ${BOLD}${FUCSIA}4${NC}) Otro (compatible OpenAI)"
      read -r -p "  ➤ Proveedor [1]: " prov
      prov="${prov:-1}"
      case "$prov" in
        1) PROV=anthropic; DEF_MODEL="claude-sonnet-4-20250514"; URL="";;
        2) PROV=openai;    DEF_MODEL="gpt-4o-mini";          URL="";;
        3) PROV=deepseek;  DEF_MODEL="deepseek-v4-flash";        URL="";;
        4) PROV=otro;      DEF_MODEL="gpt-4o-mini";          read -r -p "  🌐 Base URL (ej https://api.x.com/v1): " URL;;
        *) PROV=anthropic; DEF_MODEL="claude-sonnet-4-20250514"; URL="";;
      esac
      read -r -p "  🔑 Pegá tu API key: " APIKEY
      read -r -p "  🧠 Modelo [Enter=$DEF_MODEL]: " MODELO
      MODELO="${MODELO:-$DEF_MODEL}"
      if [[ -n "$APIKEY" ]]; then
        cat > "$CONFIG" <<EOF
PROVEEDOR=$PROV
API_KEY=$APIKEY
MODELO=$MODELO
BASE_URL=$URL
EOF
        chmod 600 "$CONFIG"
        ok "IA configurada: $PROV ($MODELO)"
      else
        warn "No pegaste key — IA desactivada (podés configurar luego en $CONFIG)"
        rm -f "$CONFIG"
      fi
      ;;
    3)
      # ── Sin IA ──
      rm -f "$CONFIG"
      ok "Sin IA — el menú funciona igual"
      ;;
    *)
      # ── Router gratis (default) ──
      rm -f "$CONFIG"
      if [[ -f /etc/ghost-license/ai-router.key ]]; then
        sed -i "s|http://localhost:20128|http://${AI_ROUTER_CENTRAL}|" "$AI_BIN" 2>/dev/null || true
        ok "IA gratis ACTIVA (router del vendedor — DeepSeek)"
      else
        warn "IA gratis instalada pero SIN key — configurala en /etc/ghost-license/ai-router.key"
      fi
      ;;
  esac
}


# ─── BROOK: proxy TCP/UDP estilo V2Ray (modo wsserver, útil fuera de zero-rating) ───
install_brook(){
  need_root
  local BROOK_BIN="/usr/local/bin/brook"
  if [[ -x "$BROOK_BIN" ]]; then
    warn "brook ya existe (se conserva)"
  else
    warn "Descargando brook (wsserver)..."
    local url_ok=0
    for url in \
      "https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/brook-linux-amd64" \
      "https://github.com/Agro-bot2026/Dev-proxy/raw/main/brook-linux-amd64"; do
      if download_file "$url" "$BROOK_BIN" 2>/dev/null && [[ -s "$BROOK_BIN" ]]; then
        chmod 755 "$BROOK_BIN"
        url_ok=1
        break
      fi
    done
    if [[ $url_ok -eq 1 ]]; then
      ok "brook descargado ($(du -h "$BROOK_BIN" | cut -f1))"
    else
      warn "No pude bajar brook (protocolo Brook NO activo)"
      return 0
    fi
  fi
  # Password aleatoria + servicio systemd (escucha SOLO en 127.0.0.1)
  local B_PASS
  B_PASS="$(openssl rand -hex 8 2>/dev/null || echo brookpass123)"
  mkdir -p /etc/systemd/system
  cat > /etc/systemd/system/brook.service <<EOF
[Unit]
Description=Brook wsserver (proxy TCP/UDP estilo V2Ray) - puerto 18999
After=network.target

[Service]
Type=simple
ExecStart=$BROOK_BIN wsserver --listen 127.0.0.1:18999 --password $B_PASS
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable brook >/dev/null 2>&1 || true
  systemctl restart brook 2>/dev/null || true
  if systemctl is-active --quiet brook; then
    ok "Brook ACTIVO en 127.0.0.1:18999"
  else
    warn "brook no arrancó — mirá journalctl -u brook"
  fi
  # Guardar la password para generar links
  echo "$B_PASS" > /etc/ctmanager/config/brook_password
  chmod 600 /etc/ctmanager/config/brook_password 2>/dev/null || true
  # Config: agregar brook_port
  if [[ -f "$CONFIG_FILE" ]]; then
    python3 - "$CONFIG_FILE" << 'PYEOF'
import json, sys
cfg_path = sys.argv[1]
cfg = json.load(open(cfg_path))
cfg['brook_host'] = '127.0.0.1'
cfg['brook_port'] = 18999
json.dump(cfg, open(cfg_path, 'w'), indent=2)
PYEOF
    systemctl restart "$SERVICE_NAME" 2>/dev/null || true
    ok "config.json actualizado con brook_port=18999 + proxy reiniciado"
  fi
}


# ─── SSHGO: servidor SSH con banner dinámico (USER/EXP/DAYS/TRF/LIMIT) ───
install_sshgo(){
  need_root
  local SSHGO_BIN="/usr/local/bin/sshgo"
  if [[ -x "$SSHGO_BIN" ]]; then
    warn "sshgo ya existe (se conserva)"
  else
    warn "Descargando sshgo (banner dinámico SSH)..."
    local url_ok=0
    for url in \
      "https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/sshgo-linux-amd64" \
      "https://github.com/Agro-bot2026/Dev-proxy/raw/main/sshgo-linux-amd64"; do
      if download_file "$url" "$SSHGO_BIN" 2>/dev/null && [[ -s "$SSHGO_BIN" ]]; then
        chmod 755 "$SSHGO_BIN"
        url_ok=1
        break
      fi
    done
    if [[ $url_ok -eq 1 ]]; then
      ok "sshgo descargado ($(du -h "$SSHGO_BIN" | cut -f1))"
    else
      warn "No pude bajar sshgo (banner dinámico NO activo — SSH sigue yendo al 22)"
      return 0
    fi
  fi
  # Servicio systemd (escucha SOLO en 127.0.0.1 — no se abre al firewall)
  mkdir -p /etc/systemd/system
  cat > /etc/systemd/system/sshgo.service <<EOF
[Unit]
Description=sshgo - servidor SSH con banner dinámico (USER/EXP/DAYS/TRF/LIMIT)
After=network.target

[Service]
Type=simple
ExecStart=$SSHGO_BIN
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable sshgo >/dev/null 2>&1 || true
  systemctl restart sshgo 2>/dev/null || true
  if systemctl is-active --quiet sshgo; then
    ok "sshgo ACTIVO en 127.0.0.1:2200 (SSH va al sshgo → banner en log HTTP Custom)"
  else
    warn "sshgo no arrancó — mirá journalctl -u sshgo"
  fi
  # Plantilla del banner (solo si no existe — no pisar personalizaciones)
  if [[ ! -f /etc/ctmanager/config/sshgo_banner.txt ]]; then
    mkdir -p /etc/ctmanager/config
    cat > /etc/ctmanager/config/sshgo_banner.txt << 'BEOF'
<span style="background-color: #000000;"><font color="#ff8c00"><b>✅ EPRO.HC ✅</b></font></span><br/>
<font color='green'><b>👤 USUARIO:</b> USER</font><br/>
<font color='blue'><b>📅 VENCE:</b> EXP</font><br/>
<font color='teal'><b>⏳ DÍAS:</b> DAYS</font><br/>
<font color='teal'><b>📊 TRÁFICO:</b> TRF GB</font><br/>
<font color='teal'><b>🎯 LÍMITE:</b> LIMIT GB</font><br/>
<font color='red'><b>⚡ ESTADO:</b> {status}</font>
BEOF
    ok "Plantilla banner creada (editable en ghost-manager → 19)"
  fi
  # Config: agregar sshgo_port (sin pisar el resto)
  if [[ -f "$CONFIG_FILE" ]]; then
    python3 - "$CONFIG_FILE" << 'PYEOF'
import json, sys
cfg_path = sys.argv[1]
cfg = json.load(open(cfg_path))
cfg['sshgo_host'] = '127.0.0.1'
cfg['sshgo_port'] = 2200
json.dump(cfg, open(cfg_path, 'w'), indent=2)
PYEOF
    systemctl restart "$SERVICE_NAME" 2>/dev/null || true
    ok "config.json actualizado con sshgo_port=2200 + proxy reiniciado"
  fi
}

# ─── Menú principal ───
menu(){
  need_root
  while true; do
    banner
    show_status
    # Aviso de actualización (solo si hay versión nueva)
    if check_update; then
      echo -e "  ${YELLOW}⚠️  Actualización disponible (${BOLD}${GREEN}ver más arriba${NC}${YELLOW})${NC}"
      echo
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " [1] 🛠️  Instalar / Actualizar proxy"
    echo " [2] 🔓 Liberar puertos 80/443"
    echo " [3] 🟣 BadVPN UDPGW (UDP Custom)"
    echo " [4] ⛔ Detener servicio"
    echo " [5] ▶️  Reanudar servicio"
    echo " [6] 🔄 Reiniciar servicio"
    echo " [7] 📜 Ver logs"
    echo " [8] ✏️  Editar config.json (nano)"
    echo " [9] 🛡️  Firewall UFW"
    echo " [10] 🧨 Desinstalar servicio"
    echo " ────────────────────────────────────────────────"
    echo " [11] 👤 Crear usuario SSH/OpenVPN"
    echo " [12] 🚀 Crear usuario V2Ray"
    echo " [13] 🌐 Estado Psiphon"
    echo " [14] 👥 Listar usuarios"
    echo " [15] 🗑️  Eliminar usuario"
    echo " [16] 🛰️  Crear usuario UDP Custom"
    echo " [17] 🔐 Estado WireGuard"
    echo " ────────────────────────────────────────────────"
    echo " [18] 🔒 Instalar SSL 443 → proxy (método TLS)"
    echo " [19] 🔄 ACTUALIZAR Ghost Proxy (si hay versión nueva)"
    echo " [20] 🟦 Instalar Brook (proxy wsserver, opcional)"
    echo " [0] Salir"
    echo
    read -r -p "Opción: " op
    case "$op" in
      1) install_proxy ;;
      2) free_ports ;;
      3) install_badvpn ;;
      4) systemctl stop "$SERVICE_NAME" 2>/dev/null || true; ok "Detenido"; press_enter ;;
      5) systemctl start "$SERVICE_NAME" 2>/dev/null || true; ok "Reanudado"; press_enter ;;
      6) systemctl restart "$SERVICE_NAME" 2>/dev/null || true; ok "Reiniciado"; press_enter ;;
      7) do_logs ;;
      8) edit_config ;;
      9) firewall_menu ;;
      10) do_uninstall ;;
      11|12|13|14|15|16|17)
        if [[ -x /usr/local/bin/ghost-manager ]]; then
          /usr/local/bin/ghost-manager
        else
          warn "Ghost Manager no instalado. Corré la opción 1 (Instalar) primero."
          press_enter
        fi
        ;;
      18) install_tls_443; press_enter ;;
      19) do_update ;;
      20) install_brook; press_enter ;;
      0) exit 0 ;;
      *) warn "Opción inválida"; press_enter ;;
    esac
  done
}

# ─── Arranque: autoinstall si se pasa "auto", si no menú ───
if [[ "${1:-}" == "auto" || "${1:-}" == "--auto" || "${1:-}" == "-y" ]]; then
  auto_install
  exit 0
fi

# ─── Modo LIMPIO: borra todo lo anterior y reinstala desde cero ───
if [[ "${1:-}" == "limpio" || "${1:-}" == "--limpio" || "${1:-}" == "--clean" || "${1:-}" == "-c" ]]; then
  echo -e "${YELLOW}⚠️  Vas a borrar TODO lo instalado (proxy, config, badvpn, manager)${NC}"
  read -r -p "¿Confirmás? (s/N): " conf
  if [[ "${conf,,}" == "s" || "${conf,,}" == "y" ]]; then
    clean_all
    echo ""
    echo -e "${GREEN}⚡ Instalando desde cero...${NC}"
      auto_install
  else
    echo "Cancelado."
  fi
  exit 0
fi

menu
