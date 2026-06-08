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

    // ── Compact icon — тонкий стиль ────────────────────────────────────────
    Widget iconWidget;
    if (type == NotificationType.success) {
      iconWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MelaColors.connected,
          boxShadow: [
            BoxShadow(
              color: MelaColors.connected.withValues(alpha: 0.40),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
      );
    } else {
      iconWidget = Icon(iconData, color: accentColor, size: 15);
    }

    final List<BoxShadow> shadows = isDark
        ? [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ]
        : [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ];

    return toastification.show(
      title: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          height: 1.3,
          letterSpacing: -0.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      icon: iconWidget,
      type: type._toastificationType,
      // ── Top center — тонкая полоска между + и настройками в AppBar ───────
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      margin: const EdgeInsets.only(top: 50, left: 58, right: 58),
      autoCloseDuration: duration,
      style: ToastificationStyle.flat,
      backgroundColor: bgColor,
      foregroundColor: textColor,
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: borderColor),
      boxShadow: shadows,
      pauseOnHover: true,
      showProgressBar: false,
      dragToClose: true,
      closeOnClick: true,
      closeButtonShowType: CloseButtonShowType.none,
      animationDuration: const Duration(milliseconds: 380),
      animationBuilder: (context, animation, alignment, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1.5),
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
