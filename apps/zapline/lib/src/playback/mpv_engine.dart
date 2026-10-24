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
  Future<void> open(Uri url, {Map<String, String> headers = const {}}) =>
      _player.open(Media(url.toString(), httpHeaders: headers));

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
}
