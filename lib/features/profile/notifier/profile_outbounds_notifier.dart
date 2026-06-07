import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:melavpn/features/profile/data/profile_data_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_outbounds_notifier.g.dart';

class ProfileOutbound {
  const ProfileOutbound({required this.tag, required this.rawTag, required this.type, this.host = '', this.port = 0});
  final String tag;     // display name (§ stripped)
  final String rawTag;  // original tag for changeProxy API
  final String type;
  final String host;
  final int port;

  static const _skipTypes = {'selector', 'urltest', 'dns', 'block'};
  static const _skipTags  = {'direct', 'bypass', 'direct-fragment', 'dns-out', 'block'};

  static bool keep(Map<String, dynamic> o) {
    final type = (o['type'] as String?)?.toLowerCase();
    final tag  = (o['tag']  as String?)?.toLowerCase();
    if (type == null) return false;
    if (_skipTypes.any(type.startsWith)) return false;
    if (tag != null && _skipTags.any(tag.startsWith)) return false;
    return true;
  }
}

class ProfileOutboundsResult {
  const ProfileOutboundsResult({required this.selectorTag, required this.items});
  final String selectorTag; // tag of the selector/proxy group
  final List<ProfileOutbound> items;
}

@riverpod
Future<ProfileOutboundsResult> profileOutbounds(Ref ref, String profileId) async {
  final repo = await ref.watch(profileRepositoryProvider.future);

  final configStr = await repo
      .generateConfig(profileId)
      .getOrElse((_) => '')
      .run()
      .then((s) async {
        if (s.isNotEmpty) return s;
        return repo.getRawConfig(profileId).getOrElse((_) => '').run();
      });

  if (configStr.isEmpty) return const ProfileOutboundsResult(selectorTag: '', items: []);

  try {
    final json = jsonDecode(configStr);
    if (json is! Map<String, dynamic>) return const ProfileOutboundsResult(selectorTag: '', items: []);
    final raw = json['outbounds'];
    if (raw is! List) return const ProfileOutboundsResult(selectorTag: '', items: []);

    String selectorTag = '';
    final items = <ProfileOutbound>[];

    for (final o in raw) {
      if (o is! Map<String, dynamic>) continue;
      final type = o['type'] as String? ?? '';
      final rawTag = o['tag'] as String? ?? '';
      // capture selector group tag
      if ((type == 'selector' || type == 'urltest') && selectorTag.isEmpty) {
        selectorTag = rawTag;
        continue;
      }
      if (!ProfileOutbound.keep(o)) continue;
      final displayTag = rawTag.replaceAll(RegExp(r'§[^§]*§?'), '').trim();
      if (displayTag.isEmpty) continue;
      final host = (o['server'] as String?) ?? '';
      final port = (o['server_port'] as int?) ?? 0;
      items.add(ProfileOutbound(tag: displayTag, rawTag: rawTag, type: type, host: host, port: port));
    }

    return ProfileOutboundsResult(selectorTag: selectorTag, items: items);
  } catch (_) {
    return const ProfileOutboundsResult(selectorTag: '', items: []);
  }
}
