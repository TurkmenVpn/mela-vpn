import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:melavpn/core/app_info/app_info_provider.dart';
import 'package:melavpn/core/bootstrap/bootstrap_proxy_provider.dart';
import 'package:melavpn/core/bootstrap/update_proxy_notifier.dart';
import 'package:melavpn/core/device_id/device_id_provider.dart';
import 'package:melavpn/features/connection/model/connection_status.dart';
import 'package:melavpn/features/connection/notifier/connection_notifier.dart';
import 'package:melavpn/features/log/model/log_level.dart';
import 'package:melavpn/features/profile/data/profile_data_providers.dart';
import 'package:melavpn/features/profile/data/profile_repository.dart';
import 'package:melavpn/features/profile/model/profile_entity.dart';
import 'package:melavpn/features/profile/notifier/profile_notifier.dart';
import 'package:melavpn/features/profile/notifier/profiles_update_notifier.dart';
import 'package:melavpn/features/settings/data/config_option_repository.dart';
import 'package:melavpn/features/stats/notifier/stats_notifier.dart';
import 'package:melavpn/hiddifycore/generated/v2/hcore/hcore.pb.dart' as hpb;
import 'package:melavpn/hiddifycore/hiddify_core_service_provider.dart';
import 'package:melavpn/utils/custom_loggers.dart';

final webAdminServerProvider = NotifierProvider<WebAdminServer, void>(
  WebAdminServer.new,
);

class WebAdminServer extends Notifier<void> with InfraLogger {
  HttpServer? _server;

  @override
  void build() {
    ref.onDispose(() => _server?.close(force: true));
    _start();
  }

  Future<void> _start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 7979);
      loggy.info('Web admin running at http://localhost:7979');
      _server!.listen(_handle);
    } catch (e) {
      loggy.warning('Failed to start web admin server on port 7979: $e');
    }
  }

  ProfileRepository get _repo => ref.read(profileRepositoryProvider).requireValue;

  Future<void> _handle(HttpRequest req) async {
    req.response.headers.add('Access-Control-Allow-Origin', '*');
    req.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
    req.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method == 'OPTIONS') {
      req.response.statusCode = 204;
      await req.response.close();
      return;
    }

    final path = req.uri.path;
    try {
      // Dashboard
      if (path == '/' || path == '/index.html') {
        _serveHtml(req);
      }

      // Status & connection
      else if (path == '/api/status' && req.method == 'GET') {
        await _handleStatus(req);
      } else if (path == '/api/toggle' && req.method == 'POST') {
        await _handleToggle(req);
      }

      // Traffic stats
      else if (path == '/api/stats' && req.method == 'GET') {
        await _handleStats(req);
      }

      // Profiles
      else if (path == '/api/profiles' && req.method == 'GET') {
        await _handleListProfiles(req);
      } else if (path == '/api/profiles' && req.method == 'POST') {
        await _handleAddProfile(req);
      } else if (path == '/api/profiles/update-all' && req.method == 'POST') {
        await _handleUpdateAllProfiles(req);
      } else if (path.startsWith('/api/profiles/') && req.method == 'DELETE') {
        await _handleDeleteProfile(req);
      } else if (path.startsWith('/api/profiles/') && path.endsWith('/activate') && req.method == 'POST') {
        await _handleActivateProfile(req);
      } else if (path.startsWith('/api/profiles/') && path.endsWith('/update') && req.method == 'POST') {
        await _handleUpdateProfile(req);
      }

      // Update proxy key management
      else if (path == '/api/update-proxy' && req.method == 'GET') {
        await _handleGetUpdateProxy(req);
      } else if (path == '/api/update-proxy' && req.method == 'POST') {
        await _handleSetUpdateProxy(req);
      } else if (path == '/api/update-proxy' && req.method == 'DELETE') {
        await _handleClearUpdateProxy(req);
      }

      // Settings
      else if (path == '/api/settings' && req.method == 'GET') {
        await _handleGetSettings(req);
      } else if (path == '/api/settings' && req.method == 'POST') {
        await _handleSaveSettings(req);
      }

      // Logs
      else if (path == '/api/logs' && req.method == 'GET') {
        await _handleLogs(req);
      }

      // App info
      else if (path == '/api/info' && req.method == 'GET') {
        await _handleInfo(req);
      }

      else {
        _json(req, {'error': 'not found'}, status: 404);
      }
    } catch (e, st) {
      loggy.error('Web admin handler error', e, st);
      _json(req, {'error': e.toString()}, status: 500);
    }
  }

  // ─── Connection ──────────────────────────────────────────────────────────────

  Future<void> _handleStatus(HttpRequest req) async {
    final status = ref.read(connectionNotifierProvider).value;
    _json(req, {'status': _statusLabel(status)});
  }

  Future<void> _handleToggle(HttpRequest req) async {
    await ref.read(connectionNotifierProvider.notifier).toggleConnection();
    final status = ref.read(connectionNotifierProvider).value;
    _json(req, {'status': _statusLabel(status)});
  }

  String _statusLabel(ConnectionStatus? s) => switch (s) {
    Connected()     => 'connected',
    Connecting()    => 'connecting',
    Disconnecting() => 'disconnecting',
    _               => 'disconnected',
  };

  // ─── Stats ───────────────────────────────────────────────────────────────────

  Future<void> _handleStats(HttpRequest req) async {
    final info = ref.read(statsNotifierProvider).asData?.value;
    _json(req, {
      'uplink':        info?.uplink.toInt()        ?? 0,
      'downlink':      info?.downlink.toInt()      ?? 0,
      'uplinkTotal':   info?.uplinkTotal.toInt()   ?? 0,
      'downlinkTotal': info?.downlinkTotal.toInt() ?? 0,
    });
  }

  // ─── Profiles ────────────────────────────────────────────────────────────────

  Future<void> _handleListProfiles(HttpRequest req) async {
    final result = await _repo.watchAll().first;
    final profiles = result.getOrElse((_) => []);
    _json(req, profiles.map(_profileToJson).toList());
  }

  Future<void> _handleAddProfile(HttpRequest req) async {
    final body = await _readBody(req);
    final url = (jsonDecode(body) as Map<String, dynamic>)['url']?.toString() ?? '';
    if (url.isEmpty) {
      _json(req, {'error': 'url required'}, status: 400);
      return;
    }
    await ref.read(addProfileNotifierProvider.notifier).addClipboard(url);
    _json(req, {'ok': true});
  }

  Future<void> _handleDeleteProfile(HttpRequest req) async {
    final id = _segmentId(req.uri.path);
    final result = await _repo.getById(id).run();
    final profile = result.getOrElse((_) => null);
    if (profile == null) {
      _json(req, {'error': 'not found'}, status: 404);
      return;
    }
    await _repo.deleteById(id, profile.active).run();
    _json(req, {'ok': true});
  }

  Future<void> _handleActivateProfile(HttpRequest req) async {
    final id = _segmentId(req.uri.path.replaceFirst('/activate', ''));
    await _repo.setAsActive(id).run();
    _json(req, {'ok': true});
  }

  Future<void> _handleUpdateProfile(HttpRequest req) async {
    final id = _segmentId(req.uri.path.replaceFirst('/update', ''));
    final result = await _repo.getById(id).run();
    final profile = result.getOrElse((_) => null);
    if (profile is RemoteProfileEntity) {
      await ref.read(updateProfileNotifierProvider(id).notifier).updateProfile(profile);
    }
    _json(req, {'ok': true});
  }

  Future<void> _handleUpdateAllProfiles(HttpRequest req) async {
    await ref.read(foregroundProfilesUpdateNotifierProvider.notifier).trigger();
    _json(req, {'ok': true});
  }

  // ─── Update proxy key ────────────────────────────────────────────────────────

  Future<void> _handleGetUpdateProxy(HttpRequest req) async {
    final key   = ref.read(bootstrapKeyProvider);
    final proxy = ref.read(bootstrapProxyAddrProvider);
    _json(req, {
      'key':    key,
      'active': proxy.isNotEmpty && proxy.contains('127.0.0.1'),
      'proxy':  proxy,
    });
  }

  Future<void> _handleSetUpdateProxy(HttpRequest req) async {
    final body = await _readBody(req);
    final key  = (jsonDecode(body) as Map<String, dynamic>)['key']?.toString().trim() ?? '';
    if (key.isEmpty) {
      _json(req, {'error': 'key required'}, status: 400);
      return;
    }
    await ref.read(bootstrapKeyProvider.notifier).update(key);
    // Re-trigger the update proxy manager with new key
    ref.invalidate(updateProxyNotifierProvider);
    _json(req, {'ok': true});
  }

  Future<void> _handleClearUpdateProxy(HttpRequest req) async {
    await ref.read(bootstrapKeyProvider.notifier).update('');
    ref.invalidate(updateProxyNotifierProvider);
    _json(req, {'ok': true});
  }

  // ─── Settings ────────────────────────────────────────────────────────────────

  Future<void> _handleGetSettings(HttpRequest req) async {
    _json(req, {
      'logLevel':       ref.read(ConfigOptions.logLevel).name,
      'remoteDns':      ref.read(ConfigOptions.remoteDnsAddress),
      'directDns':      ref.read(ConfigOptions.directDnsAddress),
      'mixedPort':      ref.read(ConfigOptions.mixedPort),
    });
  }

  Future<void> _handleSaveSettings(HttpRequest req) async {
    final body = await _readBody(req);
    final m    = jsonDecode(body) as Map<String, dynamic>;

    if (m['logLevel'] != null) {
      final lvl = LogLevel.values.where((e) => e.name == m['logLevel']).firstOrNull;
      if (lvl != null) await ref.read(ConfigOptions.logLevel.notifier).update(lvl);
    }
    if (m['remoteDns'] != null) {
      await ref.read(ConfigOptions.remoteDnsAddress.notifier).update(m['remoteDns'].toString());
    }
    if (m['directDns'] != null) {
      await ref.read(ConfigOptions.directDnsAddress.notifier).update(m['directDns'].toString());
    }
    if (m['mixedPort'] != null) {
      final port = int.tryParse(m['mixedPort'].toString());
      if (port != null) await ref.read(ConfigOptions.mixedPort.notifier).update(port);
    }
    _json(req, {'ok': true});
  }

  // ─── Logs ────────────────────────────────────────────────────────────────────

  Future<void> _handleLogs(HttpRequest req) async {
    final limitStr = req.uri.queryParameters['limit'] ?? '100';
    final limit    = int.tryParse(limitStr) ?? 100;
    final service  = ref.read(melavpnCoreServiceProvider);
    final logs     = service.logController.valueOrNull ?? <hpb.LogMessage>[];
    final slice    = logs.length > limit ? logs.sublist(logs.length - limit) : logs;
    _json(req, slice.map((l) => {
      'level':   _protoLevelName(l.level),
      'message': l.message,
      'time':    l.hasTime() ? l.time.seconds.toInt() * 1000 : null,
    }).toList());
  }

  // ─── App info ────────────────────────────────────────────────────────────────

  Future<void> _handleInfo(HttpRequest req) async {
    final info     = ref.read(appInfoProvider).asData?.value;
    final deviceId = ref.read(deviceIdProvider);
    _json(req, {
      'version':  info?.version ?? '?',
      'deviceId': deviceId,
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _protoLevelName(hpb.LogLevel level) {
    if (level == hpb.LogLevel.WARNING) return 'warn';
    return level.name.toLowerCase();
  }

  String _segmentId(String path) => path.split('/').last;

  Future<String> _readBody(HttpRequest req) async {
    final bytes = await req.fold<List<int>>([], (a, b) => [...a, ...b]);
    return utf8.decode(bytes);
  }

  void _json(HttpRequest req, Object data, {int status = 200}) {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(data));
    req.response.close();
  }

  Map<String, dynamic> _profileToJson(ProfileEntity p) {
    final sub = p is RemoteProfileEntity ? p.subInfo : null;
    return {
      'id':     p.id,
      'name':   p.name,
      'active': p.active,
      'type':   p is RemoteProfileEntity ? 'remote' : 'local',
      if (p is RemoteProfileEntity) 'url': p.url,
      if (sub != null) ...{
        'upload':   sub.upload,
        'download': sub.download,
        'total':    sub.total,
        'expire':   sub.expire.millisecondsSinceEpoch,
        'expired':  sub.isExpired,
      },
    };
  }

  void _serveHtml(HttpRequest req) {
    req.response.statusCode = 200;
    req.response.headers.contentType = ContentType.html;
    req.response.write(_kHtml);
    req.response.close();
  }
}

// ─── Embedded HTML Admin UI ──────────────────────────────────────────────────

const _kHtml = r'''<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mela VPN — Admin</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{--bg:#0d0d0d;--bg2:#141414;--bg3:#1a1a1a;--border:#252525;--accent:#6c63ff;--accent2:#a78bfa;--text:#e0e0e0;--text2:#9ca3af;--green:#4ade80;--red:#f87171;--yellow:#fbbf24;--blue:#60a5fa}
body{background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;min-height:100vh;display:flex;flex-direction:column}

/* Layout */
.layout{display:flex;flex:1;min-height:0}
.sidebar{width:220px;background:var(--bg2);border-right:1px solid var(--border);display:flex;flex-direction:column;padding:12px 8px;gap:4px;flex-shrink:0}
.content{flex:1;overflow-y:auto;padding:24px}

/* Topbar */
.topbar{background:var(--bg2);border-bottom:1px solid var(--border);padding:0 20px;height:52px;display:flex;align-items:center;gap:12px;flex-shrink:0}
.logo{width:26px;height:26px;background:linear-gradient(135deg,var(--accent),var(--accent2));border-radius:7px;flex-shrink:0}
.topbar h1{font-size:15px;font-weight:700;color:#fff}
.conn-badge{margin-left:auto;display:flex;align-items:center;gap:8px}
.dot{width:8px;height:8px;border-radius:50%;flex-shrink:0}
.dot.connected{background:var(--green)}
.dot.disconnected{background:#374151}
.dot.connecting{background:var(--blue);animation:pulse 1s infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.4}}
.conn-label{font-size:13px;color:var(--text2)}

/* Sidebar nav */
.nav-item{display:flex;align-items:center;gap:10px;padding:9px 12px;border-radius:9px;font-size:13px;font-weight:500;color:var(--text2);cursor:pointer;transition:all .15s;border:none;background:none;width:100%;text-align:left}
.nav-item:hover{background:var(--bg3);color:var(--text)}
.nav-item.active{background:rgba(108,99,255,.15);color:var(--accent2)}
.nav-icon{font-size:16px;width:20px;text-align:center}

/* Pages */
.page{display:none}.page.active{display:block}

/* Cards */
.card{background:var(--bg3);border:1px solid var(--border);border-radius:14px;padding:20px;margin-bottom:16px}
.card-title{font-size:11px;font-weight:700;color:var(--text2);text-transform:uppercase;letter-spacing:.8px;margin-bottom:16px}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:12px}

/* Stats tiles */
.stat-tile{background:var(--bg2);border:1px solid var(--border);border-radius:10px;padding:14px 16px}
.stat-label{font-size:11px;color:var(--text2);margin-bottom:4px}
.stat-value{font-size:20px;font-weight:700;color:var(--text)}
.stat-sub{font-size:11px;color:var(--text2);margin-top:2px}
.up{color:#a78bfa}.down{color:var(--green)}

/* Buttons */
.btn{display:inline-flex;align-items:center;justify-content:center;gap:7px;padding:9px 18px;border-radius:9px;border:none;font-size:13px;font-weight:600;cursor:pointer;transition:opacity .15s}
.btn:hover{opacity:.85}.btn:active{opacity:.7}.btn:disabled{opacity:.35;cursor:default}
.btn-accent{background:var(--accent);color:#fff}
.btn-green{background:#14532d;color:var(--green)}
.btn-red{background:#1c0a0a;color:var(--red);border:1px solid #2a1010}
.btn-ghost{background:var(--bg2);color:var(--text2);border:1px solid var(--border)}
.btn-sm{padding:6px 12px;font-size:12px;border-radius:7px}
.btn-full{width:100%}
.btn-row{display:flex;gap:8px;flex-wrap:wrap}

/* Inputs */
input[type=text],input[type=number],select,textarea{width:100%;background:var(--bg2);border:1px solid var(--border);border-radius:9px;color:var(--text);font-size:13px;padding:10px 12px;outline:none;transition:border-color .15s;font-family:inherit}
input:focus,select:focus,textarea:focus{border-color:var(--accent)}
input::placeholder,textarea::placeholder{color:#4b5563}
textarea{resize:vertical;min-height:80px;font-family:monospace}
.form-row{margin-bottom:12px}
.form-label{font-size:12px;font-weight:500;color:var(--text2);margin-bottom:6px;display:block}
select option{background:var(--bg3)}

/* Profile list */
.pi{background:var(--bg2);border:1px solid var(--border);border-radius:11px;padding:13px 15px;display:flex;align-items:center;gap:11px;margin-bottom:8px;transition:border-color .15s}
.pi.is-active{border-color:var(--accent)}
.pi-ico{width:34px;height:34px;border-radius:9px;background:var(--bg3);display:flex;align-items:center;justify-content:center;font-size:15px;flex-shrink:0}
.pi-info{flex:1;min-width:0}
.pi-name{font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.pi-meta{font-size:11px;color:var(--text2);margin-top:3px;display:flex;gap:5px;flex-wrap:wrap;align-items:center}
.tag{padding:2px 7px;border-radius:5px;font-size:10px;font-weight:700;text-transform:uppercase}
.t-remote{background:#1e3a5f;color:var(--blue)}
.t-local{background:#14532d;color:var(--green)}
.t-active{background:#312e81;color:var(--accent2)}
.t-exp{background:#450a0a;color:var(--red)}
.tbar{height:3px;background:var(--border);border-radius:2px;margin-top:6px;overflow:hidden}
.tfill{height:100%;background:linear-gradient(90deg,var(--accent),var(--accent2));border-radius:2px}
.pi-act{display:flex;gap:5px;flex-shrink:0}
.empty{text-align:center;color:#4b5563;padding:32px;font-size:13px}

/* Proxy status */
.proxy-status{display:flex;align-items:center;gap:10px;padding:12px 14px;background:var(--bg2);border:1px solid var(--border);border-radius:10px;margin-bottom:14px}
.proxy-status .dot{width:10px;height:10px}
.proxy-status-text{font-size:13px;flex:1}
.proxy-status-text small{display:block;font-size:11px;color:var(--text2);margin-top:2px;font-family:monospace;word-break:break-all}

/* Logs */
.log-box{background:var(--bg2);border:1px solid var(--border);border-radius:10px;padding:12px;height:380px;overflow-y:auto;font-family:monospace;font-size:12px;line-height:1.6}
.log-line{padding:1px 0}
.log-trace{color:#6b7280}.log-debug{color:#6b7280}.log-info{color:var(--green)}.log-warn{color:var(--yellow)}.log-error{color:var(--red)}.log-fatal{color:#ff0000;font-weight:700}
.log-controls{display:flex;gap:8px;margin-bottom:10px;align-items:center}
.log-controls select{width:120px}

/* Toast */
.toast{position:fixed;bottom:20px;right:20px;background:var(--bg3);border:1px solid var(--border);border-radius:11px;padding:11px 18px;font-size:13px;transform:translateY(80px);opacity:0;transition:all .25s;z-index:999}
.toast.show{transform:translateY(0);opacity:1}
.toast.ok{border-color:#14532d;color:var(--green)}
.toast.err{border-color:#450a0a;color:var(--red)}

/* Section divider */
.divider{height:1px;background:var(--border);margin:16px 0}

.spin{width:13px;height:13px;border:2px solid rgba(255,255,255,.2);border-top-color:#fff;border-radius:50%;animation:sp .5s linear infinite;display:none}
@keyframes sp{to{transform:rotate(360deg)}}

@media(max-width:600px){.sidebar{display:none}.grid2{grid-template-columns:1fr}}
</style>
</head>
<body>

<div class="topbar">
  <div class="logo"></div>
  <h1>Mela VPN Admin</h1>
  <div class="conn-badge">
    <div class="dot disconnected" id="topDot"></div>
    <span class="conn-label" id="topLabel">Отключено</span>
  </div>
</div>

<div class="layout">
  <nav class="sidebar">
    <button class="nav-item active" onclick="showPage('dashboard')"><span class="nav-icon">🏠</span> Дашборд</button>
    <button class="nav-item" onclick="showPage('profiles')"><span class="nav-icon">📡</span> Профили</button>
    <button class="nav-item" onclick="showPage('updateproxy')"><span class="nav-icon">🔑</span> Update Proxy</button>
    <button class="nav-item" onclick="showPage('settings')"><span class="nav-icon">⚙️</span> Настройки</button>
    <button class="nav-item" onclick="showPage('logs')"><span class="nav-icon">📋</span> Логи</button>
    <button class="nav-item" onclick="showPage('info')"><span class="nav-icon">ℹ️</span> Инфо</button>
  </nav>

  <div class="content">

    <!-- DASHBOARD -->
    <div class="page active" id="page-dashboard">
      <div class="card">
        <div class="card-title">Соединение</div>
        <div style="display:flex;align-items:center;gap:14px">
          <div class="dot disconnected" id="connDot" style="width:12px;height:12px"></div>
          <span id="connLabel" style="font-size:15px;font-weight:600;flex:1">Отключено</span>
          <button class="btn btn-green" id="toggleBtn" onclick="toggle()">Подключить</button>
        </div>
      </div>

      <div class="card">
        <div class="card-title">Трафик</div>
        <div class="grid2">
          <div class="stat-tile">
            <div class="stat-label">↑ Исходящий</div>
            <div class="stat-value up" id="upSpeed">0 Б/с</div>
            <div class="stat-sub">Всего: <span id="upTotal">0 Б</span></div>
          </div>
          <div class="stat-tile">
            <div class="stat-label">↓ Входящий</div>
            <div class="stat-value down" id="downSpeed">0 Б/с</div>
            <div class="stat-sub">Всего: <span id="downTotal">0 Б</span></div>
          </div>
        </div>
      </div>
    </div>

    <!-- PROFILES -->
    <div class="page" id="page-profiles">
      <div class="card">
        <div class="card-title">Добавить ключ / подписку</div>
        <div class="form-row">
          <textarea id="addInput" placeholder="vless://...  vmess://...  ss://...  trojan://...  https://sub-link..."></textarea>
        </div>
        <button class="btn btn-accent btn-full" id="addBtn" onclick="addProfile()">
          <span class="spin" id="addSpin"></span>Добавить
        </button>
      </div>

      <div class="card">
        <div style="display:flex;align-items:center;margin-bottom:14px">
          <div class="card-title" style="margin:0">Профили</div>
          <div style="margin-left:auto;display:flex;gap:6px">
            <button class="btn btn-ghost btn-sm" onclick="updAllProfiles()">↻ Обновить все</button>
            <button class="btn btn-ghost btn-sm" onclick="loadProfiles()">Reload</button>
          </div>
        </div>
        <div id="plist"><div class="empty">Загрузка...</div></div>
      </div>
    </div>

    <!-- UPDATE PROXY -->
    <div class="page" id="page-updateproxy">
      <div class="card">
        <div class="card-title">Прокси для обновления подписок</div>
        <p style="font-size:13px;color:var(--text2);margin-bottom:16px;line-height:1.6">
          Ключ (VLESS/VMess/SS/Trojan) запускается фоново как SOCKS5 прокси.<br>
          Когда домен подписки заблокирован — обновление идёт через него.
        </p>

        <div class="proxy-status" id="proxyStatus">
          <div class="dot disconnected" id="proxyDot"></div>
          <div class="proxy-status-text">
            <span id="proxyStatusText">Загрузка...</span>
            <small id="proxyAddr"></small>
          </div>
        </div>

        <div class="form-row">
          <label class="form-label">VLESS / VMess / SS / Trojan ключ</label>
          <textarea id="proxyKeyInput" placeholder="vless://UUID@host:443?security=tls&type=ws...&#10;ss://method:pass@host:8388&#10;vmess://BASE64"></textarea>
        </div>
        <div class="btn-row">
          <button class="btn btn-accent" onclick="setProxy()">
            <span class="spin" id="proxySpin"></span>Сохранить и запустить
          </button>
          <button class="btn btn-red" onclick="clearProxy()">Отключить</button>
        </div>
      </div>
    </div>

    <!-- SETTINGS -->
    <div class="page" id="page-settings">
      <div class="card">
        <div class="card-title">Основные настройки</div>

        <div class="form-row">
          <label class="form-label">Уровень логов</label>
          <select id="logLevel">
            <option value="trace">Trace</option>
            <option value="debug">Debug</option>
            <option value="info">Info</option>
            <option value="warn">Warn</option>
            <option value="error">Error</option>
            <option value="fatal">Fatal</option>
          </select>
        </div>

        <div class="form-row">
          <label class="form-label">Mixed Port (SOCKS5/HTTP)</label>
          <input type="number" id="mixedPort" min="1024" max="65535" placeholder="2080">
        </div>

        <div class="divider"></div>
        <div class="card-title">DNS</div>

        <div class="form-row">
          <label class="form-label">Remote DNS (для заблокированных доменов)</label>
          <input type="text" id="remoteDns" placeholder="https://1.1.1.1/dns-query">
        </div>

        <div class="form-row">
          <label class="form-label">Direct DNS (для прямых соединений)</label>
          <input type="text" id="directDns" placeholder="local">
        </div>

        <button class="btn btn-accent" onclick="saveSettings()">Сохранить</button>
      </div>
    </div>

    <!-- LOGS -->
    <div class="page" id="page-logs">
      <div class="card">
        <div class="card-title">Логи ядра</div>
        <div class="log-controls">
          <select id="logFilter" onchange="filterLogs()">
            <option value="all">Все</option>
            <option value="info">Info+</option>
            <option value="warn">Warn+</option>
            <option value="error">Error+</option>
          </select>
          <button class="btn btn-ghost btn-sm" onclick="loadLogs()">↻ Обновить</button>
          <button class="btn btn-ghost btn-sm" onclick="clearLogView()">Очистить</button>
          <label style="font-size:12px;color:var(--text2);margin-left:auto;display:flex;align-items:center;gap:6px">
            <input type="checkbox" id="autoLog" checked> Авто
          </label>
        </div>
        <div class="log-box" id="logBox"></div>
      </div>
    </div>

    <!-- INFO -->
    <div class="page" id="page-info">
      <div class="card">
        <div class="card-title">Информация о приложении</div>
        <table style="width:100%;border-collapse:collapse;font-size:13px">
          <tr><td style="padding:8px 0;color:var(--text2);width:140px">Версия</td><td id="appVersion" style="font-weight:600">—</td></tr>
          <tr><td style="padding:8px 0;color:var(--text2)">Device ID</td><td id="deviceId" style="font-family:monospace;font-size:12px;word-break:break-all">—</td></tr>
        </table>
        <div class="divider"></div>
        <div class="card-title">API endpoints</div>
        <div style="font-family:monospace;font-size:12px;color:var(--text2);line-height:2">
          GET /api/status<br>
          POST /api/toggle<br>
          GET /api/stats<br>
          GET /api/profiles<br>
          POST /api/profiles<br>
          DELETE /api/profiles/:id<br>
          POST /api/profiles/:id/activate<br>
          POST /api/profiles/:id/update<br>
          POST /api/profiles/update-all<br>
          GET /api/update-proxy<br>
          POST /api/update-proxy<br>
          DELETE /api/update-proxy<br>
          GET /api/settings<br>
          POST /api/settings<br>
          GET /api/logs<br>
          GET /api/info
        </div>
      </div>
    </div>

  </div>
</div>

<div class="toast" id="toast"></div>

<script>
const SM={connected:{l:'Подключено',d:'connected'},connecting:{l:'Подключение...',d:'connecting'},disconnecting:{l:'Отключение...',d:'connecting'},disconnected:{l:'Отключено',d:'disconnected'}};

// ─── Routing ─────────────────────────────────────────────────────────────────
function showPage(id){
  document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n=>n.classList.remove('active'));
  document.getElementById('page-'+id).classList.add('active');
  event.currentTarget.classList.add('active');
  if(id==='profiles')loadProfiles();
  if(id==='updateproxy')loadProxyStatus();
  if(id==='settings')loadSettings();
  if(id==='logs')loadLogs();
  if(id==='info')loadInfo();
}

// ─── Utils ───────────────────────────────────────────────────────────────────
function bytes(b){if(!b)return'0 Б';if(b>=1e12)return(b/1e12).toFixed(2)+' ТБ';if(b>=1e9)return(b/1e9).toFixed(2)+' ГБ';if(b>=1e6)return(b/1e6).toFixed(2)+' МБ';if(b>=1e3)return(b/1e3).toFixed(1)+' КБ';return b+' Б';}
function bps(b){return bytes(b)+'/с';}
function dt(ms){if(!ms)return'';return new Date(ms).toLocaleDateString('ru',{day:'2-digit',month:'2-digit',year:'numeric'});}
function esc(s){return(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
let toastT;
function toast(msg,ok){const el=document.getElementById('toast');clearTimeout(toastT);el.textContent=msg;el.className='toast show '+(ok?'ok':'err');toastT=setTimeout(()=>el.className='toast',3000);}
function spin(id,on){document.getElementById(id).style.display=on?'inline-block':'none';}

// ─── Status poll ─────────────────────────────────────────────────────────────
async function pollStatus(){
  try{
    const s=(await(await fetch('/api/status')).json()).status;
    const m=SM[s]||SM.disconnected;
    document.getElementById('topDot').className='dot '+m.d;
    document.getElementById('topLabel').textContent=m.l;
    document.getElementById('connDot').className='dot '+m.d;
    document.getElementById('connLabel').textContent=m.l;
    const tb=document.getElementById('toggleBtn');
    const off=s==='disconnected';
    tb.textContent=off?'Подключить':'Отключить';
    tb.className='btn '+(off?'btn-green':'btn-red');
  }catch(_){}
  setTimeout(pollStatus,2500);
}

async function toggle(){
  document.getElementById('toggleBtn').disabled=true;
  try{await fetch('/api/toggle',{method:'POST'});}catch(e){toast('Ошибка: '+e.message,0);}
  document.getElementById('toggleBtn').disabled=false;
}

// ─── Stats poll ──────────────────────────────────────────────────────────────
async function pollStats(){
  try{
    const d=await(await fetch('/api/stats')).json();
    document.getElementById('upSpeed').textContent=bps(d.uplink);
    document.getElementById('downSpeed').textContent=bps(d.downlink);
    document.getElementById('upTotal').textContent=bytes(d.uplinkTotal);
    document.getElementById('downTotal').textContent=bytes(d.downlinkTotal);
  }catch(_){}
  setTimeout(pollStats,1500);
}

// ─── Profiles ────────────────────────────────────────────────────────────────
async function loadProfiles(){
  const el=document.getElementById('plist');
  try{
    const ps=await(await fetch('/api/profiles')).json();
    if(!ps.length){el.innerHTML='<div class="empty">Нет профилей</div>';return;}
    el.innerHTML=ps.map(p=>{
      const rem=p.type==='remote';
      const inf=p.total>920233720368;
      const used=rem&&p.total?(p.upload+p.download):0;
      const pct=rem&&p.total&&!inf?Math.min(100,(used/p.total)*100):0;
      const tags=[
        rem?'<span class="tag t-remote">Remote</span>':'<span class="tag t-local">Local</span>',
        p.active?'<span class="tag t-active">Активен</span>':'',
        (rem&&p.expired)?'<span class="tag t-exp">Истёк</span>':'',
      ].filter(Boolean).join('');
      const meta=rem&&p.total?`<span>${bytes(used)}${inf?'':' / '+bytes(p.total)}</span>${p.expire?'<span>до '+dt(p.expire)+'</span>':''}`:'' ;
      const bar=rem&&p.total&&!inf?`<div class="tbar"><div class="tfill" style="width:${pct}%"></div></div>`:'';
      const updBtn=rem?`<button class="btn btn-ghost btn-sm" onclick="updProfile('${p.id}')">↻</button>`:'';
      const actBtn=!p.active?`<button class="btn btn-ghost btn-sm" onclick="actProfile('${p.id}')">Вкл</button>`:'';
      const delBtn=`<button class="btn btn-red btn-sm" onclick="delProfile('${p.id}','${esc(p.name)}')">✕</button>`;
      return`<div class="pi ${p.active?'is-active':''}" id="p-${p.id}">
        <div class="pi-ico">${rem?'🌐':'🔑'}</div>
        <div class="pi-info">
          <div class="pi-name">${esc(p.name)}</div>
          <div class="pi-meta">${tags} ${meta}</div>${bar}
        </div>
        <div class="pi-act">${updBtn}${actBtn}${delBtn}</div>
      </div>`;
    }).join('');
  }catch(e){el.innerHTML='<div class="empty">Ошибка: '+esc(e.message)+'</div>';}
}

async function addProfile(){
  const inp=document.getElementById('addInput');
  const url=inp.value.trim();if(!url)return;
  document.getElementById('addBtn').disabled=true;spin('addSpin',true);
  try{
    const r=await fetch('/api/profiles',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({url})});
    const d=await r.json();
    if(d.ok){inp.value='';toast('✓ Добавлено',1);setTimeout(loadProfiles,1500);}
    else toast('Ошибка: '+(d.error||'?'),0);
  }catch(e){toast('Ошибка: '+e.message,0);}
  document.getElementById('addBtn').disabled=false;spin('addSpin',false);
}

async function delProfile(id,name){
  if(!confirm('Удалить "'+name+'"?'))return;
  await fetch('/api/profiles/'+id,{method:'DELETE'});
  toast('Удалён: '+name,1);loadProfiles();
}
async function actProfile(id){
  await fetch('/api/profiles/'+id+'/activate',{method:'POST'});
  toast('Профиль активирован',1);loadProfiles();
}
async function updProfile(id){
  await fetch('/api/profiles/'+id+'/update',{method:'POST'});
  toast('Обновление запущено...',1);setTimeout(loadProfiles,3000);
}
async function updAllProfiles(){
  await fetch('/api/profiles/update-all',{method:'POST'});
  toast('Обновление всех профилей...',1);setTimeout(loadProfiles,5000);
}

// ─── Update Proxy ─────────────────────────────────────────────────────────────
async function loadProxyStatus(){
  try{
    const d=await(await fetch('/api/update-proxy')).json();
    const active=d.active;
    document.getElementById('proxyDot').className='dot '+(active?'connected':'disconnected');
    document.getElementById('proxyStatusText').textContent=active?'Активен — подписки обновляются через прокси':'Не активен';
    document.getElementById('proxyAddr').textContent=active?('SOCKS5 ' + d.proxy):'';
    if(d.key) document.getElementById('proxyKeyInput').value=d.key;
  }catch(_){}
}

async function setProxy(){
  const key=document.getElementById('proxyKeyInput').value.trim();
  if(!key){toast('Вставьте ключ',0);return;}
  spin('proxySpin',true);
  document.querySelector('.btn-accent[onclick="setProxy()"]').disabled=true;
  try{
    const r=await fetch('/api/update-proxy',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({key})});
    const d=await r.json();
    if(d.ok){toast('✓ Прокси запущен',1);setTimeout(loadProxyStatus,2000);}
    else toast('Ошибка: '+(d.error||'?'),0);
  }catch(e){toast('Ошибка: '+e.message,0);}
  spin('proxySpin',false);
  document.querySelector('.btn-accent[onclick="setProxy()"]').disabled=false;
}

async function clearProxy(){
  if(!confirm('Отключить прокси обновления?'))return;
  await fetch('/api/update-proxy',{method:'DELETE'});
  toast('Прокси отключён',1);setTimeout(loadProxyStatus,500);
}

// ─── Settings ─────────────────────────────────────────────────────────────────
async function loadSettings(){
  try{
    const d=await(await fetch('/api/settings')).json();
    document.getElementById('logLevel').value=d.logLevel||'info';
    document.getElementById('mixedPort').value=d.mixedPort||2080;
    document.getElementById('remoteDns').value=d.remoteDns||'';
    document.getElementById('directDns').value=d.directDns||'';
  }catch(_){}
}

async function saveSettings(){
  const body={
    logLevel:document.getElementById('logLevel').value,
    mixedPort:document.getElementById('mixedPort').value,
    remoteDns:document.getElementById('remoteDns').value,
    directDns:document.getElementById('directDns').value,
  };
  try{
    const r=await fetch('/api/settings',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
    const d=await r.json();
    d.ok?toast('✓ Сохранено',1):toast('Ошибка: '+(d.error||'?'),0);
  }catch(e){toast('Ошибка: '+e.message,0);}
}

// ─── Logs ─────────────────────────────────────────────────────────────────────
let allLogs=[];
const levelOrder={trace:0,debug:1,info:2,warn:3,error:4,fatal:5};

async function loadLogs(){
  try{
    allLogs=await(await fetch('/api/logs?limit=200')).json();
    renderLogs();
  }catch(_){}
}

function filterLogs(){renderLogs();}

function renderLogs(){
  const filter=document.getElementById('logFilter').value;
  const minLevel=levelOrder[filter==='all'?'trace':filter]??0;
  const box=document.getElementById('logBox');
  const lines=allLogs.filter(l=>(levelOrder[l.level]??0)>=minLevel);
  box.innerHTML=lines.map(l=>{
    const t=l.time?new Date(l.time).toLocaleTimeString('ru'):'';
    return`<div class="log-line log-${esc(l.level)}">[${esc(l.level.toUpperCase())}] ${t?t+' ':''}${esc(l.message)}</div>`;
  }).join('');
  box.scrollTop=box.scrollHeight;
}

function clearLogView(){allLogs=[];document.getElementById('logBox').innerHTML='';}

let logPollTimer;
function startLogPoll(){
  clearInterval(logPollTimer);
  logPollTimer=setInterval(()=>{if(document.getElementById('autoLog').checked&&document.getElementById('page-logs').classList.contains('active'))loadLogs();},3000);
}

// ─── Info ──────────────────────────────────────────────────────────────────────
async function loadInfo(){
  try{
    const d=await(await fetch('/api/info')).json();
    document.getElementById('appVersion').textContent=d.version||'?';
    document.getElementById('deviceId').textContent=d.deviceId||'?';
  }catch(_){}
}

// ─── Init ──────────────────────────────────────────────────────────────────────
pollStatus();
pollStats();
startLogPoll();
</script>
</body>
</html>''';
