#!/usr/bin/env python3
"""
MelaVPN Server — один файл, один запуск.
Запуск: python3 server.py
Порт:  10808  (приложение читает /config.json отсюда)
Панель: http://ВАШ_IP:10808
"""

import json, hashlib, getpass, os, sys
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

PORT     = int(os.environ.get('PORT', 10808))
DATA_DIR = Path(os.environ.get('DATA_DIR', '/etc/mela'))
DATA_DIR.mkdir(parents=True, exist_ok=True)

CFG_FILE  = DATA_DIR / 'config.json'
PASS_FILE = DATA_DIR / 'password'
KEYS_FILE = DATA_DIR / 'keys.txt'

# ── Инициализация файлов ───────────────────────────────────────────────────────
if not CFG_FILE.exists():
    CFG_FILE.write_text(json.dumps({
        "proxy": "", "sub": "", "mirrors": [], "key": ""
    }, indent=2, ensure_ascii=False))

if not KEYS_FILE.exists():
    KEYS_FILE.write_text('')

# ── Пароль ────────────────────────────────────────────────────────────────────
if not PASS_FILE.exists():
    print('\n🔐 Первый запуск — задай пароль для панели:')
    while True:
        pw  = getpass.getpass('Пароль: ').strip()
        pw2 = getpass.getpass('Повтори: ').strip()
        if not pw:        print('Пароль не может быть пустым')
        elif pw != pw2:   print('Пароли не совпадают')
        else:
            PASS_FILE.write_text(hashlib.sha256(pw.encode()).hexdigest())
            print('✅ Пароль сохранён\n')
            break
    PW_HASH = hashlib.sha256(pw.encode()).hexdigest()
else:
    PW_HASH = PASS_FILE.read_text().strip()

# ── HTML панель ───────────────────────────────────────────────────────────────
PANEL_HTML = r"""<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>MelaVPN Panel</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0f172a;color:#e2e8f0;min-height:100vh}
.nav{background:#1e293b;border-bottom:1px solid #334155;display:flex;align-items:center;padding:0 20px;gap:4px}
.logo{font-weight:800;font-size:16px;padding:14px 16px 14px 0;color:#f8fafc}
.tab{padding:14px;font-size:13px;font-weight:500;color:#64748b;cursor:pointer;border-bottom:2px solid transparent;white-space:nowrap}
.tab:hover{color:#e2e8f0}.tab.on{color:#3b82f6;border-bottom-color:#3b82f6}
.page{display:none;padding:24px 20px;max-width:760px;margin:0 auto}.page.on{display:block}
.card{background:#1e293b;border:1px solid #334155;border-radius:12px;padding:20px;margin-bottom:16px}
.ctitle{font-size:11px;font-weight:700;color:#64748b;text-transform:uppercase;letter-spacing:.1em;margin-bottom:14px}
label{display:block;font-size:13px;color:#94a3b8;margin-bottom:5px;font-weight:500}
input,textarea{width:100%;background:#0f172a;border:1px solid #334155;border-radius:8px;color:#f1f5f9;padding:9px 12px;font-size:14px;outline:none;transition:border .15s}
input:focus,textarea:focus{border-color:#3b82f6}
textarea{resize:vertical;font-family:monospace;font-size:13px;line-height:1.6}
.row{margin-bottom:13px}
.btn{display:inline-flex;align-items:center;gap:6px;padding:9px 18px;border:none;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;transition:opacity .15s}
.btn:hover{opacity:.82}.btns{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}
.bp{background:#3b82f6;color:#fff}.bg{background:#334155;color:#e2e8f0}
.br{background:#7f1d1d;color:#fca5a5;border:1px solid #991b1b}
.bgr{background:#064e3b;color:#6ee7b7;border:1px solid #065f46}
.toast{padding:10px 14px;border-radius:8px;font-size:13px;margin-top:12px;display:none}
.tok{background:#064e3b;color:#6ee7b7;border:1px solid #065f46;display:block}
.ter{background:#7f1d1d;color:#fca5a5;border:1px solid #991b1b;display:block}
.stat{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:16px}
.scard{flex:1;min-width:130px;background:#0f172a;border:1px solid #334155;border-radius:10px;padding:14px}
.snum{font-size:28px;font-weight:800;color:#f8fafc}.slbl{font-size:12px;color:#64748b;margin-top:2px}
.mono{font-family:monospace;font-size:13px;color:#7dd3fc;word-break:break-all;padding:10px 12px;background:#0f172a;border:1px solid #1e3a5f;border-radius:8px}
#login{display:flex;align-items:center;justify-content:center;min-height:100vh}
.lbox{background:#1e293b;border:1px solid #334155;border-radius:16px;padding:32px;width:100%;max-width:380px}
.ltitle{font-size:20px;font-weight:800;margin-bottom:24px;color:#f8fafc}
.hint{font-size:12px;color:#64748b;margin-top:6px;line-height:1.5}
small{font-size:12px;color:#64748b;line-height:1.5;display:block;margin-top:4px}
</style>
</head>
<body>

<!-- LOGIN -->
<div id="login">
  <div class="lbox">
    <div class="ltitle">🔐 MelaVPN Panel</div>
    <div class="row">
      <label>Пароль</label>
      <input id="pw" type="password" placeholder="твой пароль">
    </div>
    <button class="btn bp" onclick="doLogin()">Войти →</button>
    <div id="lerr" class="toast" style="margin-top:12px"></div>
  </div>
</div>

<!-- APP -->
<div id="app" style="display:none">
  <nav class="nav">
    <div class="logo">🔐 MelaVPN</div>
    <div class="tab on" onclick="tab('dash',this)">📊 Главная</div>
    <div class="tab" onclick="tab('proxy',this)">🌐 Прокси</div>
    <div class="tab" onclick="tab('sub',this)">📡 Подписка</div>
    <div class="tab" onclick="tab('keys',this)">🔑 Ключи</div>
    <div class="tab" onclick="tab('mirrors',this)">🪞 Зеркала</div>
  </nav>

  <!-- ГЛАВНАЯ -->
  <div id="page-dash" class="page on">
    <div class="stat">
      <div class="scard"><div class="snum" id="s-keys">—</div><div class="slbl">VPN ключей</div></div>
      <div class="scard"><div class="snum" id="s-mirrors">—</div><div class="slbl">Зеркал</div></div>
      <div class="scard"><div class="snum" id="s-proxy">—</div><div class="slbl">Прокси</div></div>
    </div>
    <div class="card">
      <div class="ctitle">config.json — что видит приложение</div>
      <pre id="cfg-preview" class="mono" style="white-space:pre-wrap;word-break:break-all">загрузка...</pre>
    </div>
    <div class="card">
      <div class="ctitle">URL для app_config.dart</div>
      <div class="mono" id="cfg-url">—</div>
      <small style="margin-top:8px">Вставь этот URL в lib/core/config/app_config.dart → seedUrls</small>
    </div>
  </div>

  <!-- ПРОКСИ -->
  <div id="page-proxy" class="page">
    <div class="card">
      <div class="ctitle">Bootstrap Proxy</div>
      <div class="row">
        <label>Адрес прокси</label>
        <input id="proxy" placeholder="1.2.3.4:10808 или socks5://1.2.3.4:1080">
        <small>HTTP: host:port или http://host:port — SOCKS5: socks5://host:port — оставь пустым чтобы отключить</small>
      </div>
      <div class="btns">
        <button class="btn bp" onclick="saveProxy()">💾 Сохранить</button>
        <button class="btn br" onclick="clearProxy()">✕ Очистить</button>
      </div>
      <div id="proxy-toast" class="toast"></div>
    </div>
  </div>

  <!-- ПОДПИСКА -->
  <div id="page-sub" class="page">
    <div class="card">
      <div class="ctitle">Subscription URL</div>
      <div class="row">
        <label>URL подписки</label>
        <input id="sub" placeholder="https://example.com/sub/TOKEN">
        <small>Ссылка откуда приложение загружает VPN конфиги. Отдаётся пользователям.</small>
      </div>
      <div class="btns">
        <button class="btn bp" onclick="saveSub()">💾 Сохранить</button>
      </div>
      <div id="sub-toast" class="toast"></div>
    </div>
  </div>

  <!-- КЛЮЧИ -->
  <div id="page-keys" class="page">
    <div class="card">
      <div class="ctitle">VPN Ключи (Bootstrap Key)</div>
      <div class="row">
        <label>Ключ (vless://, ss://, vmess:// и т.д.)</label>
        <textarea id="keys" rows="8" placeholder="vless://...&#10;ss://..."></textarea>
        <small>Первый рабочий ключ отдаётся пользователям как bootstrap key для первого подключения</small>
      </div>
      <div class="btns">
        <button class="btn bp" onclick="saveKeys()">💾 Сохранить</button>
      </div>
      <div id="keys-toast" class="toast"></div>
    </div>
  </div>

  <!-- ЗЕРКАЛА -->
  <div id="page-mirrors" class="page">
    <div class="card">
      <div class="ctitle">Зеркала (Mirrors)</div>
      <div class="row">
        <label>URLs (по одному на строку)</label>
        <textarea id="mirrors" rows="8" placeholder="https://mirror1.com/config.json&#10;https://mirror2.com/config.json"></textarea>
        <small>Резервные адреса откуда приложение может получить конфиг если основной недоступен</small>
      </div>
      <div class="btns">
        <button class="btn bp" onclick="saveMirrors()">💾 Сохранить</button>
      </div>
      <div id="mirrors-toast" class="toast"></div>
    </div>
  </div>
</div>

<script>
let TOK = '';

document.getElementById('pw').addEventListener('keydown', e => { if(e.key==='Enter') doLogin(); });

function doLogin(){
  TOK = document.getElementById('pw').value.trim();
  if(!TOK) return toast('lerr','Введи пароль',0);
  api('GET','/api/config').then(r=>{
    if(r.status===401) return toast('lerr','Неверный пароль',0);
    if(!r.ok) return toast('lerr','Ошибка '+r.status,0);
    sessionStorage.setItem('tok',TOK);
    document.getElementById('login').style.display='none';
    document.getElementById('app').style.display='block';
    loadAll();
  }).catch(()=>toast('lerr','Сервер недоступен',0));
}

window.onload=()=>{
  const t=sessionStorage.getItem('tok');
  if(t){TOK=t;api('GET','/api/config').then(r=>{
    if(r.ok){document.getElementById('login').style.display='none';document.getElementById('app').style.display='block';loadAll();}
  }).catch(()=>{});}
};

function tab(name,el){
  document.querySelectorAll('.tab').forEach(t=>t.classList.remove('on'));
  document.querySelectorAll('.page').forEach(p=>p.classList.remove('on'));
  el.classList.add('on');
  document.getElementById('page-'+name).classList.add('on');
  if(name==='dash') loadDash();
}

async function loadAll(){ loadDash(); loadProxy(); loadSub(); loadKeys(); loadMirrors(); }

async function loadDash(){
  const [cfg,keys] = await Promise.all([
    api('GET','/api/config').then(r=>r.json()),
    api('GET','/api/keys').then(r=>r.json()),
  ]);
  const keyLines = (keys.keys||'').split('\n').filter(l=>l.trim());
  const mirrors  = cfg.mirrors||[];
  document.getElementById('s-keys').textContent    = keyLines.length;
  document.getElementById('s-mirrors').textContent = mirrors.length;
  document.getElementById('s-proxy').textContent   = cfg.proxy ? '✓' : '—';
  document.getElementById('cfg-preview').textContent = JSON.stringify({
    proxy: cfg.proxy||'',
    sub:   cfg.sub||'',
    mirrors: mirrors,
    key: keyLines[0]||'',
  }, null, 2);
  const origin = window.location.origin;
  document.getElementById('cfg-url').textContent = origin+'/config.json';
}

async function loadProxy(){
  const cfg = await api('GET','/api/config').then(r=>r.json());
  document.getElementById('proxy').value = cfg.proxy||'';
}
async function loadSub(){
  const cfg = await api('GET','/api/config').then(r=>r.json());
  document.getElementById('sub').value = cfg.sub||'';
}
async function loadKeys(){
  const d = await api('GET','/api/keys').then(r=>r.json());
  document.getElementById('keys').value = d.keys||'';
}
async function loadMirrors(){
  const cfg = await api('GET','/api/config').then(r=>r.json());
  document.getElementById('mirrors').value = (cfg.mirrors||[]).join('\n');
}

async function saveProxy(){
  const cfg = await api('GET','/api/config').then(r=>r.json());
  cfg.proxy = document.getElementById('proxy').value.trim();
  const r = await api('POST','/api/config',cfg);
  toast('proxy-toast', r.ok?'✅ Сохранено':'❌ Ошибка', r.ok);
  if(r.ok) loadDash();
}
async function clearProxy(){
  const cfg = await api('GET','/api/config').then(r=>r.json());
  cfg.proxy = '';
  document.getElementById('proxy').value='';
  const r = await api('POST','/api/config',cfg);
  toast('proxy-toast', r.ok?'✅ Очищено':'❌ Ошибка', r.ok);
  if(r.ok) loadDash();
}
async function saveSub(){
  const cfg = await api('GET','/api/config').then(r=>r.json());
  cfg.sub = document.getElementById('sub').value.trim();
  const r = await api('POST','/api/config',cfg);
  toast('sub-toast', r.ok?'✅ Сохранено':'❌ Ошибка', r.ok);
  if(r.ok) loadDash();
}
async function saveKeys(){
  const keys = document.getElementById('keys').value.trim();
  const r = await api('POST','/api/keys',{keys});
  toast('keys-toast', r.ok?'✅ Сохранено':'❌ Ошибка', r.ok);
  if(r.ok) loadDash();
}
async function saveMirrors(){
  const cfg = await api('GET','/api/config').then(r=>r.json());
  cfg.mirrors = document.getElementById('mirrors').value.split('\n').map(s=>s.trim()).filter(Boolean);
  const r = await api('POST','/api/config',cfg);
  toast('mirrors-toast', r.ok?'✅ Сохранено':'❌ Ошибка', r.ok);
  if(r.ok) loadDash();
}

function api(method,path,body){
  return fetch(path,{method,headers:{'X-Token':TOK,'Content-Type':'application/json'},
    body:body?JSON.stringify(body):undefined});
}
function toast(id,msg,ok){
  const el=document.getElementById(id);
  el.textContent=msg; el.className='toast '+(ok?'tok':'ter');
  if(ok) setTimeout(()=>el.style.display='none',3000);
}
</script>
</body>
</html>"""

# ── HTTP Handler ──────────────────────────────────────────────────────────────
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def cors(self):
        self.send_header('Access-Control-Allow-Origin','*')
        self.send_header('Access-Control-Allow-Headers','X-Token,Content-Type')
        self.send_header('Access-Control-Allow-Methods','GET,POST,OPTIONS')

    def json_resp(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type','application/json')
        self.cors()
        self.end_headers()
        self.wfile.write(body)

    def auth(self):
        pw = self.headers.get('X-Token','')
        return hashlib.sha256(pw.encode()).hexdigest() == PW_HASH

    def body(self):
        n = int(self.headers.get('Content-Length',0))
        return json.loads(self.rfile.read(n)) if n else {}

    def cfg(self):
        return json.loads(CFG_FILE.read_text())

    def public_config(self):
        """Строит публичный config.json для приложения."""
        cfg  = self.cfg()
        keys = KEYS_FILE.read_text().strip()
        key  = next((l.strip() for l in keys.splitlines() if l.strip()), '')
        return {
            'proxy':   cfg.get('proxy',''),
            'sub':     cfg.get('sub',''),
            'mirrors': cfg.get('mirrors',[]),
            'key':     key,
        }

    def do_OPTIONS(self):
        self.send_response(204); self.cors(); self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path

        # Панель (публичная страница с паролем)
        if path in ('/', '/panel'):
            self.send_response(200)
            self.send_header('Content-Type','text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(PANEL_HTML.encode())
            return

        # Публичный конфиг — приложение читает этот URL
        if path == '/config.json':
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.cors()
            self.end_headers()
            self.wfile.write(json.dumps(self.public_config(), ensure_ascii=False, indent=2).encode())
            return

        if not self.auth():
            return self.json_resp({'error':'unauthorized'}, 401)

        if path == '/api/config':
            return self.json_resp(self.cfg())
        if path == '/api/keys':
            return self.json_resp({'keys': KEYS_FILE.read_text()})

        self.json_resp({'error':'not found'}, 404)

    def do_POST(self):
        path = urlparse(self.path).path
        if not self.auth():
            return self.json_resp({'error':'unauthorized'}, 401)

        data = self.body()

        if path == '/api/config':
            CFG_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False))
            return self.json_resp({'ok': True})

        if path == '/api/keys':
            KEYS_FILE.write_text(data.get('keys',''))
            return self.json_resp({'ok': True})

        self.json_resp({'error':'not found'}, 404)


# ── Start ─────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print(f'\n✅ MelaVPN Server запущен')
    print(f'   Панель:     http://ВАШ_IP:{PORT}')
    print(f'   Config URL: http://ВАШ_IP:{PORT}/config.json  ← вставь в app_config.dart')
    HTTPServer(('0.0.0.0', PORT), Handler).serve_forever()
