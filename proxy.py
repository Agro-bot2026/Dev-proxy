#!/usr/bin/env python3
# CTManager WebSocket/HTTP Proxy - by CHARLY_TRICKS
# v13: SSH/OpenVPN/V2Ray/Psiphon + límite 1 conexión por UUID V2Ray
import socket, threading, json

CONFIG_FILE = "/etc/ctmanager/websocket/config.json"
active_conns = {}
active_uuid_conns = {}
active_lock = threading.Lock()

def load_config():
    try:
        with open(CONFIG_FILE) as f:
            return json.load(f)
    except:
        return {"target_host": "127.0.0.1", "target_port": 22, "payload": "200"}

# Registro de tráfico por sesión (MB por protocolo)
import sqlite3, threading as _th, os
_trafico_lock = _th.Lock()

def _registrar_trafico(protocolo, src_ip, rx_bytes, tx_bytes):
    try:
        db = '/etc/ctmanager/config/trafico.db'
        os.makedirs('/etc/ctmanager/config', exist_ok=True)
        with _trafico_lock:
            con = sqlite3.connect(db, timeout=5)
            con.execute("CREATE TABLE IF NOT EXISTS trafico (id INTEGER PRIMARY KEY AUTOINCREMENT, protocolo TEXT, src_ip TEXT, rx_bytes INTEGER DEFAULT 0, tx_bytes INTEGER DEFAULT 0, conexiones INTEGER DEFAULT 1, fecha TEXT DEFAULT (datetime('now')));")
            # Sumar en la fila del día actual para no llenar la DB
            hoy = __import__('datetime').datetime.now().strftime('%Y-%m-%d')
            fila = con.execute("SELECT id FROM trafico WHERE protocolo=? AND src_ip=? AND substr(fecha,1,10)=? LIMIT 1;", (protocolo, src_ip, hoy)).fetchone()
            if fila:
                con.execute("UPDATE trafico SET rx_bytes=rx_bytes+?, tx_bytes=tx_bytes+?, conexiones=conexiones+1 WHERE id=?;", (rx_bytes, tx_bytes, fila[0]))
            else:
                con.execute("INSERT INTO trafico (protocolo, src_ip, rx_bytes, tx_bytes, conexiones) VALUES (?,?,?,?,1);", (protocolo, src_ip, rx_bytes, tx_bytes))
            con.commit()
            con.close()
    except Exception:
        pass

def forward(src, dst, _ctx=None):
    rx = 0
    tx = 0
    try:
        while True:
            data = src.recv(4096)
            if not data: break
            rx += len(data)
            dst.sendall(data)
    except: pass
    finally:
        if _ctx:
            _registrar_trafico(_ctx.get('protocolo', 'ssh'), _ctx.get('src_ip', '0.0.0.0'), rx, tx)
        try: src.close()
        except: pass
        try: dst.close()
        except: pass

def split_http_header(data):
    idx = data.find(b"\r\n\r\n")
    if idx == -1:
        return data, b""
    return data[:idx+4], data[idx+4:]

def extraer_uuid_vless(first_packet):
    """VLESS: version(1B) + UUID(16B) + ... — devuelve el UUID en hex."""
    if len(first_packet) >= 17:
        return first_packet[1:17].hex()
    return None

def detect_target(first_packet, cfg):
    ssh_target = (cfg.get("target_host", "127.0.0.1"), int(cfg.get("target_port", 22)))
    ovpn_target = (cfg.get("ovpn_host", "127.0.0.1"), int(cfg.get("ovpn_port", 1194)))
    v2ray_target = (cfg.get("v2ray_host", "127.0.0.1"), int(cfg.get("v2ray_port", 8443)))
    psiphon_target = (cfg.get("psiphon_host", "127.0.0.1"), int(cfg.get("psiphon_port", 2223)))
    wg_target = (cfg.get("wg_host", "127.0.0.1"), int(cfg.get("wg_port", 51821)))
    if first_packet:
        # 1) Psiphon
        if first_packet.startswith(b"SSH-2.0-Go") or first_packet.startswith(b"SSH-2.0-Psiphon"):
            return psiphon_target
        # 2) SSH normal
        if first_packet.startswith(b"SSH-"):
            return ssh_target
        # 3) TLS ClientHello (V2Ray TLS)
        if first_packet[0] == 0x16 and len(first_packet) >= 2 and first_packet[1] == 0x03:
            return v2ray_target
        # 4) OpenVPN
        if first_packet[0] in (0x38, 0x08, 0x28):
            return ovpn_target
        if len(first_packet) >= 3 and first_packet[2] in (0x38, 0x08, 0x28):
            return ovpn_target
        if 0x38 in first_packet[:8] or 0x08 in first_packet[:8]:
            return ovpn_target
        # 5) WireGuard (handshake initiation: type=1 + 3 bytes reserved 0)
        if len(first_packet) >= 4 and first_packet[0] == 0x01 and first_packet[1:4] == b"\x00\x00\x00":
            return wg_target
        # 6) V2Ray RAW
        if first_packet[0] in (0x00, 0x01):
            return v2ray_target
    return ssh_target

def handle_client(client_socket, cfg):
    payloads = {
        "200": b"HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
        "101": b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
    }
    payload = payloads.get(str(cfg.get("payload", "200")), payloads["200"])
    max_conn = int(cfg.get("max_connections_per_user", 1))
    src_ip = client_socket.getpeername()[0]
    try:
        # 1) Payload HTTP
        client_socket.settimeout(3)
        chunks = b""
        try:
            while True:
                d = client_socket.recv(4096)
                if not d: break
                chunks += d
                if b"\r\n\r\n" in chunks:
                    break
                if len(chunks) > 16384:
                    break
        except socket.timeout:
            pass
        client_socket.settimeout(None)
        if not chunks:
            client_socket.close()
            return

        # 2) Responder 101
        client_socket.sendall(payload)

        # 3) Separar header
        header, first_packet = split_http_header(chunks)

        # 4) Si no vino, esperar después del 101
        if not first_packet:
            try:
                client_socket.settimeout(2)
                first_packet = client_socket.recv(4096)
            except socket.timeout:
                pass
            client_socket.settimeout(None)

        # 5) Detectar destino
        target_host, target_port = detect_target(first_packet, cfg)

        # 6) Límite por IP (todos los protocolos)
        with active_lock:
            actual = active_conns.get(src_ip, 0)
            if actual >= max_conn:
                client_socket.close()
                return
            active_conns[src_ip] = actual + 1

        # 7) Si es V2Ray: límite de 1 conexión POR UUID
        uuid_hex = None
        if target_port == 8443 and first_packet:
            uuid_hex = extraer_uuid_vless(first_packet)
            if uuid_hex:
                with active_lock:
                    if active_uuid_conns.get(uuid_hex, 0) >= 1:
                        # Ya hay una conexión activa con este UUID → rechazar
                        active_conns[src_ip] = max(0, active_conns.get(src_ip, 1) - 1)
                        if active_conns.get(src_ip, 0) == 0:
                            active_conns.pop(src_ip, None)
                        client_socket.close()
                        print(f"[CTManager WS] V2Ray rechazado: UUID {uuid_hex[:8]} ya tiene conexión activa", flush=True)
                        return
                    active_uuid_conns[uuid_hex] = active_uuid_conns.get(uuid_hex, 0) + 1

        # 8) Conectar
        dest = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            dest.connect((target_host, target_port))
        except Exception:
            with active_lock:
                active_conns[src_ip] = max(0, active_conns.get(src_ip, 1) - 1)
                if active_conns.get(src_ip, 0) == 0:
                    active_conns.pop(src_ip, None)
                if uuid_hex:
                    active_uuid_conns[uuid_hex] = max(0, active_uuid_conns.get(uuid_hex, 1) - 1)
                    if active_uuid_conns.get(uuid_hex, 0) == 0:
                        active_uuid_conns.pop(uuid_hex, None)
            client_socket.close()
            return

        if first_packet:
            dest.sendall(first_packet)

        def cleanup():
            try:
                with active_lock:
                    active_conns[src_ip] = max(0, active_conns.get(src_ip, 1) - 1)
                    if active_conns.get(src_ip, 0) == 0:
                        active_conns.pop(src_ip, None)
                    if uuid_hex:
                        active_uuid_conns[uuid_hex] = max(0, active_uuid_conns.get(uuid_hex, 1) - 1)
                        if active_uuid_conns.get(uuid_hex, 0) == 0:
                            active_uuid_conns.pop(uuid_hex, None)
            except: pass

        nom_proto = 'SSH' if target_port==22 else 'OpenVPN' if target_port==1194 else 'V2Ray' if target_port==8443 else 'Psiphon' if target_port==2223 else 'WireGuard' if target_port==51821 else 'UDP Custom' if target_port==1 else 'SSH'
        ctx_fwd1 = {'protocolo': nom_proto.lower().replace(' ', ''), 'src_ip': src_ip}
        ctx_fwd2 = {'protocolo': nom_proto.lower().replace(' ', ''), 'src_ip': src_ip}
        t1 = threading.Thread(target=forward, args=(client_socket, dest, ctx_fwd1), daemon=True)
        t2 = threading.Thread(target=forward, args=(dest, client_socket, ctx_fwd2), daemon=True)
        t1.start()
        t2.start()
        def watch():
            t1.join(); t2.join(); cleanup()
        threading.Thread(target=watch, daemon=True).start()
        nom = 'SSH' if target_port==22 else 'OpenVPN' if target_port==1194 else 'V2Ray' if target_port==8443 else 'Psiphon'
        extra = f" uuid={uuid_hex[:8]}" if uuid_hex else ""
        print(f"[CTManager WS] Tunel {src_ip} -> {target_host}:{target_port} ({nom}){extra}", flush=True)
    except Exception as e:
        try: client_socket.close()
        except: pass

def start_server(port, cfg):
    srv = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        srv.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)  # dual-stack v4+v6
    except Exception:
        pass
    try:
        srv.bind(('::', port))
        srv.listen(200)
        print(f"[CTManager WS] Puerto {port} -> SSH:22 / OpenVPN:1194 / V2Ray:8443 / Psiphon:2223", flush=True)
        while True:
            client, addr = srv.accept()
            threading.Thread(target=handle_client, args=(client, cfg), daemon=True).start()
    except OSError as e:
        print(f"[CTManager WS] Error puerto {port}: {e}", flush=True)

if __name__ == "__main__":
    cfg = load_config()
    ports = []
    if cfg.get("enable_ws", True) and cfg.get("ws_port"):
        ports.append(int(cfg["ws_port"]))
    if cfg.get("enable_wss", True) and cfg.get("wss_port"):
        ports.append(int(cfg["wss_port"]))
    if not ports:
        ports = [8080]
    threads = []
    for p in set(ports):
        t = threading.Thread(target=start_server, args=(p, cfg), daemon=True)
        t.start()
        threads.append(t)
    for t in threads:
        t.join()
