import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/router/dialog/dialog_notifier.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/features/connection/model/connection_status.dart';
import 'package:melavpn/features/connection/notifier/connection_notifier.dart';
import 'package:melavpn/features/proxy/active/active_proxy_notifier.dart';
import 'package:melavpn/features/proxy/active/ip_widget.dart';
import 'package:melavpn/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:melavpn/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ActiveProxyFooter extends ConsumerWidget with InfraLogger {
  const ActiveProxyFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(
      connectionNotifierProvider.select((v) => v.valueOrNull ?? const Disconnected()),
    );
    final activeProxy = ref.watch(activeProxyNotifierProvider.select((v) => v.valueOrNull));
    final t = ref.watch(translationsProvider).requireValue;

    if (connectionState != const Connected() || activeProxy == null) {
      return const SizedBox.shrink();
    }

    Future<void> handleUrlTest() async {
      try {
        if (!context.mounted) return;
        await ref.read(activeProxyNotifierProvider.notifier).urlTest('');
      } catch (e) {
        loggy.error('Error during URL test: $e');
      }
    }

    return GestureDetector(
      onTap: () => context.goNamed('proxies'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MelaColors.surf(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MelaColors.brd(context).withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () async {
                await handleUrlTest();
                if (context.mounted) {
                  await ref.read(dialogNotifierProvider.notifier).showProxyInfo(outboundInfo: activeProxy);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MelaColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MelaColors.primary.withValues(alpha: 0.2), width: 1),
                ),
                child: IPCountryFlag(
                  countryCode: activeProxy.ipinfo.countryCode,
                  organization: activeProxy.ipinfo.org,
                  size: 36,
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeProxy.tagDisplay,
                    style: TextStyle(
                      color: MelaColors.textPrim(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(4),
                  Row(
                    children: [
                      if (activeProxy.ipinfo.ip.isNotEmpty)
                        Flexible(
                          child: IPText(
                            ip: activeProxy.ipinfo.ip,
                            onLongPress: handleUrlTest,
                            constrained: true,
                          ),
                        )
                      else
                        Flexible(
                          child: UnknownIPText(text: t.pages.proxies.unknownIp, onTap: handleUrlTest),
                        ),
                      const Gap(8),
                      _ProxyTypeBadge(type: activeProxy.type),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: MelaColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: MelaColors.primary,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProxyTypeBadge extends StatelessWidget {
  const _ProxyTypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MelaColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MelaColors.secondary.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: MelaColors.secondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

String getRealOutboundTag(OutboundInfo group) {
  var tag = group.tagDisplay;
  if (group.groupSelectedTagDisplay != '' && group.groupSelectedTagDisplay != tag) {
    tag = '$tag → ${group.groupSelectedTagDisplay}';
  }
  return tag;
}
