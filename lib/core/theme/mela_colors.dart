import 'package:flutter/material.dart';

abstract final class MelaColors {
  // ─── Dark palette — тёмно-серый (iOS-style) ───────────────────────────
  static const bgDeep      = Color(0xFF1C1C1E);
  static const bgDark      = Color(0xFF252528);
  static const bgCard      = Color(0xFF2C2C30);
  static const bgCardLight = Color(0xFF3A3A3E);
  static const bgSurface   = Color(0xFF48484C);

  // ─── Light palette — бело-серый (iOS-style) ───────────────────────────
  static const lightBg         = Color(0xFFF2F2F7);
  static const lightCard       = Color(0xFFFFFFFF);
  static const lightCardAlt    = Color(0xFFF7F7FA);
  static const lightSurface    = Color(0xFFEEEEF2);
  static const lightBorder     = Color(0xFFD1D1D6);
  static const lightBorderSoft = Color(0xFFE5E5EA);
  static const lightTextPrimary   = Color(0xFF1C1C1E);
  static const lightTextSecondary = Color(0xFF3C3C43);
  static const lightTextMuted     = Color(0xFF8E8E93);

  // ─── Primary purple ───────────────────────────────────────────────────
  static const primary      = Color(0xFF7B6CF6);
  static const primaryLight = Color(0xFF9D91FF);
  static const primaryGlow  = Color(0x557B6CF6);

  // ─── Secondary cyan ───────────────────────────────────────────────────
  static const secondary     = Color(0xFF22D3EE);
  static const secondaryGlow = Color(0x4422D3EE);

  // ─── States ───────────────────────────────────────────────────────────
  static const connected       = Color(0xFF10B981);
  static const connectedGlow   = Color(0x4410B981);
  static const disconnected    = Color(0xFF6366F1);
  static const disconnectedGlow= Color(0x446366F1);
  static const reconnect       = Color(0xFFF59E0B);

  // ─── Text — dark theme ────────────────────────────────────────────────
  static const textPrimary   = Color(0xFFEEEEEE);
  static const textSecondary = Color(0xFF9EAAB8);
  static const textMuted     = Color(0xFF8E8E93);

  // ─── Borders — dark theme ─────────────────────────────────────────────
  static const border      = Color(0xFF48484A);
  static const borderLight = Color(0xFF545458);

  // ─── Gradient endpoints ───────────────────────────────────────────────
  static const gradientStart = bgDeep;
  static const gradientMid   = bgDark;
  static const gradientEnd   = bgCard;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [bgDeep, bgDark, bgCard],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Adaptive helpers — используй везде вместо констант ──────────────
  static bool _d(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;

  static Color bg(BuildContext ctx)         => _d(ctx) ? bgDeep      : lightBg;
  static Color bgDarkColor(BuildContext ctx)=> _d(ctx) ? bgDark       : lightSurface;
  static Color card(BuildContext ctx)       => _d(ctx) ? bgCard       : lightCard;
  static Color cardAlt(BuildContext ctx)    => _d(ctx) ? bgCardLight  : lightCardAlt;
  static Color surf(BuildContext ctx)       => _d(ctx) ? bgSurface    : lightSurface;
  static Color brd(BuildContext ctx)        => _d(ctx) ? border       : lightBorder;
  static Color brdSoft(BuildContext ctx)    => _d(ctx) ? bgSurface    : lightBorderSoft;
  static Color textPrim(BuildContext ctx)   => _d(ctx) ? textPrimary  : lightTextPrimary;
  static Color textSec(BuildContext ctx)    => _d(ctx) ? textSecondary: lightTextSecondary;
  static Color textHint(BuildContext ctx)   => _d(ctx) ? textMuted    : lightTextMuted;

  static LinearGradient bgLinear(BuildContext ctx) => _d(ctx)
      ? const LinearGradient(
          colors: [bgDeep, bgDark, bgCard],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.5, 1.0],
        )
      : LinearGradient(
          colors: [lightBg, lightBg, lightCard],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.5, 1.0],
        );
}
