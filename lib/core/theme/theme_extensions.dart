import 'package:flutter/material.dart';
import 'package:melavpn/core/theme/mela_colors.dart';

class ConnectionButtonTheme extends ThemeExtension<ConnectionButtonTheme> {
  const ConnectionButtonTheme({this.idleColor, this.connectedColor});

  final Color? idleColor;
  final Color? connectedColor;

  static const ConnectionButtonTheme light = ConnectionButtonTheme(
    idleColor: MelaColors.disconnected,
    connectedColor: MelaColors.connected,
  );

  @override
  ThemeExtension<ConnectionButtonTheme> copyWith({Color? idleColor, Color? connectedColor}) =>
      ConnectionButtonTheme(
        idleColor: idleColor ?? this.idleColor,
        connectedColor: connectedColor ?? this.connectedColor,
      );

  @override
  ThemeExtension<ConnectionButtonTheme> lerp(covariant ThemeExtension<ConnectionButtonTheme>? other, double t) {
    if (other is! ConnectionButtonTheme) return this;
    return ConnectionButtonTheme(
      idleColor: Color.lerp(idleColor, other.idleColor, t),
      connectedColor: Color.lerp(connectedColor, other.connectedColor, t),
    );
  }
}

class MelaButtonTheme extends ThemeExtension<MelaButtonTheme> {
  const MelaButtonTheme({this.idleColor, this.connectedColor, this.glowColor});

  final Color? idleColor;
  final Color? connectedColor;
  final Color? glowColor;

  static const MelaButtonTheme dark = MelaButtonTheme(
    idleColor: MelaColors.disconnected,
    connectedColor: MelaColors.connected,
    glowColor: MelaColors.primaryGlow,
  );

  @override
  ThemeExtension<MelaButtonTheme> copyWith({Color? idleColor, Color? connectedColor, Color? glowColor}) =>
      MelaButtonTheme(
        idleColor: idleColor ?? this.idleColor,
        connectedColor: connectedColor ?? this.connectedColor,
        glowColor: glowColor ?? this.glowColor,
      );

  @override
  ThemeExtension<MelaButtonTheme> lerp(covariant ThemeExtension<MelaButtonTheme>? other, double t) {
    if (other is! MelaButtonTheme) return this;
    return MelaButtonTheme(
      idleColor: Color.lerp(idleColor, other.idleColor, t),
      connectedColor: Color.lerp(connectedColor, other.connectedColor, t),
      glowColor: Color.lerp(glowColor, other.glowColor, t),
    );
  }
}
