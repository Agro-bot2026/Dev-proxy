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

# ─── De dónde baja el proxy.py (GitHub = fuente de verdad, VPS = fallback) ───
PROXY_URL="https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/proxy.py"
PROXY_FALLBACK="https://configs.charly-tricks.dev/configs/proxy.py"
BADVPN_URL="https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/badvpn-udpgw"
BADVPN_FALLBACK="https://configs.charly-tricks.dev/configs/badvpn-udpgw"

BANNER_COLOR='\033[1;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
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
  "wg_port": 51821
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
  local listeners
  if has_cmd ss; then
    listeners="$(ss -tlnp 2>/dev/null)"
  elif has_cmd netstat; then
    listeners="$(netstat -tlnp 2>/dev/null)"
  fi

  # 1) SSH (sshd o dropbear)
  local ssh_pid
  ssh_pid="$(pgrep -f 'sshd|dropbear' 2>/dev/null | head -1 || true)"
  if [[ -n "$ssh_pid" ]]; then
    ssh_port="$(echo "$listeners" | grep -E 'sshd|dropbear' | grep -oE ':[0-9]+' | head -1 | tr -d ':')"
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
    v2ray_port="$(echo "$listeners" | grep -E 'xray|v2ray' | grep -oE ':[0-9]+' | head -1 | tr -d ':')"
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
    psiphon_port="$(echo "$listeners" | grep -E 'psiphon' | grep -oE ':[0-9]+' | head -1 | tr -d ':')"
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
    ovpn_port="$(echo "$listeners" | grep -E 'openvpn' | grep -oE ':[0-9]+' | head -1 | tr -d ':')"
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
  echo
  echo "╔══════════════════════════════════════════════╗"
  echo "║  📊 ESTADO — Sistema: $(detect_system)          ║"
  echo "╚══════════════════════════════════════════════╝"
  local st
  st="$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo inactive)"
  echo -e "  Proxy ${SERVICE_NAME}: ${GREEN}${st}${NC}"
  if [[ "$st" == "active" ]]; then
    ss -tlnp 2>/dev/null | grep -E ":80 |:443 " | head -2 || true
  fi
  st="$(systemctl is-active badvpn 2>/dev/null || echo inactive)"
  echo -e "  BadVPN: ${GREEN}${st}${NC}"
  if [[ -f "$CONFIG_FILE" ]]; then
    echo "  Config: $CONFIG_FILE"
    grep -E "target_port|ovpn_port|v2ray_port|psiphon_port|wg_port" "$CONFIG_FILE" | tr -d ' ",'
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
  # 3) Ghost Manager
  rm -f /usr/local/bin/ghost-manager
  # 4) Binarios badvpn
  rm -f /bin/badvpn-udpgw
  echo -e "${GREEN}✅ Todo limpio — listo para instalar desde cero${NC}"
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
  if [[ -n "$(echo > /dev/tcp/configs.charly-tricks.dev/443) 2>/dev/null && echo ok)" ]]; then
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
  [[ ${#faltan[@]} -eq 0 ]] && { ok "Dependencias OK (curl/wget, python3, systemd)"; return 0; }

  warn "Faltan: ${faltan[*]} — instalando automáticamente..."
  pkg_install "${faltan[@]}" || true
  # Intento específico por distro si falló
  case "$(detect_pkg)" in
    apt) pkg_install curl python3 systemd systemd-sysv iproute2 net-tools || true ;;
    dnf|yum) pkg_install curl python3 systemd iproute net-tools || true ;;
    apk) pkg_install curl python3 systemd iproute2 || true ;;
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

# ─── Instalación AUTOMÁTICA (todo sin preguntar) ───
auto_install(){
  need_root
  echo -e "${GREEN}⚡ AUTOINSTALL: Ghost Proxy v14${NC}"
  # 0) dependencias primero
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
  # 7) arrancar todo
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
  systemctl restart "$SERVICE_NAME" 2>/dev/null || true
  sleep 2
  echo
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
  if systemctl is-active --quiet badvpn 2>/dev/null; then
    ok "BadVPN UDPGW :7300"
  fi
  [[ -x /usr/local/bin/ghost-manager ]] && ok "Ghost Manager (usuarios)"
  echo
  echo "💡 Escribí: ghost-manager   → para entrar al menú"
  echo
}

# ─── Menú principal ───
menu(){
  need_root
  while true; do
    banner
    show_status
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
    echo " [18] 🔴 Instalar Psiphon server (si no está)"
    echo " [19] 🚀 Instalar Xray V2Ray (si no está)"
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
      18) install_psiphon; press_enter ;;
      19) install_xray; press_enter ;;
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
