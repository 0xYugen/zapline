import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen from sleeping while Zapline is open (TV boxes, phones
/// and PCs alike), as the user asked; the system clears it when the app
/// goes to the background.
Future<void> keepScreenAwake(bool on) async {
  try {
    await WakelockPlus.toggle(enable: on);
  } catch (e) {
    // No plugin in tests, or a platform without it: nothing to keep.
    debugPrint('wakelock unavailable');
  }
}
