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
    Duration duration = const Duration(seconds: 4),
  }) {
    toastification.dismissAll();

    final isDark = _isDark;

    final (accentColor, iconData) = switch (type) {
      NotificationType.success => (MelaColors.connected,       Icons.check_rounded),
      NotificationType.error   => (const Color(0xFFFF453A),    Icons.close_rounded),
      NotificationType.info    => (MelaColors.primary,         Icons.info_rounded),
    };

    // Матовое стекло: полупрозрачный фон + applyBlurEffect
    final bgColor = isDark
        ? const Color(0xFF2C2C2E).withValues(alpha: 0.80)
        : Colors.white.withValues(alpha: 0.72);

    final textColor = isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);

    // ── Carbon-style: левая полоса + иконка + текст ────────────────────────
    final content = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Левая акцентная полоска
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Иконка в кружке
          Center(
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: isDark ? 0.18 : 0.14),
              ),
              child: Icon(iconData, color: accentColor, size: 14),
            ),
          ),
          const SizedBox(width: 10),
          // Текст
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  letterSpacing: -0.1,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );

    return toastification.show(
      title: content,
      icon: const SizedBox.shrink(),
      type: type._toastificationType,
      // Верх экрана — поверх настроек и всего остального
      alignment: Alignment.topCenter,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(top: 8, left: 14, right: 14),
      autoCloseDuration: duration,
      style: ToastificationStyle.flat,
      backgroundColor: bgColor,
      foregroundColor: accentColor,
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: accentColor.withValues(alpha: isDark ? 0.22 : 0.18),
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ]
          : [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
      // Прогресс-линия снизу — показывает время до закрытия
      applyBlurEffect: true,
      showProgressBar: true,
      progressBarTheme: ProgressIndicatorThemeData(
        color: accentColor.withValues(alpha: 0.60),
        linearTrackColor: accentColor.withValues(alpha: 0.10),
        linearMinHeight: 2,
      ),
      pauseOnHover: true,
      dragToClose: true,
      closeOnClick: false,
      closeButtonShowType: CloseButtonShowType.always,
      animationDuration: const Duration(milliseconds: 340),
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
    Duration duration = const Duration(seconds: 4),
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
