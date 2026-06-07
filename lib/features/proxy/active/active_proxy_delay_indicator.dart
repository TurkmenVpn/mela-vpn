import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/core/widget/shimmer_skeleton.dart';
import 'package:melavpn/features/proxy/active/active_proxy_notifier.dart';
import 'package:melavpn/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ActiveProxyDelayIndicator extends HookConsumerWidget with InfraLogger {
  const ActiveProxyDelayIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final activeProxy = ref.watch(activeProxyNotifierProvider);

    if (activeProxy is! AsyncData) return const SizedBox();

    final proxy = activeProxy.value!;
    final delay = proxy.urlTestDelay;
    final timeout = delay > 65000;

    final delayColor = timeout
        ? MelaColors.disconnected
        : delay < 200
            ? MelaColors.connected
            : delay < 500
                ? MelaColors.reconnect
                : const Color(0xFFEF4444);

    return Center(
      child: GestureDetector(
        onTap: () async {
          try {
            await ref.read(activeProxyNotifierProvider.notifier).urlTest('');
          } catch (e) {
            loggy.error('Error during URL test: $e');
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          decoration: BoxDecoration(
            color: delayColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: delayColor.withValues(alpha: 0.2), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SignalIcon(color: delayColor),
              const Gap(6),
              if (delay > 0)
                Text.rich(
                  semanticsLabel: timeout ? t.pages.proxies.delay.timeout : t.pages.proxies.delay.result(delay: delay),
                  TextSpan(
                    children: [
                      if (timeout)
                        TextSpan(
                          text: t.common.timeout,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: delayColor,
                            fontSize: 13,
                          ),
                        )
                      else ...[
                        TextSpan(
                          text: delay.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: delayColor,
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                          text: ' ms',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: delayColor.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Semantics(label: t.pages.proxies.delay.testing, child: const ShimmerSkeleton(width: 40, height: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalIcon extends StatelessWidget {
  const _SignalIcon({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Bar(height: 5, color: color),
        const Gap(2),
        _Bar(height: 9, color: color),
        const Gap(2),
        _Bar(height: 13, color: color),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
