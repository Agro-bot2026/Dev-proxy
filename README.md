# 🦇 Ghost Proxy v14 — Multi-Protocolo

Instalador automático de proxy WebSocket en :80 con detección de protocolos:

**SSH · Psiphon · V2Ray (RAW+TLS) · OpenVPN · WireGuard**

## 🚀 Instalación (una línea)

```bash
bash <(curl -s https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh) auto
```

O con wget (si no hay curl):

```bash
wget -qO- https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh | bash -s auto
```

**El script instala TODO automáticamente**: dependencias (curl, python3, systemd — compatible Debian/Ubuntu/Rocky/Alma/CentOS/Alpine/openSUSE/Arch), proxy.py, config.json, servicio systemd y BadVPN UDPGW.

## 🖥️ Menú interactivo (14 opciones)

```bash
bash <(curl -s https://raw.githubusercontent.com/Agro-bot2026/Dev-proxy/main/ghost-proxy-v14.sh)
```

- Instalar/actualizar proxy
- Liberar puertos 80/443
- BadVPN UDPGW
- Logs · Firewall UFW · Editar config.json · Desinstalar

## 📁 Archivos

| Archivo | Qué es |
|---------|--------|
| `ghost-proxy-v14.sh` | Instalador (autoinstall + menú) |
| `proxy.py` | Proxy multi-protocolo (detección por bytes) |
| `badvpn-udpgw` | BadVPN UDP gateway |

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
