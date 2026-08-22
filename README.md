# 🦇 Ghost Proxy v14 — Multi-Protocolo

Instalador automático con **menú completo para novatos**:

**SSH · Psiphon · V2Ray · OpenVPN · WireGuard · UDP Custom · Brook · Dropbear · Squid · Shadowsocks**

![Menú del script](menu-ghost-proxy-v3.png)

## 🎨 Banner del Ghost Manager (estilo confirmado)

El banner del `ghost-manager` usa la fuente **`ansi_shadow`** de pyfiglet (bloques con sombra y esquinas `╗╔╝║═`, efecto 3D) con el texto **EPRO.HC** en naranja:

```bash
# Generarlo con:
#   /usr/bin/python3 -m pip install pyfiglet --break-system-packages
python3 -c "import pyfiglet; print(pyfiglet.figlet_format('EPRO.HC', font='ansi_shadow'))"
```

- **Fuente**: `ansi_shadow` (la misma que usaba el banner "GHOST" original)
- **Color**: `ORANGE='\033[38;5;208m'` (naranja intenso)
- **Texto**: `EPRO.HC` todo en mayúsculas (con la E bien formada, no confundir con G)
- **Menú de opciones**: números en fucsia `FUCSIA='\033[1;35m'`
- **Subtítulo**: `🦇 Ghost VPN - Administrador de Usuarios` en azul/cian

## 🚀 Instalación (una línea — instala TODO solo)

```bash
bash <(curl -s https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh) auto
```

O con wget (si no hay curl):

```bash
wget -qO- https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh | bash -s auto
```

**El script instala todo automáticamente, sin tocar nada a mano:**

1. ✅ `apt update + upgrade` del sistema (como todos los scripts)
2. ✅ Dependencias (curl, python3, systemd — Debian/Ubuntu/Rocky/Alma/CentOS/Alpine/openSUSE/Arch)
3. ✅ Detecta los servicios del VPS (SSH/V2Ray/Psiphon/OpenVPN/WireGuard)
4. ✅ Proxy multi-protocolo en :80
5. ✅ **Psiphon** (:2223 — banner SSH-2.0-Psiphon + IP pública configurados)
6. ✅ **Xray V2Ray** (:8443 — con xray_uuid.sh para usuarios)
7. ✅ **OpenVPN** (:1194 — certificados + NAT MASQUERADE + forwarding, los clientes navegan)
8. ✅ **WireGuard** (:51820)
9. ✅ BadVPN UDPGW (:7300)
10. ✅ Ghost Manager (menú de usuarios)
11. ✅ Te pide el **dominio** del VPS (para los links de usuarios)
12. ✅ **Abre TODOS los puertos en el firewall** (UFW/firewalld/iptables)
13. ✅ **SSL 443 → proxy WS** (método TLS, stunnel — opcional)

## 🔥 Puertos que abre en el firewall (automático)

| Protocolo | TCP | UDP |
|-----------|:---:|:---:|
| Proxy WS | 80 | 80 |
| SSH | 22 | — |
| Psiphon | 2223 | 2223 |
| Xray V2Ray | 8443 | 8443 |
| OpenVPN | 1194 | 1194 |
| WireGuard | 51820 | 51820 |
| BadVPN | — | 7300 |
| SSL TLS | 443 | — |

Detecta el firewall solo: **UFW** (Debian/Ubuntu), **firewalld** (Rocky/CentOS/Alma), **iptables** (cualquiera). Si UFW está inactivo, no lo fuerza (no corta tu SSH).

## 🔒 SSL 443 → proxy WebSocket (método TLS, sin Caddy)

Igual que en producción (donde CloudRun termina el TLS y reenvía desempaquetado al :80), el instalador puede poner **stunnel**: termina TLS en :443 y reenvía al proxy WS :80.

```
Cliente (HTTP Custom, método TLS)
   ↓ TLS 443
stunnel (cert autofirmado para tu dominio)
   ↓ desempaquetado
Proxy WS :80 → rutea a OpenVPN/SSH/etc.
```

Al instalar te pregunta `🌐 ¿Instalar SSL 443 → proxy (método TLS)? [s/N]`, o en el menú con la opción **18** (`🔒 Instalar SSL 443 → proxy`).

**Detalles técnicos** (ya resueltos en el script):
- `foreground = yes` va GLOBAL (al inicio del conf), no dentro del servicio — si no, stunnel daemoniza y systemd lo reinicia en loop
- Libera el 443 si lo ocupa Caddy/nginx/stunnel4 del paquete antes de arrancar
- Certificado autofirmado en `/etc/stunnel/eprohc.pem` (el .hc usa `allow_insecure: true`)
- Servicio: `stunnel-epro` (systemd, autoarranque)

## 🔄 Actualización del script (auto-update)

El instalador tiene **sistema de actualización integrado**:

- **Aviso automático**: al entrar al menú, compara su versión con la de GitHub y avisa si hay una nueva
- **Opción 19**: `🔄 ACTUALIZAR Ghost Proxy` — descarga, verifica, reemplaza y ejecuta la versión nueva

```bash
# Ver la versión actual
grep '^VERSION=' ghost-proxy-v14.sh
```

## 🧹 Instalación limpia (borra todo lo anterior)

```bash
curl -s "https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh" -o /tmp/g.sh && bash /tmp/g.sh limpio
```

Borra servicios, configs y binarios viejos, y reinstala desde cero.

## 🖥️ Menú (para crear usuarios y administrar)

```bash
bash <(curl -s https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh)
```

O después de instalar:

```bash
ghost-manager
```

```
🦇 Ghost VPN - Administrador de Usuarios
  Bienvenido! Acá creás y gestionás los accesos VPN.
  Cada usuario recibe una CONTRASEÑA y una FECHA de vencimiento.
  Cuando vence, el acceso se corta solo. Podés renovar cuando quieras.

  👤 USUARIOS
  1) 📊 Estado del sistema
  2) 👤 Crear usuario SSH
  3) 🛡️  Crear usuario OpenVPN (config armado con payload + CA)
  4) 🚀 Crear usuario V2Ray
  5) 🛰️  Crear usuario UDP Custom
  6) 👥 Listar usuarios (ver todos)
  7) 🔄 Renovar usuario (agregar más días)
  8) ✏️  Editar usuario (cambiar contraseña)
  9) 🗑️  Eliminar usuario (cortar acceso)
  🌐 SERVICIOS
  10) 🌐 Estado Psiphon (server entry + HEX)
  11) 🔐 Estado WireGuard
  12) 🌐 Panel web (http://IP:8303)
  0) Salir
```

**Menú del instalador** (además del ghost-manager):

```
 [1] 🛠️  Instalar / Actualizar proxy
 [2] 🔓 Liberar puertos 80/443
 [3] 🟣 BadVPN UDPGW (UDP Custom)
 [4] ⛔  Detener servicio
 [5] ▶️  Reanudar servicio
 [6] 🔄 Reiniciar servicio
 [7] 📜 Ver logs
 [8] ✏️  Editar config.json (nano)
 [9] 🛡️  Firewall UFW
 [10] 🧨 Desinstalar servicio
 [11] 👤 Crear usuario SSH/OpenVPN
 [12] 🚀 Crear usuario V2Ray
 [13] 🌐 Estado Psiphon
 [14] 👥 Listar usuarios
 [15] 🗑️  Eliminar usuario
 [16] 🛰️  Crear usuario UDP Custom
 [17] 🔐 Estado WireGuard
 [18] 🔒 Instalar SSL 443 → proxy (método TLS)
 [19] 🔄 ACTUALIZAR Ghost Proxy (si hay versión nueva)
 [0] Salir
```

**Al crear un usuario OpenVPN** te genera todo armado: payload, proxy remoto, .ovpn con la CA, y un enlace para descargar el archivo (`http://dominio/ovpn/usuario.ovpn`).

## 📁 Archivos del repo

| Archivo | Qué es |
|---------|--------|
| `ghost-proxy-v14.sh` | Instalador (auto / limpio / menú) — instala sshgo + banner automáticamente |
| `ghost-manager` | Menú de usuarios (16 opciones: consumo UUID/Psiphon, eliminar VLESS, editar banner) |
| `proxy.py` | Proxy multi-protocolo (detección por bytes + sirve /ovpn/ + ruteo SSH→sshgo) |
| `sshgo-linux-amd64` | Servidor SSH en Go con banner dinámico (USER/EXP/DAYS/TRF/LIMIT) |
| `brook-linux-amd64` | Brook wsserver (proxy TCP/UDP estilo V2Ray — opcional, útil fuera de zero-rating) |
| `psiphon-server` | Binario de Psiphon server |
| `xray` | Binario de Xray (V2Ray) |
| `xray_uuid.sh` | Gestión de UUIDs de Xray |
| `badvpn-udpgw` | BadVPN UDP gateway |
| `menu-ghost-proxy-v3.png` | Captura del menú |

## ⚙️ Config (`/etc/ctmanager/websocket/config.json`)

```json
{
  "ws_port": 80,
  "target_port": 22,        ← SSH (va al sshgo si sshgo_port > 0)
  "sshgo_host": "127.0.0.1",
  "sshgo_port": 2200,       ← sshgo (banner dinámico en log HTTP Custom)
  "psiphon_host": "IP_PÚBLICA",
  "psiphon_port": 2223,     ← Psiphon
  "v2ray_port": 8443,       ← V2Ray
  "ovpn_port": 1194,        ← OpenVPN
  "wg_port": 51821          ← WireGuard
}
```

El dominio del VPS se guarda en `/etc/ctmanager/websocket/dominio` (se usa para los links de usuarios).

## 🔄 Detección de protocolo (primeros bytes)

| Protocolo | Detección | Destino |
|-----------|-----------|---------|
| Psiphon | `SSH-2.0-Go` / `SSH-2.0-Psiphon` | psiphon_port |
| SSH | `SSH-` | sshgo_port (2200) si está configurado, si no target_port |
| V2Ray TLS | `0x16 0x03` | v2ray_port |
| OpenVPN | `0x38/0x08/0x28` | ovpn_port |
| WireGuard | `0x01 0x00 0x00 0x00` | wg_port |
| V2Ray RAW | `0x00/0x01` | v2ray_port |
| Brook | `GET /ws` + `Upgrade: websocket` | brook_port (18999) |
| SSH (dropbear) | `SSH-` si sshgo_port=0 y dropbear_port>0 | dropbear_port (444) |

El proxy también maneja payloads con `[split]` (2 bloques HTTP) — corta en el último `\r\n\r\n` para que el paquete del túnel llegue limpio al destino.


## 🖥️ SSHGO — Banner dinámico en el log de HTTP Custom

El instalador instala **sshgo** (servidor SSH en Go, binario estático) que autentica contra `ssh_users.db` y manda un **banner personalizado** en el handshake SSH. HTTP Custom lo muestra en su log al conectar:

```
✅ EPRO.HC ✅
👤 USUARIO: prueba1
📅 VENCE: 2026-09-21
⏳ DÍAS: 29
📊 TRÁFICO: 0.00 GB
🎯 LÍMITE: 50 GB
⚡ ESTADO: activo
```

- **Puerto**: `127.0.0.1:2200` (solo local — el proxy :80 lo alcanza, NO se abre al firewall)
- **Plantilla editable**: `/etc/ctmanager/config/sshgo_banner.txt`
  - Placeholders: `USER EXP DAYS TRF LIMIT` + `{name} {expire} {days} {traffic} {limit} {status}`
  - Soporta HTML: `<font color='green'>`, `<span style="background-color:...">`, `<b>`, `<br/>`
  - ⚠️ HTTP Custom NO renderiza colores ANSI ni caracteres de caja (╔═╗█) — usar HTML o ASCII puro
- **Editar banner**: `ghost-manager` → opción 19 (marca + idioma ES/EN/PT + color, o nano)
- **NOTA**: el banner se ve en modo **SSH** (HTTP Custom muestra el banner del server). En modo Psiphon/V2Ray/OVPN HTTP Custom NO muestra banners del server (limitación de la app).

## 🛠️ Ghost Manager — opciones nuevas

| Opción | Función |
|--------|---------|
| 16 | 📊 Consumo por UUID VLESS (top conexiones desde los logs) |
| 17 | 🗑️ Eliminar usuario VLESS (DB + Xray + links + mata conexiones) |
| 18 | 📊 Consumo Psiphon por IP |
| 19 | 🎨 Editar banner SSHGO (guiado: marca/idioma/color o nano) |

## 🔧 Fixes importantes (2026-08-22)

- **ulimit 65535** en pymanager/sshgo (antes 1024 → con grupos grandes de 1000+ personas se saturaba: "too many open files")
- **getpeername en try** (fix error 107 en avalanchas de conexiones)
- **Sin límite por UUID** en V2Ray (HTTP Custom abre 3-10 conexiones simultáneas con el mismo UUID — el límite las mataba)

## 📋 Checkuser (endpoint listo)

El panel web (`ghost-panel` repo privado) tiene `/checkuser` que responde DDMMYYYY (GET y POST). Si tu versión de HTTP Custom tiene checkuser (URL+puerto), configurá:
`http://IP:8303/checkuser` · puerto `8303`


## 🟦 Brook (wsserver — opcional)

El instalador incluye **Brook** (proxy TCP/UDP estilo V2Ray, modo `wsserver`) — un protocolo que casi ningún script trae.

- **Puerto**: `127.0.0.1:18999` (solo local — lo alcanza el proxy :80)
- **Detección**: `GET /ws` + `Upgrade: websocket` → brook_port
- **Password**: aleatoria, guardada en `/etc/ctmanager/config/brook_password`
- **Link**: `brook://wsserver?password=<pass>&wsserver=ws://IP:80/ws` (para la app oficial de Brook)
- **Útil**: en países donde no aplica zero-rating, Brook funciona como VPN directa sin payload
- ⚠️ La app oficial de Brook no tiene campo de payload → **sin zero-rating** (el método de bughost requiere HTTP Custom + payload). Por eso es un protocolo complementario, no reemplaza a los demás.
- Instalar solo: `ghost-proxy-v14.sh` → opción 20


## 🐻 Dropbear (SSH liviano :444)

Servidor SSH liviano que soporta **más conexiones simultáneas** que OpenSSH y tiene fingerprint distinta:

- **Puerto**: `444` (el 22 sigue siendo OpenSSH)
- **Uso**: cuentas SSH directo a `IP:444` (o vía proxy :80 si desactivás sshgo)
- **Alternar**: en `config.json`, `sshgo_port: 0` + `dropbear_port: 444` → el proxy manda SSH a dropbear
- Instalar solo: `ghost-proxy-v14.sh` → opción 21

## 🕷️ Squid (proxy HTTP :1080/:3128)

Proxy HTTP clásico para navegación:

- **Puertos**: `1080` y `3128`
- **Uso**: configurar el navegador/dispositivo con proxy `IP:3128` (o `1080`)
- Instalar solo: `ghost-proxy-v14.sh` → opción 22


## 🕶️ Shadowsocks (proxy cifrado :8388)

Proxy cifrado clásico (inbound de Xray):

- **Puerto**: `8388` (público — conexión directa, sin pasar por el :80)
- **Método**: aes-256-gcm · **Password**: `/etc/ctmanager/config/ss_password`
- **Link**: `ss://<base64>@IP:8388#Ghost-SS` (ghost-manager → opción 20)
- **Uso**: HTTP Custom → Shadowsocks → server IP:8388
- ⚠️ **Sin payload** — HTTP Custom no usa bughost en Shadowsocks y el protocolo no tiene firma detectable (cifrado desde byte 0), así que NO aplica zero-rating. Es un protocolo complementario (funciona en cualquier país, como Brook).
- Instalar solo: `ghost-proxy-v14.sh` → opción 23
- **Usuarios individuales** (como VLESS): ghost-manager → opción 21 (crear, genera password+link) y 22 (eliminar, corta acceso)
- **DB**: `/etc/ctmanager/config/ss_users.db` · **Script**: `ss_users.sh` (add/remove/list/reload)
