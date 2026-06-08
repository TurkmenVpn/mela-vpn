import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:melavpn/core/theme/app_theme_mode.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/core/theme/theme_preferences.dart';
import 'package:melavpn/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:toastification/toastification.dart';

part 'in_app_notification_controller.g.dart';

@Riverpod(keepAlive: true)
InAppNotificationController inAppNotificationController(Ref ref) {
  return InAppNotificationController(ref);
}

enum NotificationType { info, error, success }

class InAppNotificationController with AppLogger {
  InAppNotificationController(this._ref);

  final Ref _ref;

  bool get _isDark {
    final mode = _ref.read(themePreferencesProvider);
    if (mode == AppThemeMode.light) return false;
    if (mode == AppThemeMode.dark || mode == AppThemeMode.black) return true;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  ToastificationItem _show(
    String message, {
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    toastification.dismissAll();

    final isDark = _isDark;

    final (accentColor, iconData) = switch (type) {
      NotificationType.success => (MelaColors.connected, Icons.check_rounded),
      NotificationType.error   => (const Color(0xFFFF5A5A), Icons.error_rounded),
      NotificationType.info    => (MelaColors.primary, Icons.info_rounded),
    };

    final bgColor   = isDark ? const Color(0xFF1E1E21) : Colors.white;
    final textColor = isDark ? const Color(0xFFEEEEEE) : const Color(0xFF1C1C1E);

    final borderColor = isDark
        ? accentColor.withValues(alpha: 0.22)
        : accentColor.withValues(alpha: 0.18);

    // ── Icon / sticker ─────────────────────────────────────────────────────
    Widget iconWidget;
    if (type == NotificationType.success) {
      // iOS-style green checkmark sticker
      iconWidget = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              MelaColors.connected,
              Color.lerp(MelaColors.connected, const Color(0xFF059669), 0.6)!,
            ],
            center: const Alignment(-0.3, -0.3),
            radius: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: MelaColors.connected.withValues(alpha: isDark ? 0.45 : 0.30),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
      );
    } else {
      iconWidget = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accentColor.withValues(alpha: isDark ? 0.16 : 0.10),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.30 : 0.20),
          ),
        ),
        child: Icon(iconData, color: accentColor, size: 20),
      );
    }

    final List<BoxShadow> shadows = isDark
        ? [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ]
        : [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ];

    return toastification.show(
      title: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
          letterSpacing: -0.1,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      icon: iconWidget,
      type: type._toastificationType,
      // ── Bottom center — between AppBar (+) and the profile card ──────────
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      margin: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
      autoCloseDuration: duration,
      style: ToastificationStyle.flat,
      backgroundColor: bgColor,
      foregroundColor: textColor,
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide(color: borderColor),
      boxShadow: shadows,
      pauseOnHover: true,
      showProgressBar: false,
      dragToClose: true,
      closeOnClick: true,
      closeButtonShowType: CloseButtonShowType.none,
      animationDuration: const Duration(milliseconds: 420),
      animationBuilder: (context, animation, alignment, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  ToastificationItem? showErrorToast(String message) =>
      _show(message, type: NotificationType.error, duration: const Duration(seconds: 5));

  ToastificationItem? showSuccessToast(String message) =>
      _show(message, type: NotificationType.success);

  ToastificationItem? showInfoToast(String message, {Duration duration = const Duration(seconds: 3)}) =>
      _show(message, duration: duration);
}

extension NotificationTypeX on NotificationType {
  ToastificationType get _toastificationType => switch (this) {
    NotificationType.success => ToastificationType.success,
    NotificationType.error   => ToastificationType.error,
    NotificationType.info    => ToastificationType.info,
  };
}
