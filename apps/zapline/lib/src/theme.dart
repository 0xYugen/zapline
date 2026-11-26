import 'package:flutter/material.dart';

/// Palette tuned for 10-foot viewing, in the manner of Google TV: a
/// neutral dark ground, quiet surfaces, the focused item lit up light (it
/// grows a little and casts a shadow) and one soft blue for accents.
abstract final class ZaplineColors {
  static const ground = Color(0xFF0F1115);
  static const rail = Color(0xFF0F1115);
  static const surface = Color(0xFF181B21);
  static const surfaceHigh = Color(0xFF22262E);
  static const line = Color(0xFF33373F);
  static const text = Color(0xFFE8EAED);
  static const textMuted = Color(0xFF9AA0A6);

  /// The focused item's fill, and its text.
  static const focus = Color(0xFFE8EAED);
  static const focusBorder = Color(0xFFFFFFFF);
  static const onFocus = Color(0xFF202124);

  /// Accents: what is selected, links, progress, the "now" line.
  static const accent = Color(0xFF8AB4F8);

  /// [accent] where the ground is light (a focused item).
  static const accentOnLight = Color(0xFF1A62D6);
  static const live = Color(0xFFF28B82);
  static const ok = Color(0xFF81C995);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Figtree',
    fontFamilyFallback: const ['Inter'],
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ZaplineColors.ground,
    colorScheme: const ColorScheme.dark(
      primary: ZaplineColors.accent,
      onPrimary: Color(0xFF062E6F),
      surface: ZaplineColors.surface,
      onSurface: ZaplineColors.text,
      error: ZaplineColors.live,
    ),
  );
  return base.copyWith(
    // A short fade and rise everywhere: Android's default transition draws
    // the old and new pages into extra layers, heavy for a TV stick's GPU,
    // above all over a playing video.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values)
          p: const FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    textTheme: base.textTheme.apply(
      bodyColor: ZaplineColors.text,
      displayColor: ZaplineColors.text,
    ),
    appBarTheme: AppBarTheme(
      titleTextStyle: base.textTheme.titleLarge!.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ZaplineColors.text,
      ),
      backgroundColor: ZaplineColors.ground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ZaplineColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ZaplineColors.rail,
      surfaceTintColor: Colors.transparent,
      indicatorColor: ZaplineColors.accent,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF062E6F)
              : ZaplineColors.textMuted,
        ),
      ),
      // Small enough for five tabs and "Impostazioni" on one line.
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          letterSpacing: -0.1,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? ZaplineColors.text
              : ZaplineColors.textMuted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: ZaplineColors.rail,
      indicatorColor: ZaplineColors.focus,
      selectedIconTheme: const IconThemeData(color: ZaplineColors.onFocus),
      unselectedIconTheme: const IconThemeData(color: ZaplineColors.textMuted),
      selectedLabelTextStyle: base.textTheme.labelMedium!.copyWith(
        fontWeight: FontWeight.w500,
        color: ZaplineColors.text,
      ),
      unselectedLabelTextStyle: base.textTheme.labelMedium!.copyWith(
        fontWeight: FontWeight.w500,
        color: ZaplineColors.textMuted,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ZaplineColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: ZaplineColors.line,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: ZaplineColors.textMuted,
      textColor: ZaplineColors.text,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
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
        borderSide: const BorderSide(color: ZaplineColors.accent, width: 3),
      ),
    ),
  );
}

/// A light ring around buttons a remote or keyboard is on.
final focusRing = WidgetStateProperty.resolveWith<BorderSide?>(
  (states) => states.contains(WidgetState.focused)
      ? const BorderSide(color: ZaplineColors.focusBorder, width: 3)
      : null,
);
