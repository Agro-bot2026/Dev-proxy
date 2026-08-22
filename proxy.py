#!/usr/bin/env python3
# CTManager WebSocket/HTTP Proxy - by CHARLY_TRICKS
# v17: + Brook wsserver (detección por handshake WS /ws)
import socket, threading, json

CONFIG_FILE = "/etc/ctmanager/websocket/config.json"
active_conns = {}
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

# ─── CUOTA DE DATOS: consumo acumulado de una IP (bytes) en los últimos N días ───
def _consumo_ip(src_ip, dias=30):
    try:
        db = '/etc/ctmanager/config/trafico.db'
        con = sqlite3.connect(db, timeout=5)
        row = con.execute(
            "SELECT SUM(rx_bytes + tx_bytes) FROM trafico WHERE src_ip=? AND fecha >= datetime('now', ?);",
            (src_ip, f'-{dias} days')).fetchone()
        con.close()
        return row[0] or 0
    except Exception:
        return 0

# ─── CUOTA: ¿la IP superó el límite? (quota_gb en config.json, 0 = sin límite) ───
def _quota_excedida(src_ip, cfg):
    try:
        quota_gb = float(cfg.get("quota_gb", 0) or 0)
        if quota_gb <= 0:
            return False
        dias = int(cfg.get("quota_dias", 30))
        usado = _consumo_ip(src_ip, dias)
        return usado >= quota_gb * 1024 * 1024 * 1024
    except Exception:
        return False

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
    idx = data.rfind(b"\r\n\r\n")
    if idx == -1:
        return data, b""
    return data[:idx+4], data[idx+4:]

def extraer_uuid_vless(first_packet):
    """VLESS: version(1B) + UUID(16B) + ... — devuelve el UUID en hex."""
    if len(first_packet) >= 17:
        return first_packet[1:17].hex()
    return None

def es_handshake_brook(first_packet):
    """Detecta el handshake WebSocket de Brook (GET /ws + Upgrade: websocket + Sec-WebSocket-Key)"""
    if not first_packet:
        return False
    probe = first_packet[:300]
    if probe.startswith(b"GET /ws") or probe.startswith(b"GET /ws/"):
        return (b"Upgrade: websocket" in probe) and (b"Sec-WebSocket-Key" in probe)
    return False

def detect_target(first_packet, cfg):
    ssh_target = (cfg.get("target_host", "127.0.0.1"), int(cfg.get("target_port", 22)))
    # Si hay sshgo configurado, el SSH normal va al sshgo (banner dinámico por usuario)
    sshgo_port = int(cfg.get("sshgo_port", 0) or 0)
    if sshgo_port:
        ssh_target = (cfg.get("sshgo_host", "127.0.0.1"), sshgo_port)
    # Si no hay sshgo pero sí dropbear, el SSH va a dropbear (SSH liviano)
    elif int(cfg.get("dropbear_port", 0) or 0):
        ssh_target = (cfg.get("dropbear_host", "127.0.0.1"), int(cfg.get("dropbear_port", 444)))
    ovpn_target = (cfg.get("ovpn_host", "127.0.0.1"), int(cfg.get("ovpn_port", 1194)))
    v2ray_target = (cfg.get("v2ray_host", "127.0.0.1"), int(cfg.get("v2ray_port", 8443)))
    psiphon_target = (cfg.get("psiphon_host", "127.0.0.1"), int(cfg.get("psiphon_port", 2223)))
    wg_target = (cfg.get("wg_host", "127.0.0.1"), int(cfg.get("wg_port", 51821)))
    brook_target = (cfg.get("brook_host", "127.0.0.1"), int(cfg.get("brook_port", 18999)))
    slowdns_target = (cfg.get("slowdns_host", "127.0.0.1"), int(cfg.get("slowdns_port", 5301)))
    if first_packet:
        # 0) Brook wsserver (handshake WS: GET /ws + Upgrade)
        if es_handshake_brook(first_packet):
            return brook_target
        # 0b) SlowDNS (query DNS: flags 0x0100 + QDCOUNT 0x0001 en bytes 2-5)
        if len(first_packet) >= 6 and first_packet[2:4] == b"\x01\x00" and first_packet[4:6] == b"\x00\x01":
            return slowdns_target
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
        # 0b) CUOTA DE DATOS
        if _quota_excedida(src_ip, cfg):
            try:
                client_socket.sendall(b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n")
            except Exception:
                pass
            print(f"[CTManager WS] {src_ip} rechazada: superó cuota de datos ({cfg.get('quota_gb',0)}GB)", flush=True)
            client_socket.close()
            return

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

        # 0) Ruta especial: descargar .ovpn
        if b"GET /ovpn/" in chunks:
            try:
                import os
                ruta = chunks.split(b" ")[1].decode(errors="replace").lstrip("/")
                nombre = ruta.split("/")[-1]
                if nombre.endswith(".ovpn"):
                    base = "/etc/ctmanager/ovpn"
                    archivo = os.path.join(base, nombre)
                    if os.path.realpath(archivo).startswith(os.path.realpath(base)) and os.path.isfile(archivo):
                        data = open(archivo, "rb").read()
                        resp = b"HTTP/1.1 200 OK\r\nContent-Type: application/x-openvpn-profile\r\nContent-Disposition: attachment; filename=" + nombre.encode() + b"\r\nContent-Length: " + str(len(data)).encode() + b"\r\n\r\n" + data
                        client_socket.sendall(resp)
                        client_socket.close()
                        return
            except Exception:
                pass
            try:
                client_socket.sendall(b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")
            except Exception:
                pass
            client_socket.close()
            return

        # 1b) Si el PRIMER paquete YA es un handshake WS de Brook (app oficial conecta directo,
        #     sin payload HTTP Custom): NO responder 101 nosotros — Brook debe responder su propio
        #     101 con Sec-WebSocket-Accept válido, o la app oficial lo rechaza.
        es_brook_directo = es_handshake_brook(chunks)

        # 2) Responder 101 (solo si NO es Brook directo — para Brook directo, Brook responde)
        if not es_brook_directo:
            client_socket.sendall(payload)

        # 3) Separar header (primer \r\n\r\n)
        header, first_packet = split_http_header(chunks)

        # 4) Si no vino, esperar después del 101
        if not first_packet:
            try:
                client_socket.settimeout(2)
                first_packet = client_socket.recv(4096)
            except socket.timeout:
                pass
            client_socket.settimeout(None)

        # 4b) Descartar bloques HTTP residuales SOLO si NO es Brook:
        #     Para Brook, el handshake WS (GET /ws) debe llegar COMPLETO al server
        if first_packet and not es_handshake_brook(first_packet):
            probe = first_packet[:32]
            if probe.startswith((b"GET", b"ACL", b"POST", b"CONNECT", b"PUT", b"HEAD", b"OPTIONS", b"[", b"Upgrade")):
                idx = first_packet.rfind(b"\r\n\r\n")
                if idx != -1:
                    first_packet = first_packet[idx+4:]
                else:
                    first_packet = b""

        # 5) Detectar destino (si es Brook directo, forzar Brook aunque first_packet quede vacío
        #    tras el split — el handshake completo vive en chunks)
        if es_brook_directo:
            target_host = cfg.get("brook_host", "127.0.0.1")
            target_port = int(cfg.get("brook_port", 18999))
        else:
            target_host, target_port = detect_target(first_packet, cfg)

        # 6) Límite por IP
        with active_lock:
            actual = active_conns.get(src_ip, 0)
            if actual >= max_conn:
                client_socket.close()
                return
            active_conns[src_ip] = actual + 1

        # 8) Conectar
        dest = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            dest.connect((target_host, target_port))
        except Exception:
            with active_lock:
                active_conns[src_ip] = max(0, active_conns.get(src_ip, 1) - 1)
                if active_conns.get(src_ip, 0) == 0:
                    active_conns.pop(src_ip, None)
            client_socket.close()
            return

        # Si es Brook y el handshake WS vino en chunks (app oficial directa), reenviar el
        # chunks COMPLETO a Brook (el handshake va en header tras el split — no perderlo)
        if es_brook_directo:
            dest.sendall(chunks)
        elif first_packet:
            dest.sendall(first_packet)

        def cleanup():
            try:
                with active_lock:
                    active_conns[src_ip] = max(0, active_conns.get(src_ip, 1) - 1)
                    if active_conns.get(src_ip, 0) == 0:
                        active_conns.pop(src_ip, None)
            except: pass

        nom_proto = 'SSH' if target_port==22 else 'OpenVPN' if target_port==1194 else 'V2Ray' if target_port==8443 else 'Psiphon' if target_port==2223 else 'WireGuard' if target_port==51821 else 'Brook' if target_port==18999 else 'SSH'
        ctx_fwd1 = {'protocolo': nom_proto.lower(), 'src_ip': src_ip}
        ctx_fwd2 = {'protocolo': nom_proto.lower(), 'src_ip': src_ip}
        t1 = threading.Thread(target=forward, args=(client_socket, dest, ctx_fwd1), daemon=True)
        t2 = threading.Thread(target=forward, args=(dest, client_socket, ctx_fwd2), daemon=True)
        t1.start()
        t2.start()
        def watch():
            t1.join(); t2.join(); cleanup()
        threading.Thread(target=watch, daemon=True).start()
        print(f"[CTManager WS] Tunel {src_ip} -> {target_host}:{target_port} ({nom_proto})", flush=True)
    except Exception as e:
        try: client_socket.close()
        except: pass

def start_server(port, cfg):
    srv = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        srv.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
    except Exception:
        pass
    try:
        srv.bind(('::', port))
        srv.listen(200)
        print(f"[CTManager WS] Puerto {port} -> SSH:22 / OpenVPN:1194 / V2Ray:8443 / Psiphon:2223 / Brook:18999", flush=True)
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
