import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:melavpn/core/theme/mela_colors.dart';

/// Базовый blur/glass диалог — вместо стандартного AlertDialog.
class MelaDialog extends StatelessWidget {
  const MelaDialog({
    super.key,
    this.title,
    this.icon,
    this.iconColor,
    required this.content,
    required this.actions,
    this.maxWidth = 360,
  });

  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = iconColor ?? MelaColors.primary;

    final bgColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.78);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.07);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Иконка
                  if (icon != null) ...[
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(icon, color: accentColor, size: 26),
                      ),
                    ),
                    const Gap(16),
                  ],
                  // Заголовок
                  if (title != null) ...[
                    Text(
                      title!,
                      style: TextStyle(
                        color: MelaColors.textPrim(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const Gap(10),
                  ],
                  // Контент
                  DefaultTextStyle(
                    style: TextStyle(
                      color: MelaColors.textSec(context),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    child: content,
                  ),
                  const Gap(22),
                  // Кнопки
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions
                        .map((a) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: a,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Вторичная кнопка (серый текст)
class MelaDialogTextButton extends StatelessWidget {
  const MelaDialogTextButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: MelaColors.textSec(context),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}

/// Основная кнопка (цветной акцент)
class MelaDialogFilledButton extends StatelessWidget {
  const MelaDialogFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.isDanger = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final btnColor = isDanger ? const Color(0xFFFF453A) : (color ?? MelaColors.primary);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: btnColor.withValues(alpha: 0.9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
