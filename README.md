# 🦇 Ghost Proxy v14 — Multi-Protocolo

Instalador automático tipo ADMRufu con **menú completo para novatos**:

**SSH · Psiphon · V2Ray · OpenVPN · WireGuard · UDP Custom**

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

1. ✅ Dependencias (curl, python3, systemd — Debian/Ubuntu/Rocky/Alma/CentOS/Alpine/openSUSE/Arch)
2. ✅ Detecta los servicios del VPS (SSH/V2Ray/Psiphon/OpenVPN/WireGuard)
3. ✅ Proxy multi-protocolo en :80
4. ✅ **Psiphon** (:2223 — banner SSH-2.0-Psiphon + IP pública configurados)
5. ✅ **Xray V2Ray** (:8443 — con xray_uuid.sh para usuarios)
6. ✅ **OpenVPN** (:1194 — certificados + NAT MASQUERADE + forwarding, los clientes navegan)
7. ✅ **WireGuard** (:51820)
8. ✅ BadVPN UDPGW (:7300)
9. ✅ Ghost Manager (menú de usuarios)
10. ✅ Te pide el **dominio** del VPS (para los links de usuarios)

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

**Al crear un usuario OpenVPN** te genera todo armado: payload, proxy remoto, .ovpn con la CA, y un enlace para descargar el archivo (`http://dominio/ovpn/usuario.ovpn`).

## 📁 Archivos del repo

| Archivo | Qué es |
|---------|--------|
| `ghost-proxy-v14.sh` | Instalador (auto / limpio / menú) |
| `ghost-manager` | Menú de usuarios (crear/renovar/editar/eliminar) |
| `proxy.py` | Proxy multi-protocolo (detección por bytes + sirve /ovpn/) |
| `psiphon-server` | Binario de Psiphon server |
| `xray` | Binario de Xray (V2Ray) |
| `xray_uuid.sh` | Gestión de UUIDs de Xray |
| `badvpn-udpgw` | BadVPN UDP gateway |
| `menu-ghost-proxy-v3.png` | Captura del menú |

## ⚙️ Config (`/etc/ctmanager/websocket/config.json`)

```json
{
  "ws_port": 80,
  "target_port": 22,        ← SSH
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
| SSH | `SSH-` | target_port |
| V2Ray TLS | `0x16 0x03` | v2ray_port |
| OpenVPN | `0x38/0x08/0x28` | ovpn_port |
| WireGuard | `0x01 0x00 0x00 0x00` | wg_port |
| V2Ray RAW | `0x00/0x01` | v2ray_port |

El proxy también maneja payloads con `[split]` (2 bloques HTTP) — corta en el último `\r\n\r\n` para que el paquete del túnel llegue limpio al destino.
