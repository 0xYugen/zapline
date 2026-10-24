import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'playback_engine.dart';

/// The platform's own player through the official `video_player` plugin:
/// Media3/ExoPlayer on Android (hardware decoding on TV boxes), the HTML
/// video element on web.
class NativeEngine implements PlaybackEngine {
  final _controller = ValueNotifier<VideoPlayerController?>(null);
  final _position = StreamController<Duration>.broadcast();
  final _errors = StreamController<String>.broadcast();

  /// Bumped on every open so a slow, superseded initialisation is discarded.
  int _generation = 0;
  String? _lastError;

  @override
  String get name => kIsWeb ? 'html5' : 'media3';

  @override
  Future<void> open(Uri url, {Map<String, String> headers = const {}}) async {
    final gen = ++_generation;
    _lastError = null;
    await _release();
    final c = VideoPlayerController.networkUrl(
      url,
      httpHeaders: headers,
      formatHint: url.path.toLowerCase().endsWith('.m3u8')
          ? VideoFormat.hls
          : null,
      // A platform view (SurfaceView on Android) avoids an extra GPU copy
      // per frame, which matters on low-end TV sticks.
      viewType: VideoViewType.platformView,
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: false),
    );
    try {
      await c.initialize();
    } catch (e) {
      await c.dispose();
      if (gen == _generation) _errors.add(_describe(e));
      return;
    }
    if (gen != _generation) {
      await c.dispose();
      return;
    }
    c.addListener(() => _onValue(c));
    _controller.value = c;
    await c.play();
  }

  void _onValue(VideoPlayerController c) {
    final v = c.value;
    if (v.hasError) {
      final msg = _clean(v.errorDescription ?? 'Playback error');
      if (msg != _lastError) _errors.add(_lastError = msg);
    } else if (v.isPlaying) {
      _position.add(v.position);
    }
  }

  Future<void> _release() async {
    final old = _controller.value;
    _controller.value = null;
    await old?.dispose();
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _release();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _position.close();
    await _errors.close();
    _controller.dispose();
  }

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Widget buildView() => ValueListenableBuilder<VideoPlayerController?>(
    valueListenable: _controller,
    builder: (context, c, _) {
      if (c == null || !c.value.isInitialized) return const SizedBox.expand();
      return Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      );
    },
  );

  /// Turns `PlatformException(VideoError, Video player had error fk: Source
  /// error, ...)` into `Source error`. The class name before the colon is
  /// obfuscated in release builds and means nothing to users.
  static String _describe(Object e) {
    final s = e.toString();
    final m = RegExp(r'VideoError, (?:Video player had error [^:]*: )?([^,]+)')
        .firstMatch(s);
    return m?.group(1)?.trim() ?? s;
  }

  static String _clean(String s) =>
      s.replaceFirst(RegExp(r'^Video player had error [^:]*: '), '');
}
