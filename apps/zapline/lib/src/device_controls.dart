import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The phone's media volume, the player window's brightness and
/// picture-in-picture, through MainActivity on Android. Elsewhere (desktop,
/// TV boxes without them, tests) the calls do nothing and getters give
/// `null`.
class DeviceControls {
  DeviceControls._();

  static const _channel = MethodChannel('zapline/device');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether the app is shrunk to a picture-in-picture window now.
  static final inPip = ValueNotifier<bool>(false);

  static bool _listening = false;

  static void _listen() {
    if (_listening || !_android) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pip') inPip.value = call.arguments == true;
    });
  }

  static Future<T?> _call<T>(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      debugPrint('$method: $e');
    } on MissingPluginException {
      // Not this platform after all (tests).
    }
    return null;
  }

  /// Media volume, 0–1.
  static Future<double?> volume() => _call<double>('volume');

  static Future<void> setVolume(double v) =>
      _call<void>('setVolume', {'value': v.clamp(0.0, 1.0)});

  /// The player window's brightness, 0–1: its own, or the system's while
  /// it has none.
  static Future<double?> brightness() => _call<double>('brightness');

  /// `null` follows the system's brightness again.
  static Future<void> setBrightness(double? v) =>
      _call<void>('setBrightness', {'value': v?.clamp(0.0, 1.0)});

  /// Leaving the app with a player open shrinks it to a small window,
  /// [width]:[height] in shape. Returns whether the device can.
  static Future<bool> enablePip({int width = 16, int height = 9}) async {
    _listen();
    return await _call<bool>('setPip', {
          'enabled': true,
          'width': width,
          'height': height,
        }) ??
        false;
  }

  static Future<void> disablePip() => _call<void>('setPip', {'enabled': false});
}
