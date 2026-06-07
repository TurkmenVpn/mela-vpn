import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:melavpn/core/theme/app_theme_mode.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/core/theme/theme_extensions.dart';

class AppTheme {
  AppTheme(this.mode, this.fontFamily);
  final AppThemeMode mode;
  final String fontFamily;

  static final ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: MelaColors.primary,
    onPrimary: Colors.white,
    primaryContainer: MelaColors.bgSurface,
    onPrimaryContainer: MelaColors.primaryLight,
    secondary: MelaColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: MelaColors.bgCard,
    onSecondaryContainer: MelaColors.textSecondary,
    tertiary: MelaColors.connected,
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFF0F3024),
    onTertiaryContainer: MelaColors.connected,
    error: const Color(0xFFEF4444),
    onError: Colors.white,
    errorContainer: const Color(0xFF3D1A1A),
    onErrorContainer: const Color(0xFFFCA5A5),
    surface: MelaColors.bgCard,
    onSurface: MelaColors.textPrimary,
    surfaceContainerHighest: MelaColors.bgSurface,
    onSurfaceVariant: MelaColors.textSecondary,
    outline: MelaColors.border,
    outlineVariant: MelaColors.bgSurface,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Colors.white,
    onInverseSurface: MelaColors.bgDeep,
    inversePrimary: MelaColors.primary,
  );

  static final ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: const Color(0xFF5B52D6),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFEEECFF),
    onPrimaryContainer: const Color(0xFF3730A3),
    secondary: const Color(0xFF0891B2),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE0F5FA),
    onSecondaryContainer: const Color(0xFF065F7A),
    tertiary: const Color(0xFF059669),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFD1FAE5),
    onTertiaryContainer: const Color(0xFF065F46),
    error: const Color(0xFFDC2626),
    onError: Colors.white,
    errorContainer: const Color(0xFFFEE2E2),
    onErrorContainer: const Color(0xFF991B1B),
    surface: MelaColors.lightBg,
    onSurface: MelaColors.lightTextPrimary,
    surfaceContainerHighest: MelaColors.lightSurface,
    onSurfaceVariant: MelaColors.lightTextSecondary,
    outline: MelaColors.lightBorder,
    outlineVariant: MelaColors.lightBorderSoft,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: MelaColors.bgCard,
    onInverseSurface: Colors.white,
    inversePrimary: MelaColors.primaryLight,
  );

  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    final scheme = lightColorScheme ?? _lightScheme;
    return _buildTheme(scheme, Brightness.light, scaffoldBg: MelaColors.lightBg);
  }

  ThemeData darkTheme(ColorScheme? darkColorScheme) {
    final scheme = darkColorScheme ?? _darkScheme;
    final bg = mode.trueBlack ? const Color(0xFF111113) : MelaColors.bgDeep;
    return _buildTheme(scheme, Brightness.dark, scaffoldBg: bg);
  }

  ThemeData _buildTheme(ColorScheme scheme, Brightness brightness, {Color? scaffoldBg}) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scaffoldBg,
      splashColor: MelaColors.primaryGlow,
      highlightColor: MelaColors.primaryGlow.withValues(alpha: 0.3),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: brightness == Brightness.dark ? MelaColors.textPrimary : const Color(0xFF1A1D3A),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: brightness == Brightness.dark ? MelaColors.textPrimary : const Color(0xFF1A1D3A),
        ),
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.dark ? MelaColors.bgCard : MelaColors.lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: brightness == Brightness.dark ? MelaColors.border : MelaColors.lightBorder,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: brightness == Brightness.dark ? MelaColors.border : const Color(0xFFE8EAFF),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: MelaColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>{MelaButtonTheme.dark},
    );
  }

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.black => true,
    };
    final def = CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light);
    final defaultMaterialTheme = isDark ? darkTheme(darkColorScheme) : lightTheme(lightColorScheme);
    return MaterialBasedCupertinoThemeData(
      materialTheme: defaultMaterialTheme.copyWith(
        cupertinoOverrideTheme: def.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: def.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: def.textTheme.actionTextStyle.copyWith(fontFamily: fontFamily),
            navActionTextStyle: def.textTheme.navActionTextStyle.copyWith(fontFamily: fontFamily),
            navTitleTextStyle: def.textTheme.navTitleTextStyle.copyWith(fontFamily: fontFamily),
            navLargeTitleTextStyle: def.textTheme.navLargeTitleTextStyle.copyWith(fontFamily: fontFamily),
            pickerTextStyle: def.textTheme.pickerTextStyle.copyWith(fontFamily: fontFamily),
            dateTimePickerTextStyle: def.textTheme.dateTimePickerTextStyle.copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: def.textTheme.tabLabelTextStyle.copyWith(fontFamily: fontFamily),
          ),
          barBackgroundColor: def.barBackgroundColor,
          scaffoldBackgroundColor: def.scaffoldBackgroundColor,
        ),
      ),
    );
  }
}
