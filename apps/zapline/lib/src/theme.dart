import 'package:flutter/material.dart';

/// Palette tuned for 10-foot viewing: dark ground, one high-contrast focus
/// colour that stays visible from the sofa.
abstract final class ZaplineColors {
  static const ground = Color(0xFF0B0E13);
  static const rail = Color(0xFF10141B);
  static const surface = Color(0xFF141922);
  static const surfaceHigh = Color(0xFF1C2330);
  static const line = Color(0xFF2A3342);
  static const text = Color(0xFFEEF2F7);
  static const textMuted = Color(0xFF9AA6B8);
  static const focus = Color(0xFFF5B841);
  static const focusBorder = Color(0xFFFFE3A3);
  static const onFocus = Color(0xFF1A1204);
  static const live = Color(0xFFFF8A7A);
  static const ok = Color(0xFF7FD6A4);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ZaplineColors.ground,
    colorScheme: const ColorScheme.dark(
      primary: ZaplineColors.focus,
      onPrimary: ZaplineColors.onFocus,
      surface: ZaplineColors.surface,
      onSurface: ZaplineColors.text,
      error: ZaplineColors.live,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: ZaplineColors.text,
      displayColor: ZaplineColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ZaplineColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ZaplineColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ZaplineColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ZaplineColors.focus, width: 3),
      ),
    ),
  );
}
