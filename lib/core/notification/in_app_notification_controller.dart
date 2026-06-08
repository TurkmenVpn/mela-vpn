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

    final isDark  = _isDark;
    final isLong  = message.length > 32;

    final (accentColor, iconData) = switch (type) {
      NotificationType.success => (MelaColors.connected, Icons.check_rounded),
      NotificationType.error   => (const Color(0xFFFF453A), Icons.close_rounded),
      NotificationType.info    => (MelaColors.primary,     Icons.info_rounded),
    };

    final bgColor   = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    final shadows = isDark
        ? <BoxShadow>[
            BoxShadow(
              color: accentColor.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ];

    // ── Режим: короткий (пилл сверху) / длинный (карточка по центру) ────────
    if (isLong) {
      // Центр экрана — иконка + текст, полноценная карточка
      return toastification.show(
        title: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        icon: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
          ),
          child: Icon(iconData, color: accentColor, size: 17),
        ),
        type: type._toastificationType,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 32),
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
        closeButtonShowType: CloseButtonShowType.always,
        animationDuration: const Duration(milliseconds: 350),
        animationBuilder: (context, animation, alignment, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
          return ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            ),
          );
        },
      );
    }

    // Короткий — пилл 10px высотой у верхнего края
    return toastification.show(
      title: SizedBox(
        height: 10,
        child: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.w500,
            height: 1.0,
            letterSpacing: -0.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      icon: const SizedBox.shrink(),
      type: type._toastificationType,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      margin: const EdgeInsets.symmetric(horizontal: 60),
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
      closeButtonShowType: CloseButtonShowType.always,
      animationDuration: const Duration(milliseconds: 320),
      animationBuilder: (context, animation, alignment, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
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

  ToastificationItem? showInfoToast(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      _show(message, duration: duration);
}

extension NotificationTypeX on NotificationType {
  ToastificationType get _toastificationType => switch (this) {
    NotificationType.success => ToastificationType.success,
    NotificationType.error   => ToastificationType.error,
    NotificationType.info    => ToastificationType.info,
  };
}
