import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// The app's window on Windows, macOS and Linux: full screen for the
/// players. Elsewhere (Android, iOS, web, tests) every call does nothing.
class DesktopWindow {
  DesktopWindow._();

  /// Whether this is a desktop build with a window to manage.
  static final bool supported =
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static bool _ready = false;

  /// Call once at startup, before [runApp].
  static Future<void> init() async {
    if (!supported) return;
    try {
      await windowManager.ensureInitialized();
      _ready = true;
    } catch (e) {
      debugPrint('Window manager unavailable: $e');
    }
  }

  /// Full screen now; changes as [toggleFullScreen] and [exitFullScreen]
  /// are called.
  static final fullScreen = ValueNotifier<bool>(false);

  static Future<void> setFullScreen(bool on) async {
    if (!_ready || fullScreen.value == on) return;
    fullScreen.value = on;
    try {
      await windowManager.setFullScreen(on);
    } catch (e) {
      fullScreen.value = !on;
      debugPrint('Full screen not available: $e');
    }
  }

  static Future<void> toggleFullScreen() => setFullScreen(!fullScreen.value);

  static Future<void> exitFullScreen() => setFullScreen(false);
}
