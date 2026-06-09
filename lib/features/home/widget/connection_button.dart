import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/core/widget/animated_text.dart';
import 'package:melavpn/features/connection/model/connection_status.dart';
import 'package:melavpn/features/connection/notifier/connection_notifier.dart';
import 'package:melavpn/features/profile/notifier/active_profile_notifier.dart';
import 'package:melavpn/features/proxy/active/active_proxy_notifier.dart';
import 'package:melavpn/features/settings/notifier/config_option/config_option_notifier.dart';

class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    final delay = activeProxy.valueOrNull?.urlTestDelay ?? 0;
    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;

    final buttonColor = switch (connectionStatus) {
      AsyncData(value: Connected()) when requiresReconnect == true => MelaColors.reconnect,
      AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => MelaColors.reconnect,
      AsyncData(value: Connected()) => MelaColors.connected,
      AsyncData(value: _) => MelaColors.disconnected,
      _ => const Color(0xFFEF4444),
    };

    final isConnecting = switch (connectionStatus) {
      AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => true,
      AsyncData(value: Connecting()) => true,
      AsyncData(value: _) when connectionStatus.isLoading => true,
      _ => false,
    };

    return _MelaConnectionButton(
      onTap: switch (connectionStatus) {
        AsyncData(value: Connected()) when requiresReconnect == true => () async {
          final activeProfile = await ref.read(activeProfileProvider.future);
          return await ref.read(connectionNotifierProvider.notifier).reconnect(activeProfile);
        },
        AsyncData(value: Connecting()) => () async {
          await ref.read(connectionNotifierProvider.notifier).abortConnection();
        },
        AsyncData(value: Disconnected()) || AsyncError() => () async {
          if (ref.read(activeProfileProvider).valueOrNull == null) {
            ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
            return;
          }
          return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        },
        AsyncData(value: Connected()) => () async {
          if (requiresReconnect == true) {
            return await ref
                .read(connectionNotifierProvider.notifier)
                .reconnect(await ref.read(activeProfileProvider.future));
          }
          return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        },
        _ => () {},
      },
      enabled: switch (connectionStatus) {
        AsyncData(value: Connected()) ||
        AsyncData(value: Disconnected()) ||
        AsyncData(value: Connecting()) ||
        AsyncError() =>
          true,
        _ => false,
      },
      label: switch (connectionStatus) {
        AsyncData(value: Connected()) when requiresReconnect == true => t.connection.reconnect,
        AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => t.connection.connecting,
        AsyncData(value: final status) => status.present(t),
        _ => '',
      },
      buttonColor: buttonColor,
      isConnecting: isConnecting,
      isConnected: connectionStatus.valueOrNull == const Connected(),
    );
  }
}

class _MelaConnectionButton extends HookWidget {
  const _MelaConnectionButton({
    required this.onTap,
    required this.enabled,
    required this.label,
    required this.buttonColor,
    required this.isConnecting,
    required this.isConnected,
  });

  final VoidCallback onTap;
  final bool enabled;
  final String label;
  final Color buttonColor;
  final bool isConnecting;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final pulseCtrl = useAnimationController(
      duration: const Duration(milliseconds: 2000),
    );
    final rotCtrl = useAnimationController(
      duration: const Duration(seconds: 8),
    );

    useEffect(() {
      if (isConnecting) {
        pulseCtrl.repeat(reverse: true);
        rotCtrl.repeat();
      } else if (isConnected) {
        pulseCtrl.repeat(reverse: true);
        rotCtrl.stop();
      } else {
        pulseCtrl.stop();
        pulseCtrl.value = 0;
        rotCtrl.stop();
      }
      return null;
    }, [isConnecting, isConnected]);

    final pulse = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: pulseCtrl, curve: Curves.easeInOut),
    );
    final rotation = Tween<double>(begin: 0, end: 1).animate(rotCtrl);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: buttonColor),
            duration: const Duration(milliseconds: 600),
            builder: (context, animColor, _) {
              final color = animColor ?? buttonColor;
              return AnimatedBuilder(
                animation: Listenable.merge([pulse, rotation]),
                builder: (context, _) {
                  return _GlowButton(
                    color: color,
                    pulseValue: pulse.value,
                    rotationValue: rotation.value,
                    onTap: onTap,
                    enabled: enabled,
                    isConnecting: isConnecting,
                  );
                },
              );
            },
          ),
        ),
        const Gap(20),
        AnimatedText(
          label,
          style: TextStyle(
            color: MelaColors.textSec(context),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _GlowButton extends StatelessWidget {
  const _GlowButton({
    required this.color,
    required this.pulseValue,
    required this.rotationValue,
    required this.onTap,
    required this.enabled,
    required this.isConnecting,
  });

  final Color color;
  final double pulseValue;
  final double rotationValue;
  final VoidCallback onTap;
  final bool enabled;
  final bool isConnecting;

  @override
  Widget build(BuildContext context) {
    const outerSize = 156.0;
    const ring1Size = 128.0;
    const ring2Size = 102.0;
    const innerSize = 76.0;

    final glowColor = color.withValues(alpha: 0.35 * pulseValue);
    final ring1Color = color.withValues(alpha: 0.08);
    final ring2Color = color.withValues(alpha: 0.14);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: outerSize * (0.96 + 0.04 * pulseValue),
            height: outerSize * (0.96 + 0.04 * pulseValue),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: glowColor, blurRadius: 40, spreadRadius: 8),
                BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 80, spreadRadius: 20),
              ],
            ),
          ),
          // Rotating arc ring (only when connecting)
          if (isConnecting)
            SizedBox(
              width: outerSize,
              height: outerSize,
              child: Transform.rotate(
                angle: rotationValue * 2 * math.pi,
                child: CustomPaint(painter: _ArcPainter(color: color)),
              ),
            ),
          // Ring 1
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MelaColors.bgDarkColor(context),
              border: Border.all(
                color: color.withValues(alpha: 0.2 + 0.1 * pulseValue),
                width: 1.5,
              ),
            ),
          ),
          // Ring 2
          Container(
            width: ring1Size,
            height: ring1Size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ring1Color),
          ),
          // Ring 3
          Container(
            width: ring2Size,
            height: ring2Size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ring2Color),
          ),
          // Inner button
          Material(
            key: const ValueKey('home_connection_button'),
            shape: const CircleBorder(),
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              splashColor: color.withValues(alpha: 0.3),
              child: Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.95),
                      Color.lerp(color, Colors.black, 0.3)!,
                    ],
                    center: const Alignment(-0.3, -0.3),
                    radius: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2),
                  ],
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2 - 1);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.4, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}
