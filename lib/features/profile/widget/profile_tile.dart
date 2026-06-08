import 'dart:convert';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/model/constants.dart';
import 'package:melavpn/core/model/failures.dart';
import 'package:melavpn/core/notification/in_app_notification_controller.dart';
import 'package:melavpn/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:melavpn/core/router/dialog/dialog_notifier.dart';
import 'package:melavpn/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/core/widget/adaptive_icon.dart';
import 'package:melavpn/core/widget/adaptive_menu.dart';
import 'package:melavpn/features/profile/model/profile_entity.dart';
import 'package:melavpn/features/profile/notifier/profile_notifier.dart';
import 'package:melavpn/features/profile/notifier/profile_outbounds_notifier.dart';
import 'package:melavpn/features/profile/overview/profiles_notifier.dart';
import 'package:melavpn/features/connection/model/connection_status.dart';
import 'package:melavpn/features/connection/notifier/connection_notifier.dart';
import 'package:melavpn/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:melavpn/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';

// Maps common country name prefixes to flag emojis
String _flagForName(String name) {
  const flags = {
    'german': '🇩🇪', 'germany': '🇩🇪',
    'france': '🇫🇷', 'french': '🇫🇷',
    'italy': '🇮🇹', 'italia': '🇮🇹', 'italian': '🇮🇹',
    'netherlands': '🇳🇱', 'dutch': '🇳🇱', 'holland': '🇳🇱',
    'finland': '🇫🇮', 'finnish': '🇫🇮',
    'sweden': '🇸🇪', 'swedish': '🇸🇪',
    'norway': '🇳🇴', 'norwegian': '🇳🇴',
    'denmark': '🇩🇰', 'danish': '🇩🇰',
    'poland': '🇵🇱', 'polish': '🇵🇱',
    'russia': '🇷🇺', 'russian': '🇷🇺',
    'ukraine': '🇺🇦', 'ukrainian': '🇺🇦',
    'turkey': '🇹🇷', 'turkish': '🇹🇷',
    'iran': '🇮🇷', 'iranian': '🇮🇷',
    'china': '🇨🇳', 'chinese': '🇨🇳',
    'japan': '🇯🇵', 'japanese': '🇯🇵',
    'korea': '🇰🇷', 'korean': '🇰🇷',
    'usa': '🇺🇸', 'united states': '🇺🇸', 'america': '🇺🇸', 'american': '🇺🇸',
    'uk': '🇬🇧', 'united kingdom': '🇬🇧', 'britain': '🇬🇧', 'british': '🇬🇧', 'england': '🇬🇧',
    'canada': '🇨🇦', 'canadian': '🇨🇦',
    'australia': '🇦🇺', 'australian': '🇦🇺',
    'singapore': '🇸🇬',
    'india': '🇮🇳', 'indian': '🇮🇳',
    'brazil': '🇧🇷', 'brazilian': '🇧🇷',
    'spain': '🇪🇸', 'spanish': '🇪🇸',
    'austria': '🇦🇹',
    'switzerland': '🇨🇭', 'swiss': '🇨🇭',
    'estonia': '🇪🇪',
    'latvia': '🇱🇻',
    'lithuania': '🇱🇹',
    'czech': '🇨🇿', 'czechia': '🇨🇿',
    'hungary': '🇭🇺',
    'romania': '🇷🇴',
    'bulgaria': '🇧🇬',
    'greece': '🇬🇷', 'greek': '🇬🇷',
    'portugal': '🇵🇹',
    'belgium': '🇧🇪',
    'luxembourg': '🇱🇺',
    'serbia': '🇷🇸',
    'croatia': '🇭🇷',
    'moldova': '🇲🇩',
    'iceland': '🇮🇸',
    'cyprus': '🇨🇾',
    'mexico': '🇲🇽',
    'argentina': '🇦🇷',
    'colombia': '🇨🇴',
    'chile': '🇨🇱',
    'vietnam': '🇻🇳',
    'thailand': '🇹🇭',
    'indonesia': '🇮🇩',
    'malaysia': '🇲🇾',
    'philippines': '🇵🇭',
    'taiwan': '🇹🇼',
    'hong kong': '🇭🇰',
    'south africa': '🇿🇦',
    'israel': '🇮🇱',
    'dubai': '🇦🇪', 'uae': '🇦🇪',
    'saudi': '🇸🇦',
    'pakistan': '🇵🇰',
    'kazakhstan': '🇰🇿',
    'uzbekistan': '🇺🇿',
    'georgia': '🇬🇪',
    'armenia': '🇦🇲',
    'azerbaijan': '🇦🇿',
  };
  final lower = name.toLowerCase().trim();
  for (final entry in flags.entries) {
    if (lower.startsWith(entry.key)) return entry.value;
  }
  return '';
}

// Extract flag emoji: first try leading regional-indicator pair, then name lookup
String _extractFlag(String text) {
  final runes = text.runes.toList();
  // Regional Indicator Symbols: U+1F1E6–U+1F1FF (two = one flag)
  if (runes.length >= 2 &&
      runes[0] >= 0x1F1E6 && runes[0] <= 0x1F1FF &&
      runes[1] >= 0x1F1E6 && runes[1] <= 0x1F1FF) {
    return String.fromCharCodes([runes[0], runes[1]]);
  }
  return _flagForName(text);
}

// Remove leading flag emoji (regional-indicator pair) from display name
String _stripLeadingFlag(String text) {
  final runes = text.runes.toList();
  if (runes.length >= 2 &&
      runes[0] >= 0x1F1E6 && runes[0] <= 0x1F1FF &&
      runes[1] >= 0x1F1E6 && runes[1] <= 0x1F1FF) {
    return String.fromCharCodes(runes.skip(2)).trimLeft();
  }
  return text;
}

// Offline proxy selection — in-memory while app runs
final _offlineSelectedOutboundProvider = StateProvider.family<String, String>(
  (ref, profileId) => '',
);

// Offline ping results: profileId → {rawTag → ms}
final _offlinePingResultsProvider = StateProvider.family<Map<String, int>, String>(
  (ref, profileId) => {},
);

// Whether offline ping is in progress for a profile
final _offlinePingingProvider = StateProvider.family<bool, String>(
  (ref, profileId) => false,
);

Future<int> _tcpPing(String host, int port) async {
  if (host.isEmpty || port <= 0) return -1;
  final sw = Stopwatch()..start();
  try {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
    sw.stop();
    socket.destroy();
    return sw.elapsedMilliseconds;
  } catch (_) {
    return 65535;
  }
}

Future<void> _runOfflinePing(List<ProfileOutbound> items, String profileId, WidgetRef ref) async {
  if (ref.read(_offlinePingingProvider(profileId))) return;
  ref.read(_offlinePingingProvider(profileId).notifier).state = true;
  try {
    final futures = items
        .where((i) => i.host.isNotEmpty && i.port > 0)
        .map((item) async {
          final ms = await _tcpPing(item.host, item.port);
          return MapEntry(item.rawTag, ms);
        });
    final results = await Future.wait(futures);
    ref.read(_offlinePingResultsProvider(profileId).notifier).state = Map.fromEntries(results);
  } finally {
    ref.read(_offlinePingingProvider(profileId).notifier).state = false;
  }
}

String? _decodeAnnounce(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = utf8.decode(base64.decode(base64.normalize(raw)));
    return decoded.trim().isEmpty ? null : decoded.trim();
  } catch (_) {
    return raw.trim().isEmpty ? null : raw.trim();
  }
}

class ProfileTile extends HookConsumerWidget {
  const ProfileTile({super.key, required this.profile, this.isMain = false, this.margin = EdgeInsets.zero, this.color});

  final ProfileEntity profile;

  /// home screen active profile card
  final bool isMain;
  final EdgeInsets margin;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final selectActiveMutation = useMutation(
      initialOnFailure: (err) {
        ref.read(inAppNotificationControllerProvider).showErrorToast(t.presentShortError(err));
      },
      initialOnSuccess: () {
        if (context.mounted && context.canPop()) context.pop();
      },
    );

    final subInfo = switch (profile) {
      RemoteProfileEntity(:final subInfo) => subInfo,
      _ => null,
    };

    if (isMain) {
      return _MainProfileCard(profile: profile, subInfo: subInfo, t: t, theme: theme);
    }

    // List tile (non-main)
    final flag = _extractFlag(profile.name);
    final borderColor = profile.active ? MelaColors.primary.withValues(alpha: 0.5) : MelaColors.brd(context);
    final bgColor = profile.active ? MelaColors.primary.withValues(alpha: 0.06) : MelaColors.card(context);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: ProfileTileConst.cardBorderRadius,
        border: Border.all(color: borderColor, width: profile.active ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 52,
                child: Semantics(sortKey: const OrdinalSortKey(1), child: ProfileActionButton(profile, true)),
              ),
              Container(
                width: 1,
                color: profile.active ? MelaColors.primary.withValues(alpha: 0.2) : MelaColors.brd(context),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  child: InkWell(
                    borderRadius: ProfileTileConst.endBorderRadius(Directionality.of(context)),
                    onTap: () {
                      if (selectActiveMutation.state.isInProgress) return;
                      selectActiveMutation.setFuture(
                        ref.read(profilesNotifierProvider.notifier).selectActiveProfile(profile.id),
                      );
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.goNamed('home');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          if (flag.isNotEmpty) ...[
                            Text(flag, style: const TextStyle(fontSize: 20)),
                            const Gap(10),
                          ],
                          Expanded(
                            child: Text(
                              flag.isNotEmpty ? _stripLeadingFlag(profile.name) : profile.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: profile.active ? MelaColors.textPrim(context) : MelaColors.textSec(context),
                                fontWeight: profile.active ? FontWeight.w700 : FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                fontSize: 15,
                              ),
                              semanticsLabel: profile.active
                                  ? t.pages.profiles.activeProfileName(name: profile.name)
                                  : t.pages.profiles.nonActiveProfileName(name: profile.name),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: MelaColors.textHint(context), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainProfileCard extends HookConsumerWidget {
  const _MainProfileCard({required this.profile, required this.subInfo, required this.t, required this.theme});

  final ProfileEntity profile;
  final SubscriptionInfo? subInfo;
  final TranslationsEn t;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUpdating = ref.watch(updateProfileNotifierProvider(profile.id)).isLoading;
    final flag = _extractFlag(profile.name);
    final offlineSelectedTag = ref.watch(_offlineSelectedOutboundProvider(profile.id));
    final offlinePingResults = ref.watch(_offlinePingResultsProvider(profile.id));
    final isOfflinePinging = ref.watch(_offlinePingingProvider(profile.id));
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final isConnected = connectionStatus.valueOrNull == const Connected();
    final proxiesGroup = ref.watch(proxiesOverviewNotifierProvider);
    final offlineOutbounds = ref.watch(profileOutboundsProvider(profile.id));
    // groupTag: prefer live service, fallback to parsed selector tag from config
    final liveGroupTag = proxiesGroup.valueOrNull?.tag ?? '';
    final configSelectorTag = offlineOutbounds.valueOrNull?.selectorTag ?? '';
    final groupTag = liveGroupTag.isNotEmpty ? liveGroupTag : configSelectorTag;
    final serviceRunning = isConnected && liveGroupTag.isNotEmpty;
    // delay map from live service: rawTag → ms
    final delayMap = proxiesGroup.valueOrNull?.items.fold<Map<String, int>>(
      {},
      (m, i) => m..[i.tag] = i.urlTestDelay,
    ) ?? {};
    final liveSelectedTag = proxiesGroup.valueOrNull?.selected ?? '';
    final effectiveSelectedTag = liveSelectedTag.isNotEmpty ? liveSelectedTag : offlineSelectedTag;
    final isPinging = serviceRunning ? proxiesGroup.isLoading : isOfflinePinging;

    final updateInterval = switch (profile) {
      RemoteProfileEntity(:final options) => options?.updateInterval,
      _ => null,
    };

    final announceRaw = profile.populatedHeaders?['profile-announce'] as String?;
    final announce = _decodeAnnounce(announceRaw);

    return Container(
      decoration: BoxDecoration(
        color: MelaColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MelaColors.brd(context),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row — subscription name + count + refresh + "..."
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              children: [
                if (flag.isNotEmpty) ...[
                  Text(flag, style: const TextStyle(fontSize: 20)),
                  const Gap(8),
                ],
                Expanded(
                  child: Text(
                    flag.isNotEmpty ? _stripLeadingFlag(profile.name) : profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MelaColors.textPrim(context),
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      fontFamily: null,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Key count badge
                offlineOutbounds.whenData((result) {
                  if (result.items.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: MelaColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${result.items.length}',
                      style: const TextStyle(
                        color: MelaColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).valueOrNull ?? const SizedBox.shrink(),
                // Refresh button (remote only)
                if (profile is RemoteProfileEntity)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: MelaColors.primary),
                          )
                        : const Icon(Icons.refresh_rounded, color: MelaColors.primary, size: 20),
                    onPressed: isUpdating
                        ? null
                        : () => ref
                            .read(updateProfileNotifierProvider(profile.id).notifier)
                            .updateProfile(profile as RemoteProfileEntity),
                  ),
                // More menu
                ProfileActionsMenu(
                  profile,
                  (context, toggleVisibility, _) => IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(Icons.more_horiz_rounded, color: MelaColors.textSec(context), size: 22),
                    onPressed: toggleVisibility,
                  ),
                ),
              ],
            ),
          ),

          // Last update + auto-update interval
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
            child: _UpdateInfo(profile: profile, updateInterval: updateInterval),
          ),

          const Gap(8),

          // Traffic bar + expiry
          if (subInfo != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _TrafficSection(subInfo: subInfo!),
            ),
            const Gap(8),
          ],

          // Announce message from subscription (base64 decoded)
          if (announce != null && announce.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    const Color(0xFF06B6D4).withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MelaColors.primary.withValues(alpha: 0.25), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: MelaColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.mark_email_unread_rounded, color: MelaColors.primary, size: 14),
                      ),
                      const Gap(8),
                      const Text(
                        'Сообщение от провайдера',
                        style: TextStyle(
                          color: MelaColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const Gap(8),
                  Text(
                    announce,
                    style: TextStyle(
                      color: MelaColors.textPrim(context),
                      fontSize: 13,
                      fontFamily: null,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          // Servers list — always visible (no service needed)
          offlineOutbounds.whenData((result) {
            if (result.items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section header: "Серверы" + ping button
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: MelaColors.brd(context).withValues(alpha: 0.4),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
                  child: Row(
                    children: [
                      Text(
                        'Серверы',
                        style: TextStyle(
                          color: MelaColors.textHint(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      // Ping button — works with and without VPN service
                      GestureDetector(
                        onTap: isPinging ? null : () {
                          if (serviceRunning) {
                            ref.read(proxiesOverviewNotifierProvider.notifier).urlTest(groupTag);
                          } else {
                            _runOfflinePing(result.items, profile.id, ref);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: isPinging
                                ? MelaColors.secondary.withValues(alpha: 0.1)
                                : MelaColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: MelaColors.secondary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPinging)
                                SizedBox(
                                  width: 11, height: 11,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: MelaColors.secondary,
                                  ),
                                )
                              else
                                Icon(Icons.wifi_tethering_rounded, size: 13, color: MelaColors.secondary),
                              const Gap(5),
                              Text(
                                isPinging ? 'ПИНГ...' : 'ПИНГ',
                                style: TextStyle(
                                  color: MelaColors.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...result.items.map((item) => _OfflineProxyRow(
                  item: item,
                  groupTag: groupTag,
                  profileId: profile.id,
                  selectedTag: effectiveSelectedTag,
                  serviceRunning: serviceRunning,
                  delay: serviceRunning ? delayMap[item.rawTag] : offlinePingResults[item.rawTag],
                )),
              ],
            );
          }).valueOrNull ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// Строка конфига на главном экране — работает без запущенного сервиса
class _OfflineProxyRow extends ConsumerWidget {
  const _OfflineProxyRow({
    required this.item,
    required this.groupTag,
    required this.profileId,
    required this.selectedTag,
    required this.serviceRunning,
    this.delay,
  });
  final ProfileOutbound item;
  final String groupTag;
  final String profileId;
  final String selectedTag;
  final bool serviceRunning;
  final int? delay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flag = _extractFlag(item.tag);
    final displayName = flag.isNotEmpty ? _stripLeadingFlag(item.tag) : item.tag;
    final isActive = item.rawTag == selectedTag || item.tag == selectedTag;
    final delayColor = delay == null || delay! <= 0 || delay! >= 65000
        ? MelaColors.textHint(context)
        : delay! < 800
            ? const Color(0xFF22C55E)
            : delay! < 1500
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);

    return InkWell(
      onTap: () {
        if (serviceRunning && groupTag.isNotEmpty) {
          ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy(groupTag, item.rawTag);
        } else {
          ref.read(_offlineSelectedOutboundProvider(profileId).notifier).state = item.rawTag;
        }
      },
      child: Container(
        color: isActive ? MelaColors.primary.withValues(alpha: 0.06) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            if (flag.isNotEmpty)
              SizedBox(width: 28, child: Text(flag, style: const TextStyle(fontSize: 18)))
            else
              Container(
                width: 28,
                height: 20,
                decoration: BoxDecoration(
                  color: MelaColors.surf(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? MelaColors.primary : MelaColors.textPrim(context),
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (item.type.isNotEmpty)
                    Text(
                      item.type,
                      style: TextStyle(
                        color: MelaColors.textHint(context),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (delay != null && delay! > 0 && delay! < 65000)
              Text(
                '${delay}мс',
                style: TextStyle(
                  color: delayColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (delay != null && delay! >= 65000)
              Text('×', style: TextStyle(color: delayColor, fontSize: 14, fontWeight: FontWeight.w700)),
            const Gap(6),
            if (isActive)
              const Icon(Icons.check_circle_rounded, color: MelaColors.primary, size: 16)
            else
              Icon(Icons.radio_button_unchecked_rounded, color: MelaColors.textHint(context), size: 16),
          ],
        ),
      ),
    );
  }
}


class _UpdateInfo extends StatelessWidget {
  const _UpdateInfo({required this.profile, required this.updateInterval});

  final ProfileEntity profile;
  final Duration? updateInterval;

  @override
  Widget build(BuildContext context) {
    final lastUpdate = profile.lastUpdate;
    final dateStr = intl.DateFormat('dd.MM.yyyy HH:mm').format(lastUpdate);
    final intervalStr = switch (updateInterval) {
      null => '',
      Duration(inHours: final h) when h > 0 => ' · Auto $h h',
      _ => '',
    };
    return Text(
      '$dateStr$intervalStr',
      style: TextStyle(color: MelaColors.textHint(context), fontSize: 11),
    );
  }
}

class _TrafficSection extends StatelessWidget {
  const _TrafficSection({required this.subInfo});

  final SubscriptionInfo subInfo;

  @override
  Widget build(BuildContext context) {
    final isExpired = subInfo.isExpired;
    final isNoTraffic = subInfo.ratio >= 1;
    final trackColor = subInfo.ratio < 0.5
        ? MelaColors.connected
        : subInfo.ratio < 0.8
            ? MelaColors.reconnect
            : const Color(0xFFEF4444);

    final trafficText = subInfo.total > 10 * 1099511627776
        ? '0B / ∞'
        : subInfo.consumption.sizeOf(subInfo.total);

    final expiryStr = isExpired
        ? 'Expired'
        : subInfo.remaining.inDays > 365
            ? '∞'
            : intl.DateFormat('dd.MM.yyyy').format(subInfo.expire);

    final Color statusColor = isExpired || isNoTraffic ? const Color(0xFFEF4444) : MelaColors.textSec(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                trafficText,
                style: TextStyle(
                  color: MelaColors.textPrim(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              isExpired ? 'Expired' : isNoTraffic ? 'No traffic' : 'Exp: $expiryStr',
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const Gap(5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: subInfo.ratio.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: MelaColors.brd(context),
            valueColor: AlwaysStoppedAnimation<Color>(trackColor),
          ),
        ),
      ],
    );
  }
}

class ProfileActionButton extends HookConsumerWidget {
  const ProfileActionButton(this.profile, this.showAllActions, {super.key});

  final ProfileEntity profile;
  final bool showAllActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    if (profile case RemoteProfileEntity() when !showAllActions) {
      return Semantics(
        button: true,
        enabled: !ref.watch(updateProfileNotifierProvider(profile.id)).isLoading,
        child: Tooltip(
          message: t.pages.profiles.update,
          child: InkWell(
            borderRadius: ProfileTileConst.startBorderRadius(Directionality.of(context)),
            onTap: () {
              if (ref.read(updateProfileNotifierProvider(profile.id)).isLoading) return;
              ref.read(updateProfileNotifierProvider(profile.id).notifier).updateProfile(profile as RemoteProfileEntity);
            },
            child: const Icon(Icons.refresh_rounded, color: MelaColors.primary, size: 22),
          ),
        ),
      );
    }
    return ProfileActionsMenu(profile, (context, toggleVisibility, _) {
      return Semantics(
        button: true,
        child: Tooltip(
          message: MaterialLocalizations.of(context).showMenuTooltip,
          child: InkWell(
            borderRadius: ProfileTileConst.startBorderRadius(Directionality.of(context)),
            onTap: toggleVisibility,
            child: Icon(Icons.more_vert_rounded, color: MelaColors.textSec(context), size: 22),
          ),
        ),
      );
    });
  }
}

class ProfileActionsMenu extends HookConsumerWidget {
  const ProfileActionsMenu(this.profile, this.builder, {super.key, this.child});

  final ProfileEntity profile;
  final AdaptiveMenuBuilder builder;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final menuItems = [
      if (profile case RemoteProfileEntity())
        AdaptiveMenuItem(
          title: t.common.update,
          leadingIcon: const Icon(Icons.update_rounded),
          onTap: () {
            if (ref.read(updateProfileNotifierProvider(profile.id)).isLoading) {
              return;
            }
            ref.read(updateProfileNotifierProvider(profile.id).notifier).updateProfile(profile as RemoteProfileEntity);
          },
        ),
      AdaptiveMenuItem(
        title: t.common.share,
        leadingIcon: Icon(AdaptiveIcon(context).share),
        subItems: [
          if (profile case RemoteProfileEntity(:final url, :final name)) ...[
            AdaptiveMenuItem(
              title: t.pages.profiles.share.urlToClipboard,
              onTap: () async {
                final link = LinkParser.generateSubShareLink(url, name);
                if (link.isNotEmpty) {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ref
                        .read(inAppNotificationControllerProvider)
                        .showSuccessToast(t.common.msg.export.clipboard.success);
                  }
                }
              },
            ),
            AdaptiveMenuItem(
              title: 'Crypt-ссылка — копировать',
              leadingIcon: const Icon(Icons.lock_outline_rounded),
              onTap: () async {
                final link = await LinkParser.generateCryptLink(url, name);
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) {
                  ref
                      .read(inAppNotificationControllerProvider)
                      .showSuccessToast(t.common.msg.export.clipboard.success);
                }
              },
            ),
            AdaptiveMenuItem(
              title: 'Crypt-ссылка — QR-код',
              leadingIcon: const Icon(Icons.qr_code_rounded),
              onTap: () async {
                final link = await LinkParser.generateCryptLink(url, name);
                await ref.read(dialogNotifierProvider.notifier).showQrCode(link, message: name);
              },
            ),
            AdaptiveMenuItem(
              title: t.pages.profiles.share.showUrlQr,
              onTap: () async {
                final link = LinkParser.generateSubShareLink(url, name);
                if (link.isNotEmpty) {
                  await ref.read(dialogNotifierProvider.notifier).showQrCode(link, message: name);
                }
              },
            ),
          ],
          AdaptiveMenuItem(
            title: t.pages.profiles.share.jsonToClipboard,
            onTap: () async => await ref.read(profilesNotifierProvider.notifier).exportConfigToClipboard(profile),
          ),
        ],
      ),
      AdaptiveMenuItem(
        leadingIcon: const Icon(Icons.delete_outline_rounded),
        title: t.common.delete,
        onTap: () async => await ref
            .read(dialogNotifierProvider.notifier)
            .showConfirmation(
              title: t.dialogs.confirmation.profile.delete.title,
              message: t.dialogs.confirmation.profile.delete.msg,
            )
            .then((deleteConfirmed) async {
              if (!deleteConfirmed) return;
              await ref.read(profilesNotifierProvider.notifier).deleteProfile(profile);
            }),
      ),
    ];

    return AdaptiveMenu(builder: builder, items: menuItems, child: child);
  }
}

// TODO add support url
class ProfileSubscriptionInfo extends HookConsumerWidget {
  const ProfileSubscriptionInfo(this.subInfo, {super.key});

  final SubscriptionInfo subInfo;

  (String, Color?) remainingText(TranslationsEn t, ThemeData theme) {
    if (subInfo.isExpired) {
      return (t.components.subscriptionInfo.expired, theme.colorScheme.error);
    } else if (subInfo.ratio >= 1) {
      return (t.components.subscriptionInfo.noTraffic, theme.colorScheme.error);
    } else if (subInfo.remaining.inDays > 365) {
      return (t.components.subscriptionInfo.remainingDuration(duration: "∞"), null);
    } else {
      return (t.components.subscriptionInfo.remainingDuration(duration: subInfo.remaining.inDays), null);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final remaining = remainingText(t, theme);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Flexible(
            child: Text(
              subInfo.total > 10 * 1099511627776 ? '∞ GiB' : subInfo.consumption.sizeOf(subInfo.total),
              semanticsLabel: t.components.subscriptionInfo.remainingTrafficSemanticLabel(
                consumed: subInfo.consumption.sizeGB(),
                total: subInfo.total.sizeGB(),
              ),
              style: TextStyle(color: MelaColors.textSec(context), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Flexible(
          child: Text(
            remaining.$1,
            style: TextStyle(
              color: remaining.$2 ?? MelaColors.textSec(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// TODO add support url
class NewTrafficSubscriptionInfo extends HookConsumerWidget {
  const NewTrafficSubscriptionInfo(this.subInfo, {super.key});

  final SubscriptionInfo subInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    return Column(
      children: [
        const Icon(Icons.assessment_rounded, color: Colors.blue),
        Text(t.components.subscriptionInfo.remainingTraffic),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                subInfo.total >
                        10 *
                            1099511627776 //10TB
                    ? "∞ GiB"
                    : subInfo.consumption.sizeOf(subInfo.total),
                semanticsLabel: t.components.subscriptionInfo.remainingTrafficSemanticLabel(
                  consumed: subInfo.consumption.sizeGB(),
                  total: subInfo.total.sizeGB(),
                ),
                // style: theme.textTheme.body,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// TODO add support url
class NewDaySubscriptionInfo extends HookConsumerWidget {
  const NewDaySubscriptionInfo(this.subInfo, {super.key});

  final SubscriptionInfo subInfo;

  (String, Color?) remainingText(TranslationsEn t, ThemeData theme) {
    if (subInfo.isExpired) {
      return (t.components.subscriptionInfo.expired, theme.colorScheme.error);
    } else if (subInfo.ratio >= 1) {
      return (t.components.subscriptionInfo.noTraffic, theme.colorScheme.error);
    } else if (subInfo.remaining.inDays > 365) {
      return (t.components.subscriptionInfo.remainingDurationNew(duration: "∞"), null);
    } else {
      return (t.components.subscriptionInfo.remainingDurationNew(duration: subInfo.remaining.inDays), null);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final remaining = remainingText(t, theme);
    return Column(
      children: [
        const Icon(Icons.timer, color: Colors.blue),
        Text(t.components.subscriptionInfo.remainingTime),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                remaining.$1,
                // style: theme.textTheme.bodySmall?.copyWith(color: remaining.$2),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// TODO add support url
class NewDayTrafficSubscriptionInfo extends HookConsumerWidget {
  const NewDayTrafficSubscriptionInfo(this.subInfo, {super.key});

  final SubscriptionInfo subInfo;

  (String, Color?) remainingText(TranslationsEn t, ThemeData theme) {
    if (subInfo.isExpired) {
      return (t.components.subscriptionInfo.expired, theme.colorScheme.error);
    } else if (subInfo.ratio >= 1) {
      return (t.components.subscriptionInfo.noTraffic, theme.colorScheme.error);
    } else if (subInfo.remaining.inDays > 365) {
      return (t.components.subscriptionInfo.remainingDurationNew(duration: "∞"), null);
    } else {
      return (t.components.subscriptionInfo.remainingDurationNew(duration: subInfo.remaining.inDays), null);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final remaining = remainingText(t, theme);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.assessment_rounded, color: Colors.blue),
        Text(t.components.subscriptionInfo.remainingUsage),
        const SizedBox(height: 4),
        Text(
          remaining.$1,
          // style: theme.textTheme.bodySmall?.copyWith(color: remaining.$2),
          overflow: TextOverflow.ellipsis,
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            subInfo.total >
                    10 *
                        1099511627776 //10TB
                ? "∞ GiB"
                : subInfo.consumption.sizeOf(subInfo.total),
            semanticsLabel: t.components.subscriptionInfo.remainingTrafficSemanticLabel(
              consumed: subInfo.consumption.sizeGB(),
              total: subInfo.total.sizeGB(),
            ),
            // style: theme.textTheme.body,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class NewSiteSubscriptionInfo extends HookConsumerWidget {
  const NewSiteSubscriptionInfo(this.subInfo, {super.key});

  final SubscriptionInfo subInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final uri = Uri.parse(subInfo.webPageUrl ?? "");
    var host = uri.host;
    if (["telegram.me", "t.me"].contains(host)) {
      host = "@${uri.path.split("/").last}";
    }
    return InkWell(
      onTap: () => launchUrl(Uri.parse(subInfo.webPageUrl ?? "")),
      child: Column(
        children: [
          const Icon(FluentIcons.globe_person_24_filled, size: 24, color: Colors.blue),
          Text(t.components.subscriptionInfo.profileSite),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  host,
                  // style: theme.textTheme.bodySmall?.copyWith(color: remaining.$2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RemainingTrafficIndicator extends StatelessWidget {
  const RemainingTrafficIndicator(this.ratio, {super.key});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final trackColor = ratio < 0.5
        ? MelaColors.connected
        : ratio < 0.8
            ? MelaColors.reconnect
            : const Color(0xFFEF4444);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 5,
        backgroundColor: MelaColors.brd(context),
        valueColor: AlwaysStoppedAnimation<Color>(trackColor),
      ),
    );
  }
}
