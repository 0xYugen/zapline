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

  /// Starts playing [url], replacing whatever was playing; films and
  /// episodes resume from [start].
  Future<void> open(
    Uri url, {
    Map<String, String> headers = const {},
    Duration start = Duration.zero,
  });

  Future<void> stop();

  Future<void> dispose();

  /// Playback position of the current stream; the first value above zero
  /// marks the end of a zap.
  Stream<Duration> get position;

  /// Where playback is now; zero before the stream starts.
  Duration get currentPosition;

  /// Length of the stream; zero for live channels or while unknown.
  Duration get duration;

  bool get isPlaying;

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration to);

  /// Human-readable playback errors.
  Stream<String> get errors;

  /// The video surface, scaled to the screen as [fit] says. Rebuilds
  /// itself when the stream changes.
  Widget buildView({BoxFit fit = BoxFit.contain});

  /// Audio tracks of the current stream (languages, audio description).
  Future<List<MediaTrack>> audioTracks();

  Future<void> selectAudioTrack(String id);

  /// Subtitle tracks carried in the stream; empty where the engine can't
  /// show them.
  Future<List<MediaTrack>> subtitleTracks();

  /// `null` turns subtitles off.
  Future<void> selectSubtitleTrack(String? id);
}

/// An audio or subtitle track as the player shows it.
class MediaTrack {
  const MediaTrack({
    required this.id,
    required this.selected,
    this.label,
    this.language,
  });

  final String id;
  final bool selected;
  final String? label;

  /// ISO 639 code as the stream reports it ("ita", "eng"), if any.
  final String? language;
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
