import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:melavpn/utils/validators.dart';

// bootstrapProxy: optional proxy URI (ss://, vless://, etc.) embedded in crypt link
// When set, it is imported as a local connection profile alongside the subscription.
typedef ProfileLink = ({String url, String name, String? bootstrapProxy});

// TODO: test and improve
abstract class LinkParser {
  static final _chacha20 = Chacha20.poly1305Aead();
  static SecretKey? _cachedKey;

  // Derives 32-byte key from the app secret via SHA-256 (computed once, then cached)
  static Future<SecretKey> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final hash = await Sha256().hash(utf8.encode('melarelax'));
    return _cachedKey = await _chacha20.newSecretKeyFromBytes(hash.bytes);
  }

  /// Generates a crypt link with an embedded bootstrap proxy URI.
  /// The payload is JSON: {"u": url, "p": proxy, "n": name?}
  /// When imported, the proxy URI is also added as a local connection profile.
  static Future<String> generateCryptLinkWithProxy(String url, String proxy, [String? name]) async {
    final payload = jsonEncode({
      'u': url,
      'p': proxy,
      if (name != null && name.isNotEmpty) 'n': name,
    });
    final key = await _getKey();
    final secretBox = await _chacha20.encrypt(utf8.encode(payload), secretKey: key);
    final nonce = Uint8List.fromList(secretBox.nonce);
    final mac = Uint8List.fromList(secretBox.mac.bytes);
    final cipher = Uint8List.fromList(secretBox.cipherText);
    final combined = Uint8List(nonce.length + mac.length + cipher.length);
    combined.setRange(0, nonce.length, nonce);
    combined.setRange(nonce.length, nonce.length + mac.length, mac);
    combined.setRange(nonce.length + mac.length, combined.length, cipher);
    final encoded = base64Url.encode(combined);
    final params = name != null && name.isNotEmpty ? '?name=${Uri.encodeComponent(name)}' : '';
    return 'melavpn://crypt/$encoded$params';
  }

  static String generateSubShareLink(String url, [String? name]) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final modifiedUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      path: uri.path,
      query: uri.query,
      fragment: name ?? uri.fragment,
    );
    return '$modifiedUri';
  }

  /// Generates a ChaCha20-Poly1305 encrypted subscription share link.
  /// Format: melavpn://crypt/<base64url(nonce[12] + mac[16] + ciphertext)>?name=<name>
  static Future<String> generateCryptLink(String url, [String? name]) async {
    final key = await _getKey();
    final secretBox = await _chacha20.encrypt(utf8.encode(url), secretKey: key);
    final nonce = Uint8List.fromList(secretBox.nonce);
    final mac = Uint8List.fromList(secretBox.mac.bytes);
    final cipher = Uint8List.fromList(secretBox.cipherText);
    final combined = Uint8List(nonce.length + mac.length + cipher.length);
    combined.setRange(0, nonce.length, nonce);
    combined.setRange(nonce.length, nonce.length + mac.length, mac);
    combined.setRange(nonce.length + mac.length, combined.length, cipher);
    final encoded = base64Url.encode(combined);
    final params = name != null && name.isNotEmpty ? '?name=${Uri.encodeComponent(name)}' : '';
    return 'melavpn://crypt/$encoded$params';
  }

  // protocols schemas
  static const protocols = ['melavpn', 'v2ray', 'v2rayn', 'v2rayng', 'clash', 'clashmeta', 'sing-box'];

  static Future<ProfileLink?> parse(String link) async {
    return simple(link) ?? await deep(link);
  }

  static ProfileLink? simple(String link) {
    if (!isUrl(link)) return null;
    final uri = Uri.parse(link.trim());
    return (url: uri.toString(), name: uri.queryParameters['name'] ?? '', bootstrapProxy: null);
  }

  static Future<ProfileLink?> deep(String link) async {
    final uri = Uri.tryParse(link.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    final queryParams = uri.queryParameters;
    switch (uri.scheme) {
      case 'melavpn':
        if (uri.host == 'crypt') {
          final encoded = uri.pathSegments.firstOrNull ?? '';
          final decoded = await _decryptChacha20(encoded);
          if (decoded != null) {
            // JSON payload: {"u": url, "p": proxy, "n": name?}
            if (decoded.startsWith('{')) {
              try {
                final json = jsonDecode(decoded) as Map<String, dynamic>;
                final subUrl = json['u'] as String? ?? '';
                final proxy = json['p'] as String?;
                final jsonName = json['n'] as String? ?? '';
                final name = queryParams['name']?.isNotEmpty == true ? queryParams['name']! : jsonName;
                if (subUrl.isNotEmpty) {
                  return (url: subUrl, name: name, bootstrapProxy: proxy);
                }
              } catch (_) {}
            }
            return (url: decoded, name: queryParams['name'] ?? '', bootstrapProxy: null);
          }
          return null;
        }
        if (queryParams.containsKey('url')) {
          final rawUrl = queryParams['url']!;
          final isCrypt = queryParams['crypt'] == '1' || queryParams['encrypted'] == '1';
          final url = isCrypt ? (await _decryptChacha20(rawUrl) ?? rawUrl) : rawUrl;
          return (url: url, name: queryParams['name'] ?? '', bootstrapProxy: null);
        } else {
          final url = uri.path.substring(1) + (uri.hasQuery ? "?${uri.query}" : "");
          if (!url.startsWith('https://') && !url.startsWith('http://')) return null;
          return (url: url, name: uri.fragment, bootstrapProxy: null);
        }
      case 'v2ray' || 'v2rayn' || 'v2rayng' || 'clash' || 'clashmeta' || 'sing-box':
        return queryParams.containsKey('url')
            ? (url: queryParams['url']!, name: queryParams['name'] ?? '', bootstrapProxy: null)
            : null;
      default:
        return null;
    }
  }

  static Future<String?> _decryptChacha20(String encoded) async {
    if (encoded.isEmpty) return null;
    try {
      final bytes = base64Url.decode(base64Url.normalize(encoded));
      if (bytes.length < 29) return null; // nonce(12) + mac(16) + min 1 byte ciphertext
      final nonce = bytes.sublist(0, 12);
      final mac = bytes.sublist(12, 28);
      final cipherText = bytes.sublist(28);
      final key = await _getKey();
      final plainText = await _chacha20.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return utf8.decode(plainText);
    } catch (_) {
      return null;
    }
  }
}

String safeDecodeBase64(String str) {
  try {
    return utf8.decode(base64Decode(str));
  } on FormatException {
    return str;
  } on RangeError {
    return str;
  }
}
