import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'playback_engine.dart';

/// libmpv via media_kit.
class MpvEngine implements PlaybackEngine {
  MpvEngine()
    : _player = Player(
        configuration: const PlayerConfiguration(
          // Live IPTV: keep the demuxer cache modest on low-RAM devices.
          bufferSize: 16 * 1024 * 1024,
        ),
      ) {
    _video = VideoController(_player);
  }

  final Player _player;
  late final VideoController _video;

  @override
  String get name => 'mpv';

  @override
  Future<void> open(
    Uri url, {
    Map<String, String> headers = const {},
    Duration start = Duration.zero,
  }) => _player.open(
    Media(
      url.toString(),
      httpHeaders: headers,
      start: start > Duration.zero ? start : null,
    ),
  );

  @override
  Duration get currentPosition => _player.state.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  bool get isPlaying => _player.state.playing;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration to) => _player.seek(to);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<String> get errors => _player.stream.error;

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) =>
      Video(controller: _video, controls: NoVideoControls, fit: fit);

  // mpv lists the pseudo tracks "auto" and "no" first.
  static bool _real(String id) => id != 'auto' && id != 'no';

  @override
  Future<List<MediaTrack>> audioTracks() async => [
    for (final t in _player.state.tracks.audio)
      if (_real(t.id))
        MediaTrack(
          id: t.id,
          label: t.title,
          language: t.language,
          selected: _player.state.track.audio.id == t.id,
        ),
  ];

  @override
  Future<void> selectAudioTrack(String id) async {
    final t = _player.state.tracks.audio.where((t) => t.id == id).firstOrNull;
    if (t != null) await _player.setAudioTrack(t);
  }

  @override
  Future<List<MediaTrack>> subtitleTracks() async => [
    for (final t in _player.state.tracks.subtitle)
      if (_real(t.id))
        MediaTrack(
          id: t.id,
          label: t.title,
          language: t.language,
          selected: _player.state.track.subtitle.id == t.id,
        ),
  ];

  @override
  Future<void> selectSubtitleTrack(String? id) async {
    if (id == null) return _player.setSubtitleTrack(SubtitleTrack.no());
    final t = _player.state.tracks.subtitle
        .where((t) => t.id == id)
        .firstOrNull;
    if (t != null) await _player.setSubtitleTrack(t);
  }
}
