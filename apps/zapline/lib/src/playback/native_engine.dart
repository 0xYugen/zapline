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
  Future<void> open(
    Uri url, {
    Map<String, String> headers = const {},
    Duration start = Duration.zero,
  }) async {
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
    if (start > Duration.zero) await c.seekTo(start);
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

  VideoPlayerValue? get _value {
    final c = _controller.value;
    return c != null && c.value.isInitialized ? c.value : null;
  }

  @override
  Duration get currentPosition => _value?.position ?? Duration.zero;

  @override
  Duration get duration => _value?.duration ?? Duration.zero;

  @override
  bool get isPlaying => _value?.isPlaying ?? false;

  @override
  Future<void> play() async => _controller.value?.play();

  @override
  Future<void> pause() async => _controller.value?.pause();

  @override
  Future<void> seek(Duration to) async => _controller.value?.seekTo(to);

  @override
  Future<List<MediaTrack>> audioTracks() async {
    final c = _controller.value;
    if (c == null || !c.value.isInitialized) return const [];
    if (!c.isAudioTrackSupportAvailable()) return const [];
    return [
      for (final t in await c.getAudioTracks())
        MediaTrack(
          id: t.id,
          label: t.label,
          language: t.language,
          selected: t.isSelected,
        ),
    ];
  }

  @override
  Future<void> selectAudioTrack(String id) async =>
      _controller.value?.selectAudioTrack(id);

  // video_player shows only external caption files, not subtitles carried
  // in the stream.
  @override
  Future<List<MediaTrack>> subtitleTracks() async => const [];

  @override
  Future<void> selectSubtitleTrack(String? id) async {}

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) =>
      ValueListenableBuilder<VideoPlayerController?>(
        valueListenable: _controller,
        builder: (context, c, _) {
          if (c == null || !c.value.isInitialized) {
            return const SizedBox.expand();
          }
          if (fit == BoxFit.fill) return SizedBox.expand(child: VideoPlayer(c));
          // Sized by layout, not scaled with a transform: Android draws the
          // picture in a platform view, and transformed platform views leave
          // stale pixels in the widgets drawn over them.
          return LayoutBuilder(
            builder: (context, box) {
              final ratio = c.value.aspectRatio;
              var w = box.maxWidth, h = box.maxHeight;
              final wider = ratio > w / h;
              if (wider == (fit == BoxFit.contain)) {
                h = w / ratio;
              } else {
                w = h * ratio;
              }
              final view = OverflowBox(
                minWidth: w,
                maxWidth: w,
                minHeight: h,
                maxHeight: h,
                child: VideoPlayer(c),
              );
              // Only zoom spills over the edges; clip nothing otherwise.
              return fit == BoxFit.cover ? ClipRect(child: view) : view;
            },
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
