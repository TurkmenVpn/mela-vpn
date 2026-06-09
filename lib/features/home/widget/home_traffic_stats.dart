import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/features/connection/model/connection_status.dart';
import 'package:melavpn/features/connection/notifier/connection_notifier.dart';
import 'package:melavpn/features/stats/notifier/stats_notifier.dart';
import 'package:melavpn/features/stats/widget/speed_chart.dart';
import 'package:melavpn/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:melavpn/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class HomeTrafficStats extends HookConsumerWidget {
  const HomeTrafficStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(
      connectionNotifierProvider.select((v) => v.valueOrNull ?? const Disconnected()),
    );
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final isConnected = connectionStatus == const Connected();

    final elapsed = useState(Duration.zero);

    useEffect(() {
      if (!isConnected) {
        elapsed.value = Duration.zero;
        return null;
      }
      DateTime startTime() => ref.read(connectionNotifierProvider.notifier).connectedAt ?? DateTime.now();
      elapsed.value = DateTime.now().difference(startTime());
      final timer = Stream.periodic(const Duration(seconds: 1)).listen((_) {
        elapsed.value = DateTime.now().difference(startTime());
      });
      return timer.cancel;
    }, [isConnected]);

    return AnimatedOpacity(
      opacity: isConnected ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: isConnected
            ? Padding(
                padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: MelaColors.card(context).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MelaColors.brd(context).withValues(alpha: 0.5), width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Speed row: UP | TIME | DOWN
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            icon: Icons.arrow_upward_rounded,
                            iconColor: MelaColors.secondary,
                            label: 'UP',
                            value: stats.uplink.toInt().speed(),
                          ),
                          _Divider(),
                          _TimerItem(elapsed: elapsed.value),
                          _Divider(),
                          _StatItem(
                            icon: Icons.arrow_downward_rounded,
                            iconColor: MelaColors.connected,
                            label: 'DOWN',
                            value: stats.downlink.toInt().speed(),
                          ),
                        ],
                      ),
                      // Speed sparkline chart
                      const Gap(10),
                      const SpeedChart(height: 44),
                      // Total transferred
                      const Gap(6),
                      _TotalRow(stats: stats),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.stats});

  final SystemInfo stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.arrow_upward_rounded, size: 11, color: MelaColors.secondary.withValues(alpha: 0.7)),
        const Gap(2),
        Text(
          stats.uplinkTotal.toInt().size(),
          style: TextStyle(
            color: MelaColors.textHint(context),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(12),
        Icon(Icons.arrow_downward_rounded, size: 11, color: MelaColors.connected.withValues(alpha: 0.7)),
        const Gap(2),
        Text(
          stats.downlinkTotal.toInt().size(),
          style: TextStyle(
            color: MelaColors.textHint(context),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Container(
        width: 1,
        height: 32,
        color: MelaColors.brd(context).withValues(alpha: 0.6),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 12, color: iconColor),
            ),
            const Gap(6),
            Builder(
              builder: (context) => Text(
                value,
                style: TextStyle(
                  color: MelaColors.textPrim(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const Gap(2),
        Builder(
          builder: (context) => Text(
            label,
            style: TextStyle(
              color: MelaColors.textHint(context),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerItem extends StatelessWidget {
  const _TimerItem({required this.elapsed});
  final Duration elapsed;

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (context) => Text(
            _format(elapsed),
            style: TextStyle(
              color: MelaColors.textPrim(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 1.0,
            ),
          ),
        ),
        const Gap(2),
        Builder(
          builder: (context) => Text(
            'TIME',
            style: TextStyle(
              color: MelaColors.textHint(context),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
