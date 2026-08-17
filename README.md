# 🦇 Ghost Proxy v14 — Multi-Protocolo

Instalador automático tipo ADMRufu con **menú completo para novatos**:

**SSH · Psiphon · V2Ray (RAW+TLS) · OpenVPN · WireGuard · UDP Custom**

![Menú del script](menu-ghost-proxy-v3.png)

## 🚀 Instalación (una línea — instala TODO solo)

```bash
bash <(curl -s https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh) auto
```

O con wget (si no hay curl):

```bash
wget -qO- https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh | bash -s auto
```

**El script instala todo automáticamente, sin tocar nada a mano:**
1. ✅ Dependencias (curl, python3, systemd — compatible Debian/Ubuntu/Rocky/Alma/CentOS/Alpine/openSUSE/Arch)
2. ✅ Detecta los servicios del VPS (SSH/V2Ray/Psiphon/OpenVPN/WireGuard)
3. ✅ Proxy multi-protocolo en :80
4. ✅ BadVPN UDPGW
5. ✅ Ghost Manager (menú de usuarios)

## 🖥️ Menú (para crear usuarios y administrar)

```bash
bash <(curl -s https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh)
```

```
🦇 Ghost VPN - Administrador de Usuarios
  Bienvenido! Acá creás y gestionás los accesos VPN.
  Cada usuario recibe una CONTRASEÑA y una FECHA de vencimiento.
  Cuando vence, el acceso se corta solo. Podés renovar cuando quieras.

  👤 USUARIOS
  1) 📊 Estado del sistema
  2) 👤 Crear usuario SSH/OpenVPN
  3) 🚀 Crear usuario V2Ray
  4) 🛰️  Crear usuario UDP Custom
  5) 👥 Listar usuarios (ver todos)
  6) 🔄 Renovar usuario (agregar más días)
  7) ✏️  Editar usuario (cambiar contraseña)
  8) 🗑️  Eliminar usuario (cortar acceso)
  🌐 SERVICIOS
  9) 🔐 Estado WireGuard
  10) 🌐 Panel web (http://IP:8303)
  0) Salir
```

## 📁 Archivos del repo

| Archivo | Qué es |
|---------|--------|
| `ghost-proxy-v14.sh` | Instalador (autoinstall + menú) |
| `ghost-manager` | Menú de usuarios (crear/renovar/editar/eliminar) |
| `proxy.py` | Proxy multi-protocolo (detección por bytes) |
| `badvpn-udpgw` | BadVPN UDP gateway |
| `menu-ghost-proxy-v3.png` | Captura del menú |

## ⚙️ Config (`/etc/ctmanager/websocket/config.json`)

```json
{
  "ws_port": 80,
  "target_port": 22,      ← SSH
  "psiphon_port": 2223,   ← Psiphon
  "v2ray_port": 8443,     ← V2Ray
  "ovpn_port": 1194,      ← OpenVPN
  "wg_port": 51821        ← WireGuard
}
```

## 🔄 Detección de protocolo (primeros bytes)

| Protocolo | Detección | Destino |
|-----------|-----------|---------|
| Psiphon | `SSH-2.0-Go` | psiphon_port |
| SSH | `SSH-` | target_port |
| V2Ray TLS | `0x16 0x03` | v2ray_port |
| OpenVPN | `0x38/0x08/0x28` | ovpn_port |
| WireGuard | `0x01 0x00 0x00 0x00` | wg_port |
| V2Ray RAW | `0x00/0x01` | v2ray_port |
