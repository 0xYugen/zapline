import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'mpv_engine.dart';
import 'native_engine.dart';

/// A video backend. The player screen talks only to this interface so each
/// platform can use the engine that works best there:
///
/// * Android, Android TV, Fire OS and web: [NativeEngine] (Media3/ExoPlayer
///   on Android, the browser's video element on web).
/// * Windows, macOS, Linux and iOS: [MpvEngine] (libmpv), which also plays
///   raw MPEG-TS that AVPlayer cannot.
abstract class PlaybackEngine {
  /// Short engine name shown in diagnostics.
  String get name;

  /// Starts playing [url], replacing whatever was playing.
  Future<void> open(Uri url, {Map<String, String> headers = const {}});

  Future<void> stop();

  Future<void> dispose();

  /// Playback position of the current stream; the first value above zero
  /// marks the end of a zap.
  Stream<Duration> get position;

  /// Human-readable playback errors.
  Stream<String> get errors;

  /// The video surface, scaled to the screen as [fit] says. Rebuilds
  /// itself when the stream changes.
  Widget buildView({BoxFit fit = BoxFit.contain});
}

/// Tests and screenshots substitute a fake engine here.
PlaybackEngine Function()? debugEngineFactory;

PlaybackEngine createDefaultEngine() {
  if (debugEngineFactory case final make?) return make();
  if (kIsWeb) return NativeEngine();
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => NativeEngine(),
    _ => MpvEngine(),
  };
}
