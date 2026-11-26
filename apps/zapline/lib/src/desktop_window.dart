import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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

  /// The window shrunk to a small picture in a corner, above other
  /// windows, while working in other apps.
  static final mini = ValueNotifier<bool>(false);

  /// Where the window was before [mini], to go back to.
  static Rect? _before;

  static const miniSize = Size(480, 270);

  static Future<void> setMini(bool on) async {
    if (!_ready || mini.value == on) return;
    try {
      if (on) {
        if (fullScreen.value) await setFullScreen(false);
        _before = await windowManager.getBounds();
        // Bottom right of the main screen, clear of a task bar.
        final display =
            WidgetsBinding.instance.platformDispatcher.displays.firstOrNull;
        final screen = display == null
            ? const Size(1280, 720)
            : display.size / display.devicePixelRatio;
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setBounds(
          null,
          position: Offset(
            screen.width - miniSize.width - 24,
            screen.height - miniSize.height - 72,
          ),
          size: miniSize,
        );
      } else {
        await windowManager.setAlwaysOnTop(false);
        if (_before case final b?) await windowManager.setBounds(b);
      }
      mini.value = on;
    } catch (e) {
      debugPrint('Mini player not available: $e');
    }
  }

  static Future<void> toggleMini() => setMini(!mini.value);

  static Future<void> exitMini() => setMini(false);

  /// Moves the window with the mouse, from a drag on the picture.
  static Future<void> startDragging() async {
    if (_ready) await windowManager.startDragging();
  }
}
