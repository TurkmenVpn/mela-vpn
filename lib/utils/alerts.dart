import 'package:flutter/material.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:toastification/toastification.dart';

enum AlertType {
  info,
  error,
  success;

  ToastificationType get _toastificationType => switch (this) {
    success => ToastificationType.success,
    error => ToastificationType.error,
    info => ToastificationType.info,
  };

  (Color bg, Color fg, IconData icon) get _colors => switch (this) {
    success => (const Color(0xFF1E3A2F), const Color(0xFF4ADE80), Icons.check_circle_rounded),
    error => (const Color(0xFF3A1E1E), const Color(0xFFF87171), Icons.error_rounded),
    info => (MelaColors.bgCard, MelaColors.textPrimary, Icons.info_rounded),
  };
}

class CustomToast {
  const CustomToast(this.message, {this.type = AlertType.info, this.duration = const Duration(seconds: 3)});

  const CustomToast.error(this.message, {this.duration = const Duration(seconds: 5)}) : type = AlertType.error;

  const CustomToast.success(this.message, {this.duration = const Duration(seconds: 3)}) : type = AlertType.success;

  final String message;
  final AlertType type;
  final Duration duration;

  void show(BuildContext context) {
    final (bgColor, fgColor, icon) = type._colors;

    toastification.dismissAll();
    toastification.show(
      context: context,
      title: Text(
        message,
        style: TextStyle(
          color: fgColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
      icon: Icon(icon, color: fgColor, size: 20),
      type: type._toastificationType,
      alignment: Alignment.topCenter,
      margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
      autoCloseDuration: duration,
      style: ToastificationStyle.flat,
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
      pauseOnHover: true,
      showProgressBar: false,
      dragToClose: true,
      closeOnClick: true,
      closeButtonShowType: CloseButtonShowType.none,
      animationDuration: const Duration(milliseconds: 300),
      animationBuilder: (context, animation, alignment, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}
