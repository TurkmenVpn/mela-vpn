import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:melavpn/core/config/app_config.dart';
import 'package:melavpn/core/utils/preferences_utils.dart';

const _kBootstrapProxyAddr = 'bootstrap_proxy_addr';
const _kBootstrapSubUrl    = 'bootstrap_sub_url';
const _kBootstrapMirrors   = 'bootstrap_mirrors';
const _kBootstrapKey       = 'bootstrap_key';

/// Cached bootstrap proxy address: "host:port" or empty.
final bootstrapProxyAddrProvider = PreferencesNotifier.create<String, String>(
  _kBootstrapProxyAddr, '',
);

/// Cached subscription URL.
final bootstrapSubUrlProvider = PreferencesNotifier.create<String, String>(
  _kBootstrapSubUrl, '',
);

/// Saved mirror list discovered from previous fetches.
/// Stored as semicolon-separated URLs.
final bootstrapMirrorsProvider = PreferencesNotifier.create<String, String>(
  _kBootstrapMirrors, '',
);

/// Bootstrap vless/ss/vmess key distributed by the backend for first-time users.
final bootstrapKeyProvider = PreferencesNotifier.create<String, String>(
  _kBootstrapKey, '',
);

// ─── public API ─────────────────────────────────────────────────────────────

Future<_Config?> refreshBootstrapProxy(ProviderContainer container) async {
  final urls = _buildUrlList(container.read(bootstrapMirrorsProvider));
  final result = await _fetchFirstAvailable(urls);
  if (result == null) return null;
  await _save(
    writeProxy:   (v) => container.read(bootstrapProxyAddrProvider.notifier).update(v),
    writeSub:     (v) => container.read(bootstrapSubUrlProvider.notifier).update(v),
    writeMirrors: (v) => container.read(bootstrapMirrorsProvider.notifier).update(v),
    writeKey:     (v) => container.read(bootstrapKeyProvider.notifier).update(v),
    result: result,
  );
  return result;
}

Future<void> refreshBootstrapProxyFromWidget(WidgetRef ref) async {
  final urls = _buildUrlList(ref.read(bootstrapMirrorsProvider));
  final result = await _fetchFirstAvailable(urls);
  if (result == null) return;
  await _save(
    writeProxy:   (v) => ref.read(bootstrapProxyAddrProvider.notifier).update(v),
    writeSub:     (v) => ref.read(bootstrapSubUrlProvider.notifier).update(v),
    writeMirrors: (v) => ref.read(bootstrapMirrorsProvider.notifier).update(v),
    writeKey:     (v) => ref.read(bootstrapKeyProvider.notifier).update(v),
    result: result,
  );
}

// ─── internal ────────────────────────────────────────────────────────────────

typedef _Config = ({String proxy, String sub, List<String> mirrors, String key});

/// Builds full URL list: saved mirrors first, then seed URLs (deduplicated).
List<String> _buildUrlList(String savedMirrors) {
  final saved = savedMirrors.isNotEmpty
      ? savedMirrors.split(';').where((u) => u.isNotEmpty).toList()
      : <String>[];
  final all = [...saved, ...AppConfig.seedUrls];
  final seen = <String>{};
  return all.where((u) => seen.add(u)).toList();
}

final _dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ),
);

Future<_Config?> _fetchFirstAvailable(List<String> urls) async {
  for (final url in urls) {
    if (_isPlaceholder(url)) continue;
    try {
      final resp = await _dio.get<String>(url);
      if (resp.statusCode != 200 || resp.data == null) continue;
      final config = _parse(resp.data!.trim(), url);
      if (config != null) return config;
    } catch (_) {
      continue;
    }
  }
  return null;
}

bool _isPlaceholder(String url) =>
    url.contains('ДОМЕН') ||
    url.contains('ТВОй') ||
    url.contains('XXXXXXXXXX') ||
    url.contains('ИМЯ-ПРОЕКТА') ||
    url.contains('BUCKET') ||
    url.contains('РЕПО') ||
    url.contains('НИК');

Future<void> _save({
  required Future<void> Function(String) writeProxy,
  required Future<void> Function(String) writeSub,
  required Future<void> Function(String) writeMirrors,
  required Future<void> Function(String) writeKey,
  required _Config result,
}) async {
  if (result.proxy.isNotEmpty)   await writeProxy(result.proxy);
  if (result.sub.isNotEmpty)     await writeSub(result.sub);
  if (result.key.isNotEmpty)     await writeKey(result.key);
  if (result.mirrors.isNotEmpty) await writeMirrors(result.mirrors.join(';'));
}

// ─── parsers ─────────────────────────────────────────────────────────────────

_Config? _parse(String raw, String sourceUrl) {
  if (raw.isEmpty) return null;

  if (sourceUrl.contains('api.telegram.org')) return _parseTelegram(raw);
  if (sourceUrl.contains('firebaseio.com'))    return _parseFirebase(raw);
  if (raw.startsWith('{'))                     return _parseJson(raw);

  final proxy = _normalizeProxy(raw);
  if (proxy.isNotEmpty) return (proxy: proxy, sub: '', mirrors: [], key: '');
  return null;
}

_Config? _parseFirebase(String raw) {
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final inner = map['config'] is Map ? map['config'] as Map<String, dynamic> : map;
    return _parseJson(jsonEncode(inner));
  } catch (_) {
    return null;
  }
}

_Config? _parseTelegram(String raw) {
  try {
    final outer = jsonDecode(raw) as Map<String, dynamic>;
    if (outer['ok'] != true) return null;
    final result  = outer['result']  as Map<String, dynamic>?;
    final pinned  = result?['pinned_message'] as Map<String, dynamic>?;
    final text    = (pinned?['text'] as String? ?? '').trim();
    if (text.isEmpty) return null;
    if (text.startsWith('{')) return _parseJson(text);
    final proxy = _normalizeProxy(text);
    if (proxy.isNotEmpty) return (proxy: proxy, sub: '', mirrors: [], key: '');
  } catch (_) {}
  return null;
}

/// Parses:
/// {
///   "key":     "vless://... or ss://... or vmess://...",  ← bootstrap VPN key
///   "proxy":   "host:port",                               ← HTTP proxy (optional)
///   "sub":     "https://...",                             ← subscription URL
///   "mirrors": ["https://..."]                            ← backup config servers
/// }
_Config? _parseJson(String raw) {
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;

    final proxy = _normalizeProxy(map['proxy']?.toString() ?? '');
    final sub   = map['sub']?.toString() ?? '';
    final key   = _extractKey(map['key']?.toString() ?? '');

    final mirrors = <String>[];
    if (map['mirrors'] is List) {
      for (final m in (map['mirrors'] as List)) {
        final s = m?.toString() ?? '';
        if (s.isNotEmpty && !_isPlaceholder(s)) mirrors.add(s);
      }
    }

    if (proxy.isEmpty && sub.isEmpty && mirrors.isEmpty && key.isEmpty) return null;
    return (proxy: proxy, sub: sub, mirrors: mirrors, key: key);
  } catch (_) {
    return null;
  }
}

/// Accepts vless://, vmess://, ss://, trojan://, hy2://, hysteria2://, tuic://, wg://
String _extractKey(String raw) {
  if (raw.isEmpty) return '';
  const schemes = ['vless://', 'vmess://', 'ss://', 'trojan://', 'hysteria2://', 'hysteria://', 'hy2://', 'tuic://', 'wg://'];
  final lower = raw.trim().toLowerCase();
  if (schemes.any(lower.startsWith)) return raw.trim();
  return '';
}

/// Parses an x-update-proxy header value into a storable form.
/// Accepted formats:
///   host:port                → HTTP CONNECT proxy → stored as "host:port"
///   http://host:port         → HTTP CONNECT proxy → stored as "host:port"
///   socks5://host:port       → SOCKS5 proxy       → stored as "socks5:host:port"
///   socks://host:port        → SOCKS5 proxy       → stored as "socks5:host:port"
///   "off" / "disable" / "0" → disable (caller should write empty string)
String normalizeProxyAddr(String raw) => _normalizeProxy(raw);

String _normalizeProxy(String raw) {
  if (raw.isEmpty) return '';
  final uri = Uri.tryParse(raw);
  if (uri != null && uri.host.isNotEmpty) {
    switch (uri.scheme) {
      case 'socks5' || 'socks':
        final port = uri.hasPort ? uri.port : 1080;
        return 'socks5:${uri.host}:$port';
      case 'http' || 'https':
        final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
        return '${uri.host}:$port';
    }
  }
  if (raw.contains(':') && !raw.contains('/')) return raw;
  return '';
}
