#!/usr/bin/env python3
"""
MelaVPN Admin Panel Server
Запуск: python3 panel-server.py
Доступ: http://VPS_IP:7979
"""

import json, os, subprocess, hashlib, getpass
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# ── Конфиг ────────────────────────────────────────────────────────────────────
PORT        = 7979
DATA_DIR    = Path('/etc/mela')
CONFIG_FILE = DATA_DIR / 'config.json'
SUB_FILE    = DATA_DIR / 'subscription.txt'
RELAYS_FILE = DATA_DIR / 'relays.json'
PASS_FILE   = DATA_DIR / 'password'

DATA_DIR.mkdir(parents=True, exist_ok=True)

# Пароль — задаётся при первом запуске
if not PASS_FILE.exists():
    print('\n🔐 Первый запуск — задай пароль для панели:')
    while True:
        pw = getpass.getpass('Пароль: ').strip()
        pw2 = getpass.getpass('Повтори: ').strip()
        if not pw:
            print('Пароль не может быть пустым')
        elif pw != pw2:
            print('Пароли не совпадают, попробуй снова')
        else:
            PASS_FILE.write_text(hashlib.sha256(pw.encode()).hexdigest())
            print('✅ Пароль сохранён\n')
            break
    PASSWORD_HASH = hashlib.sha256(pw.encode()).hexdigest()
else:
    PASSWORD_HASH = PASS_FILE.read_text().strip()

# Начальные файлы
if not CONFIG_FILE.exists():
    CONFIG_FILE.write_text(json.dumps({"proxy":"","sub":"","mirrors":[]}, indent=2))
if not SUB_FILE.exists():
    SUB_FILE.write_text('')
if not RELAYS_FILE.exists():
    RELAYS_FILE.write_text('[]')

# ── HTTP Handler ──────────────────────────────────────────────────────────────
class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): pass  # тихий лог

    def cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', 'X-Token, Content-Type')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS')

    def json_resp(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.cors()
        self.end_headers()
        self.wfile.write(body)

    def auth_ok(self):
        pw = self.headers.get('X-Token', '')
        return hashlib.sha256(pw.encode()).hexdigest() == PASSWORD_HASH

    def body(self):
        n = int(self.headers.get('Content-Length', 0))
        return json.loads(self.rfile.read(n)) if n else {}

    def do_OPTIONS(self):
        self.send_response(204)
        self.cors()
        self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path

        if not self.auth_ok():
            return self.json_resp({'error': 'unauthorized'}, 401)

        if path == '/api/config':
            return self.json_resp(json.loads(CONFIG_FILE.read_text()))

        if path == '/api/keys':
            return self.json_resp({'keys': SUB_FILE.read_text()})

        if path == '/api/relays':
            return self.json_resp(json.loads(RELAYS_FILE.read_text()))

        if path == '/api/status':
            relays = json.loads(RELAYS_FILE.read_text())
            statuses = []
            for r in relays:
                alive = os.system(f"ping -c1 -W1 {r['ip']} >/dev/null 2>&1") == 0
                statuses.append({**r, 'alive': alive})
            return self.json_resp({'relays': statuses, 'backend': 'ok'})

        self.json_resp({'error': 'not found'}, 404)

    def do_POST(self):
        path = urlparse(self.path).path

        if not self.auth_ok():
            return self.json_resp({'error': 'unauthorized'}, 401)

        data = self.body()

        if path == '/api/config':
            CONFIG_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False))
            return self.json_resp({'ok': True})

        if path == '/api/keys':
            SUB_FILE.write_text(data.get('keys', ''))
            return self.json_resp({'ok': True})

        if path == '/api/relays':
            relays = json.loads(RELAYS_FILE.read_text())
            relay = {'ip': data['ip'], 'label': data.get('label', data['ip'])}
            if not any(r['ip'] == relay['ip'] for r in relays):
                relays.append(relay)
                RELAYS_FILE.write_text(json.dumps(relays, indent=2))
            return self.json_resp({'ok': True})

        if path == '/api/relay/setup':
            ip = data.get('ip')
            password = data.get('password', '')
            backend_ip = data.get('backend_ip', '')
            if not ip or not backend_ip:
                return self.json_resp({'error': 'ip и backend_ip обязательны'}, 400)
            script = _relay_setup_script(backend_ip)
            result = _ssh_run(ip, password, script)
            return self.json_resp({'ok': result['ok'], 'output': result['output']})

        self.json_resp({'error': 'not found'}, 404)

    def do_DELETE(self):
        path = urlparse(self.path).path

        if not self.auth_ok():
            return self.json_resp({'error': 'unauthorized'}, 401)

        if path == '/api/relays':
            data = self.body()
            relays = [r for r in json.loads(RELAYS_FILE.read_text()) if r['ip'] != data.get('ip')]
            RELAYS_FILE.write_text(json.dumps(relays, indent=2))
            return self.json_resp({'ok': True})

        self.json_resp({'error': 'not found'}, 404)


# ── SSH helper ────────────────────────────────────────────────────────────────
def _ssh_run(ip, password, script):
    try:
        import paramiko
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(ip, username='root', password=password, timeout=15)
        _, stdout, stderr = ssh.exec_command(script, timeout=60)
        out = stdout.read().decode() + stderr.read().decode()
        ssh.close()
        return {'ok': True, 'output': out}
    except ImportError:
        # Если paramiko не установлен — возвращаем скрипт для ручного запуска
        return {'ok': False, 'output': f'paramiko не установлен.\nЗапусти вручную на relay:\n\n{script}'}
    except Exception as e:
        return {'ok': False, 'output': str(e)}


def _relay_setup_script(backend_ip):
    return f"""#!/bin/bash
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p
iptables -F; iptables -t nat -F
for PORT in 80 443 8443 10808; do
  iptables -t nat -A PREROUTING -p tcp --dport $PORT -j DNAT --to-destination {backend_ip}:$PORT
  iptables -t nat -A POSTROUTING -p tcp -d {backend_ip} --dport $PORT -j MASQUERADE
done
for PORT in 443 8443; do
  iptables -t nat -A PREROUTING -p udp --dport $PORT -j DNAT --to-destination {backend_ip}:$PORT
  iptables -t nat -A POSTROUTING -p udp -d {backend_ip} --dport $PORT -j MASQUERADE
done
apt-get install -y iptables-persistent -qq
netfilter-persistent save
echo "RELAY_OK"
"""


# ── Start ─────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print(f'MelaVPN backend → localhost:{PORT}')
    HTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
