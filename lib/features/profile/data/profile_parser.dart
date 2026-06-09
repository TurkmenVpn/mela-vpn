import 'dart:convert';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:melavpn/core/db/db.dart';
import 'package:melavpn/core/device_id/device_id_provider.dart';
import 'package:melavpn/core/http_client/dio_http_client.dart';
import 'package:melavpn/features/profile/data/profile_data_mapper.dart';
import 'package:melavpn/features/profile/model/profile_entity.dart';
import 'package:melavpn/features/profile/model/profile_failure.dart';
import 'package:melavpn/features/settings/data/config_option_repository.dart';
import 'package:melavpn/singbox/model/singbox_proxy_type.dart';
import 'package:melavpn/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:meta/meta.dart';

/// parse profile subscription url and headers for data
///
/// ***name parser hierarchy:***
/// - UserOverride.name
/// - `profile-title` header
/// - `content-disposition` header
/// - url fragment (example: `https://example.com/config#user`) -> name=`user`
/// - url filename extension (example: `https://example.com/config.json`) -> name=`config`
/// - if none of these methods return a non-blank string, switch(profileType)
/// - remote:  fallback to `Remote Profile`
/// - local: fallback to protocol, extracted from content by protocol()

class ProfileParser {
  static const infiniteTrafficThreshold = 920_233_720_368;
  static const infiniteTimeThreshold = 92_233_720_368;
  static const allowedOverrideConfigs = [
    'connection-test-url',
    'direct-dns-address',
    'remote-dns-address',
    'tls-tricks',
    'chain-status',
    'extra-security',
  ];
  static const allowedProfileHeaders = [
    'profile-title',
    'content-disposition',
    'subscription-userinfo',
    'profile-update-interval',
    'support-url',
    'profile-web-page-url',
    'profile-announce',
    'announce',
    'enable-warp',
    'enable-fragment',
  ];

  final Ref _ref;
  final DioHttpClient _httpClient;

  ProfileParser({required Ref ref, required DioHttpClient httpClient}) : _ref = ref, _httpClient = httpClient;
  TaskEither<ProfileFailure, ProfileEntriesCompanion> addLocal({
    required String id,
    required String content,
    required String tempFilePath,
    required UserOverride? userOverride,
  }) {
    return TaskEither.tryCatch(() async {
          await expandRemoteLinesInParallel(
            tempFilePath: tempFilePath,
            httpClient: _httpClient,
            cancelToken: CancelToken(),
            ref: _ref,
          );
        }, (_, _) => const ProfileFailure.unexpected())
        .flatMap((_) => TaskEither.fromEither(populateHeaders(content: content)))
        .flatMap(
          (populatedHeaders) => TaskEither.fromEither(
            parse(
              tempFilePath: tempFilePath,
              profile: ProfileEntity.local(
                id: id,
                active: true,
                name: '',
                lastUpdate: DateTime.now(),
                userOverride: userOverride,
                populatedHeaders: populatedHeaders,
              ),
            ).flatMap((profEntity) => Either.tryCatch(() => profEntity.toInsertEntry(), ProfileFailure.unexpected)),
          ),
        );
  }

  TaskEither<ProfileFailure, ProfileEntriesCompanion> addRemote({
    required String id,
    required String url,
    required String tempFilePath,
    required UserOverride? userOverride,
    CancelToken? cancelToken,
  }) => _downloadProfile(url, tempFilePath, cancelToken).flatMap(
    (remoteHeaders) =>
        TaskEither.fromEither(
          populateHeaders(content: File(tempFilePath).readAsStringSync(), remoteHeaders: remoteHeaders),
        ).flatMap(
          (populatedHeaders) => TaskEither.fromEither(
            parse(
              tempFilePath: tempFilePath,
              profile: ProfileEntity.remote(
                id: id,
                active: true,
                name: '',
                url: url,
                lastUpdate: DateTime.now(),
                userOverride: userOverride,
                populatedHeaders: populatedHeaders,
              ),
            ).flatMap((profEntity) => Either.tryCatch(() => profEntity.toInsertEntry(), ProfileFailure.unexpected)),
          ),
        ),
  );

  TaskEither<ProfileFailure, ProfileEntriesCompanion> updateRemote({
    required RemoteProfileEntity rp,
    required String tempFilePath,
    CancelToken? cancelToken,
  }) => _downloadProfile(rp.url, tempFilePath, cancelToken).flatMap(
    (remoteHeaders) =>
        TaskEither.fromEither(
          populateHeaders(content: File(tempFilePath).readAsStringSync(), remoteHeaders: remoteHeaders),
        ).flatMap(
          (populatedHeaders) => TaskEither.fromEither(
            parse(
              tempFilePath: tempFilePath,
              profile: rp.copyWith(populatedHeaders: populatedHeaders),
            ).flatMap((profEntity) => Either.tryCatch(() => profEntity.toUpdateEntry(), ProfileFailure.unexpected)),
          ),
        ),
  );

  Either<ProfileFailure, ProfileEntriesCompanion> offlineUpdate({
    required ProfileEntity profile,
    required String tempFilePath,
  }) => profile
      .map(
        remote: (rp) => parse(profile: rp, tempFilePath: tempFilePath),
        local: (lp) => parse(tempFilePath: tempFilePath, profile: lp),
      )
      .flatMap((profEntity) => Either.tryCatch(() => profEntity.toUpdateEntry(), ProfileFailure.unexpected));

  TaskEither<ProfileFailure, Map<String, dynamic>> _downloadProfile(
    String url,
    String tempFilePath,
    CancelToken? cancelToken,
  ) => TaskEither.tryCatch(() async {
    // if (url.startsWith("http://"))
    //   throw const ProfileFailure.invalidUrl('HTTP is not supported. Please use HTTPS for secure connection.');

    final sendHwid = _ref.read(sendHwidWithSubscription);
    final hwid = sendHwid ? _ref.read(deviceIdProvider) : null;

    final rs = await _httpClient
        .download(
          url.trim(),
          tempFilePath,
          cancelToken: cancelToken,
          userAgent: _ref.read(ConfigOptions.useXrayCoreWhenPossible)
              ? _httpClient.userAgent.replaceAll("MelaVPNNext", "MelaVPNNextX")
              : null,
          extraHeaders: {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
            if (hwid != null) 'X-HWID': hwid,
          },
        )
        .catchError((Object err) {
          if (err is DioException && CancelToken.isCancel(err)) {
            throw const ProfileFailure.cancelByUser('HTTP request for getting profile content canceled by user.');
          }
          throw err;
        });
    await expandRemoteLinesInParallel(
      tempFilePath: tempFilePath,
      httpClient: _httpClient,
      cancelToken: cancelToken ?? CancelToken(),
      ref: _ref,
    );
    // fixing headers before return
    return rs.headers.map.map((key, value) {
      if (value.length == 1) return MapEntry(key, value.first);
      return MapEntry(key, value);
    });
  }, (err, st) => err is ProfileFailure ? err : ProfileFailure.unexpected(err, st));
  Future<void> expandRemoteLinesInParallel({
    required String tempFilePath,
    required DioHttpClient httpClient,
    required CancelToken cancelToken,
    required Ref ref,
    int parallelism = 4,
  }) async {
    var content = await File(tempFilePath).readAsString();

    // If the entire content looks like base64, decode it first.
    // Classic V2Ray/Xray subscriptions return base64-encoded proxy URI lists,
    // often in MIME format with \r\n line breaks every 76 chars.
    final trimmed = content.trim();
    if (_looksLikeBase64(trimmed)) {
      // Strip all whitespace before decoding — dart:convert base64Decode
      // rejects any whitespace including MIME-style line breaks.
      final noWs = trimmed.replaceAll(RegExp(r'\s'), '');
      final decoded = safeDecodeBase64(noWs);
      if (decoded != noWs && _containsProxyUris(decoded)) {
        content = decoded;
        await File(tempFilePath).writeAsString(content);
      }
    }

    final lines = content.split('\n');
    final results = List<String?>.filled(lines.length, null);

    int index = 0;

    Future<void> worker() async {
      while (true) {
        if (cancelToken.isCancelled) return;

        final currentIndex = index++;
        if (currentIndex >= lines.length) return;

        final line = lines[currentIndex];

        // Non-URL: keep the line as-is (trimRight only removes trailing CR/space
        // without stripping leading whitespace needed by YAML/indented formats).
        if (!line.trimLeft().startsWith('http://') && !line.trimLeft().startsWith('https://')) {
          results[currentIndex] = line.trimRight();
          continue;
        }

        final tmpPath = '$tempFilePath.$currentIndex';
        try {
          await httpClient.download(
            line.trim(),
            tmpPath,
            cancelToken: cancelToken,
          );

          results[currentIndex] = (await File(tmpPath).readAsString()).trim();
        } catch (err) {
          results[currentIndex] = '';
          if (err is DioException && CancelToken.isCancel(err)) return;
        } finally {
          final tmp = File(tmpPath);
          if (tmp.existsSync()) tmp.deleteSync();
        }
      }
    }

    // Start workers
    await Future.wait(List.generate(parallelism, (_) => worker()));

    if (results.any((e) => e != null)) {
      final newContent = results.map((e) => e ?? '').join("\n");
      await File(tempFilePath).writeAsString(newContent);
    }
  }

  static final _base64Chars = RegExp(r'^[A-Za-z0-9+/=]+$');
  static final _proxySchemes = RegExp(r'(vless|vmess|ss|trojan|hysteria2?|hy2?|tuic|wg|ssh|shadowtls|mieru|warp)://', caseSensitive: false);

  static bool _looksLikeBase64(String s) {
    if (s.length < 20) return false;
    // JSON/YAML/proxy URIs contain these characters; base64 never does
    if (s.contains('{') || s.contains(':')) return false;
    // Strip whitespace: MIME base64 adds \r\n every 76 chars
    final noWs = s.replaceAll(RegExp(r'\s'), '');
    if (noWs.length < 20) return false;
    return _base64Chars.hasMatch(noWs);
  }

  static bool _containsProxyUris(String s) => _proxySchemes.hasMatch(s);

  static Either<ProfileFailure, Map<String, dynamic>> populateHeaders({
    required String content,
    Map<String, dynamic>? remoteHeaders,
  }) => Either.tryCatch(() {
    final contentHeaders = _parseHeadersFromContent(content);
    return _mergeAndValidateHeaders(contentHeaders, remoteHeaders ?? {});
  }, ProfileFailure.unexpected);

  static Map<String, dynamic> _mergeAndValidateHeaders(
    Map<String, dynamic> contentHeaders,
    Map<String, dynamic> remoteHeaders,
  ) {
    for (final entry in contentHeaders.entries) {
      if (!remoteHeaders.keys.contains(entry.key)) {
        remoteHeaders[entry.key] = entry.value;
      }
    }
    final headers = <String, dynamic>{};
    for (final entry in remoteHeaders.entries) {
      if (allowedProfileHeaders.contains(entry.key) && entry.value != null && entry.value.toString().isNotEmpty) {
        headers[entry.key] = entry.value;
      }
    }
    return headers;
  }

  static Map<String, dynamic> _parseHeadersFromContent(String content) {
    final headers = <String, dynamic>{};
    final content_ = safeDecodeBase64(content);
    final lines = content_.split("\n");
    final linesToProcess = lines.length < 10 ? lines.length : 10;
    for (int i = 0; i < linesToProcess; i++) {
      final line = lines[i];
      if (line.startsWith("#") || line.startsWith("//")) {
        final index = line.indexOf(':');
        if (index == -1) continue;
        final key = line.substring(0, index).replaceFirst(RegExp("^#|//"), "").trim().toLowerCase();
        final value = line.substring(index + 1).trim();
        headers[key] = value;
      }
    }
    return headers;
  }

  static SubscriptionInfo? _parseSubscriptionInfo(String subInfoStr) {
    final values = subInfoStr.split(';');
    final map = <String, int?>{};
    for (final v in values) {
      final eqIdx = v.indexOf('=');
      if (eqIdx < 0) continue;
      map[v.substring(0, eqIdx).trim()] = num.tryParse(v.substring(eqIdx + 1).trim())?.toInt();
    }
    if (map case {"upload": final upload?, "download": final download?, "total": final total, "expire": var expire}) {
      final total1 = (total == null || total == 0) ? infiniteTrafficThreshold + 1 : total;
      expire = (expire == null || expire == 0) ? infiniteTimeThreshold : expire;
      return SubscriptionInfo(
        upload: upload,
        download: download,
        total: total1,
        expire: DateTime.fromMillisecondsSinceEpoch(expire * 1000),
      );
    }
    return null;
  }

  @visibleForTesting
  static Either<ProfileFailure, ProfileEntity> parse({required String tempFilePath, required ProfileEntity profile}) =>
      Either.tryCatch(() {
        final headers = Map<String, dynamic>.from(profile.populatedHeaders ?? {});
        var name = '';
        if (profile.userOverride?.name case final String oName when oName.isNotEmpty) {
          name = oName;
        }

        if (headers['profile-title'] case final String titleHeader when name.isEmpty) {
          if (titleHeader.startsWith("base64:")) {
            final encoded = titleHeader.replaceFirst("base64:", "").trim();
            final decoded = safeDecodeBase64(encoded);
            if (decoded != encoded) name = decoded;
          } else {
            name = titleHeader.trim();
          }
        }
        if (headers['content-disposition'] case final String contentDispositionHeader when name.isEmpty) {
          final regExp = RegExp('filename="([^"]*)"');
          final match = regExp.firstMatch(contentDispositionHeader);
          if (match != null && match.groupCount >= 1) {
            name = match.group(1) ?? '';
          }
        }
        if (profile case RemoteProfileEntity(:final url)) {
          if (Uri.parse(url).fragment case final fragment when name.isEmpty) {
            name = fragment;
          }
          if (url.split("/").lastOrNull case final part? when name.isEmpty) {
            final pattern = RegExp(r"\.(json|yaml|yml|txt)[\s\S]*");
            name = part.replaceFirst(pattern, "");
          }
        }
        if (name.isBlank) {
          switch (profile) {
            case RemoteProfileEntity():
              name = "Remote Profile";

            case LocalProfileEntity():
              name = protocol(File(tempFilePath).readAsStringSync());
          }
        }

        final isAutoUpdateDisable = profile.userOverride?.isAutoUpdateDisable ?? false;
        ProfileOptions? options;
        if (profile.userOverride?.updateInterval case final int updateInterval
            when updateInterval > 0 && !isAutoUpdateDisable) {
          options = ProfileOptions(updateInterval: Duration(hours: updateInterval));
        }
        if (headers['profile-update-interval'] case final String updateIntervalStr
            when options == null && !isAutoUpdateDisable) {
          final hours = int.tryParse(updateIntervalStr);
          if (hours != null && hours > 0) {
            options = ProfileOptions(updateInterval: Duration(hours: hours));
          }
        }

        SubscriptionInfo? subInfo;
        if (headers['subscription-userinfo'] case final String subInfoStr) {
          subInfo = _parseSubscriptionInfo(subInfoStr);
        }

        if (subInfo != null) {
          if (headers['profile-web-page-url'] case final String profileWebPageUrl when isUrl(profileWebPageUrl)) {
            subInfo = subInfo.copyWith(webPageUrl: profileWebPageUrl);
          }
          if (headers['support-url'] case final String profileSupportUrl when isUrl(profileSupportUrl)) {
            subInfo = subInfo.copyWith(supportUrl: profileSupportUrl);
          }
        }

        return profile.map(
          remote: (rp) => rp.copyWith(name: name, lastUpdate: DateTime.now(), options: options, subInfo: subInfo),
          local: (lp) => lp.copyWith(name: name, lastUpdate: DateTime.now()),
        );
      }, ProfileFailure.unexpected);

  static String protocol(String content) {
    if (content.contains("[Interface]")) {
      return ProxyType.wireguard.label;
    }
    final lines = content.split('\n');
    String? name;
    for (final line in lines) {
      final uri = Uri.tryParse(line);
      if (uri == null) continue;
      final fragment = uri.hasFragment ? Uri.decodeComponent(uri.fragment.split(" -> ")[0]) : null;
      name ??= switch (uri.scheme) {
        'ss' => fragment ?? ProxyType.shadowsocks.label,
        'ssconf' => fragment ?? ProxyType.shadowsocks.label,
        'vmess' => ProxyType.vmess.label,
        'vless' => fragment ?? ProxyType.vless.label,
        'trojan' => fragment ?? ProxyType.trojan.label,
        'tuic' => fragment ?? ProxyType.tuic.label,
        'hy2' || 'hysteria2' => fragment ?? ProxyType.hysteria2.label,
        'hy' || 'hysteria' => fragment ?? ProxyType.hysteria.label,
        'ssh' => fragment ?? ProxyType.ssh.label,
        'wg' => fragment ?? ProxyType.wireguard.label,
        'awg' => fragment ?? ProxyType.awg.label,
        'shadowtls' => fragment ?? ProxyType.shadowtls.label,
        'mieru' => fragment ?? ProxyType.mieru.label,
        'warp' => fragment ?? ProxyType.warp.label,
        _ => null,
      };
    }
    return name ?? ProxyType.unknown.label;
  }

  static String profileOverrideHelper({required ProfileEntriesCompanion profile}) {
    final populatedHeaders = profile.populatedHeaders.value;

    Map<String, dynamic>? mPopulatedHeaders;
    if (populatedHeaders != null) {
      final m = jsonDecode(populatedHeaders) as Map;
      mPopulatedHeaders = m.cast<String, dynamic>();
    }

    return ProfileParser.profileOverride(
      populatedHeaders: mPopulatedHeaders,
      userOverride: UserOverride.fromStr(profile.userOverride.value),
    );
  }

  static String profileOverride({
    required Map<String, dynamic>? populatedHeaders,
    required UserOverride? userOverride,
  }) {
    final headers = Map<String, dynamic>.from(populatedHeaders ?? {});

    if (headers['enable-warp'].toString() == 'true' || userOverride?.enableWarp == true) {
      headers['chain-status'] = 'extra_security';
      headers['extra-security'] = {'mode': 'warp'};
    }

    if (headers['enable-fragment'].toString() == 'true' || userOverride?.enableFragment == true) {
      headers['tls-tricks'] = {'enable-fragment': true};
    }

    headers.removeWhere(
      (key, value) => !allowedOverrideConfigs.contains(key) || value == null || value.toString().isEmpty,
    );

    final profileOverrideStr = jsonEncode({for (final key in headers.keys) key: headers[key]});
    return profileOverrideStr;
  }

  static Map<String, dynamic> applyProfileOverride(Map<String, dynamic> main, String? profileOverride) {
    if (profileOverride == null) return main;
    if (profileOverride.contains("{")) {
      final profileOverrideMap = jsonDecode(profileOverride) as Map<String, dynamic>;
      return _mergeJson(main, profileOverrideMap);
    } else {
      return main;
    }
  }

  static Map<String, dynamic> _mergeJson(Map<String, dynamic> main, Map<String, dynamic> override) {
    override.forEach((key, value) {
      if (main.containsKey(key)) {
        if (main[key] is Map<String, dynamic> && value is Map<String, dynamic>) {
          main[key] = _mergeJson(main[key] as Map<String, dynamic>, value);
        } else {
          main[key] = value;
        }
      } else {
        main[key] = value;
      }
    });
    return main;
  }
}
