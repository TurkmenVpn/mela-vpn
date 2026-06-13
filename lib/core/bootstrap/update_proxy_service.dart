import 'dart:convert';

/// Parses a proxy URI (vless/vmess/ss/trojan) into a minimal sing-box config JSON
/// that runs a SOCKS5+HTTP mixed inbound on [port] without TUN/VPN.
/// Returns null if the key cannot be parsed.
class UpdateProxyService {
  static const proxyPort = 12808;

  static String? buildConfig(String key) {
    final outbound = _parseKey(key.trim());
    if (outbound == null) return null;

    return jsonEncode({
      'log': {'level': 'error'},
      'inbounds': [
        {
          'type': 'mixed',
          'tag': 'mixed-in',
          'listen': '127.0.0.1',
          'listen_port': proxyPort,
          'sniff': false,
        },
      ],
      'outbounds': [
        outbound,
        {'type': 'direct', 'tag': 'direct'},
      ],
    });
  }

  static Map<String, dynamic>? _parseKey(String key) {
    if (key.startsWith('vless://')) return _parseVless(key);
    if (key.startsWith('vmess://')) return _parseVmess(key);
    if (key.startsWith('ss://')) return _parseShadowsocks(key);
    if (key.startsWith('trojan://')) return _parseTrojan(key);
    return null;
  }

  static Map<String, dynamic>? _parseVless(String raw) {
    final u = Uri.tryParse(raw);
    if (u == null || u.host.isEmpty || u.port == 0) return null;
    final q = u.queryParameters;

    final out = <String, dynamic>{
      'type': 'vless',
      'tag': 'proxy',
      'server': u.host,
      'server_port': u.port,
      'uuid': u.userInfo,
    };

    final security = q['security'] ?? '';
    if (security == 'tls' || security == 'reality') {
      final tls = <String, dynamic>{'enabled': true};
      final sni = q['sni'] ?? q['host'] ?? u.host;
      if (sni.isNotEmpty) tls['server_name'] = sni;
      if (security == 'reality') {
        tls['reality'] = {
          'enabled': true,
          'public_key': q['pbk'] ?? '',
          if (q['sid'] != null) 'short_id': q['sid'],
        };
      }
      final fp = q['fp'];
      if (fp != null && fp.isNotEmpty) {
        tls['utls'] = {'enabled': true, 'fingerprint': fp};
      }
      out['tls'] = tls;
    }
    _applyTransport(out, q);
    return out;
  }

  static Map<String, dynamic>? _parseVmess(String raw) {
    try {
      final b64 = raw.substring('vmess://'.length);
      final decoded = utf8.decode(base64.decode(base64.normalize(b64)));
      final m = jsonDecode(decoded) as Map<String, dynamic>;

      final host = m['add']?.toString() ?? '';
      final port = int.tryParse(m['port']?.toString() ?? '') ?? 0;
      if (host.isEmpty || port == 0) return null;

      final out = <String, dynamic>{
        'type': 'vmess',
        'tag': 'proxy',
        'server': host,
        'server_port': port,
        'uuid': m['id']?.toString() ?? '',
        'security': m['scy']?.toString() ?? 'auto',
        'alter_id': int.tryParse(m['aid']?.toString() ?? '') ?? 0,
      };

      if (m['tls']?.toString() == 'tls') {
        final tls = <String, dynamic>{'enabled': true};
        final sni = m['sni']?.toString() ?? m['host']?.toString() ?? '';
        if (sni.isNotEmpty) tls['server_name'] = sni;
        out['tls'] = tls;
      }

      final net = m['net']?.toString() ?? 'tcp';
      if (net == 'ws') {
        out['transport'] = {
          'type': 'ws',
          'path': m['path']?.toString() ?? '/',
          if ((m['host']?.toString() ?? '').isNotEmpty) 'headers': {'Host': m['host'].toString()},
        };
      } else if (net == 'grpc') {
        out['transport'] = {'type': 'grpc', 'service_name': m['path']?.toString() ?? ''};
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseShadowsocks(String raw) {
    final u = Uri.tryParse(raw);
    if (u == null || u.host.isEmpty || u.port == 0) return null;

    String method;
    String password;
    final userInfo = u.userInfo;

    if (userInfo.contains(':')) {
      final idx = userInfo.indexOf(':');
      method = Uri.decodeComponent(userInfo.substring(0, idx));
      password = Uri.decodeComponent(userInfo.substring(idx + 1));
    } else {
      try {
        final decoded = utf8.decode(base64.decode(base64.normalize(userInfo)));
        final idx = decoded.indexOf(':');
        if (idx < 0) return null;
        method = decoded.substring(0, idx);
        password = decoded.substring(idx + 1);
      } catch (_) {
        return null;
      }
    }

    return {
      'type': 'shadowsocks',
      'tag': 'proxy',
      'server': u.host,
      'server_port': u.port,
      'method': method,
      'password': password,
    };
  }

  static Map<String, dynamic>? _parseTrojan(String raw) {
    final u = Uri.tryParse(raw);
    if (u == null || u.host.isEmpty || u.port == 0) return null;
    final q = u.queryParameters;

    final out = <String, dynamic>{
      'type': 'trojan',
      'tag': 'proxy',
      'server': u.host,
      'server_port': u.port,
      'password': u.userInfo,
    };

    final tls = <String, dynamic>{'enabled': true};
    final sni = q['sni'] ?? q['host'] ?? u.host;
    if (sni.isNotEmpty) tls['server_name'] = sni;
    final trojanFp = q['fp'];
    if (trojanFp != null && trojanFp.isNotEmpty) {
      tls['utls'] = {'enabled': true, 'fingerprint': trojanFp};
    }
    out['tls'] = tls;
    _applyTransport(out, q);
    return out;
  }

  static void _applyTransport(Map<String, dynamic> out, Map<String, String> q) {
    final type = q['type'] ?? 'tcp';
    if (type == 'ws') {
      out['transport'] = {
        'type': 'ws',
        'path': q['path'] ?? '/',
        if ((q['host'] ?? '').isNotEmpty) 'headers': {'Host': q['host']},
      };
    } else if (type == 'grpc') {
      out['transport'] = {
        'type': 'grpc',
        'service_name': q['serviceName'] ?? q['path'] ?? '',
      };
    } else if (type == 'h2') {
      out['transport'] = {
        'type': 'http',
        if ((q['path'] ?? '').isNotEmpty) 'path': q['path'],
        if ((q['host'] ?? '').isNotEmpty) 'host': [q['host']],
      };
    }
  }
}
