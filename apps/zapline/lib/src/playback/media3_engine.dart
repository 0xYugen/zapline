import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../device_controls.dart';
import 'playback_engine.dart';

/// Zapline's own Android player (android/…/Media3Host.kt): one ExoPlayer
/// per player screen, reused from channel to channel, so a zap only
/// changes what it plays. Raw MPEG-TS starts on the first picture it can
/// show, playback starts after one second of buffer, and subtitles carried
/// in the stream are shown.
class Media3Engine with WidgetsBindingObserver implements PlaybackEngine {
  Media3Engine({this.background = false, this.matchFrameRate = false})
    : _id = _nextId++ {
    _ready = _method.invokeMethod<void>('create', {
      'id': _id,
      'background': background,
      'matchFrameRate': matchFrameRate,
    });
    _sub = _shared.listen(_onEvent, onError: (_) {});
    WidgetsBinding.instance.addObserver(this);
  }

  /// Keeps playing, as sound with a media notification, when the app is
  /// left (phones, when chosen in Settings). Otherwise leaving the app
  /// pauses, as the system player does: Home on a TV must not leave a
  /// channel playing behind the launcher.
  final bool background;

  /// The screen switches to the stream's frame rate while it plays (TVs,
  /// when chosen in Settings) and back when the player closes.
  final bool matchFrameRate;

  /// Paused because the app was left: plays again when it is back.
  bool _pausedByApp = false;

  /// A live stream let go when the app was left, to open again at live.
  (Uri, Map<String, String>)? _reopen;

  /// What was last opened, to open a live stream again.
  (Uri, Map<String, String>)? _last;

  /// Live, as the player says once ready; before that, live unless it
  /// has a length.
  bool? _isLive;
  bool get _live => _isLive ?? _duration <= Duration.zero;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        // Picture-in-picture shows the app shrunk, not left.
        if (DeviceControls.inPip.value || _closedOpens == _opens) return;
        // With background sound the media service keeps it going.
        if (background || _pausedByApp || _reopen != null) return;
        if (_live && _last != null) {
          // A live channel is let go: its decoders, connection and buffer
          // free (TV sticks have few), and it opens again at live.
          _reopen = _last;
          _call('stop');
        } else {
          _pausedByApp = true;
          _call('pause');
        }
      case AppLifecycleState.resumed:
        if (_reopen case (final url, final headers)) {
          _reopen = null;
          open(url, headers: headers);
        } else if (_pausedByApp) {
          _pausedByApp = false;
          _call('play');
        }
      case _:
        break;
    }
  }

  static const _method = MethodChannel('zapline/media3');
  static const _events = EventChannel('zapline/media3/events');

  /// One stream for every player: each listening to the channel on its own
  /// would cut the others off when it stops (a new player opened before
  /// the old one has closed).
  static final _shared = _events.receiveBroadcastStream();
  static int _nextId = 1;

  final int _id;
  late final Future<void> _ready;
  late final StreamSubscription<Object?> _sub;

  final _position = StreamController<Duration>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _buffering = StreamController<bool>.broadcast();

  Duration _current = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  /// Errors and positions of what was playing before the last open don't
  /// count: the native side keeps sending until it has switched.
  int _opens = 0;
  int _closedOpens = 0;

  @override
  String get name => 'media3+';

  Future<void> _call(String method, [Map<String, Object?> args = const {}]) =>
      _ready.then(
        (_) => _method.invokeMethod<void>(method, {'id': _id, ...args}),
      );

  void _onEvent(Object? e) {
    if (e is! Map || e['id'] != _id || _closedOpens == _opens) return;
    switch (e['event']) {
      case 'position':
        _current = Duration(milliseconds: (e['ms'] as num).toInt());
        if (!_position.isClosed) _position.add(_current);
      case 'duration':
        _duration = Duration(milliseconds: (e['ms'] as num).toInt());
        if (e['live'] case final bool live) _isLive = live;
      case 'playing':
        _playing = e['value'] == true;
      case 'picture':
        _hasPicture = true;
      case 'buffering':
        if (!_buffering.isClosed) _buffering.add(e['value'] == true);
      case 'error':
        if (!_errors.isClosed) _errors.add('${e['message']}');
      case 'ended':
        // A live stream doesn't end: the server closed it. As an error,
        // the player tries again; a film's end is its own.
        if (_live && !_errors.isClosed) _errors.add('Stream ended');
    }
  }

  /// A stop waits this long for the next channel: a zap then switches
  /// the paused player, whose decoders are still set up, instead of
  /// tearing it down and setting it up again.
  Timer? _stopLater;

  @override
  Future<void> open(
    Uri url, {
    Map<String, String> headers = const {},
    Duration start = Duration.zero,
  }) {
    _stopLater?.cancel();
    _opens++;
    _last = (url, headers);
    _reopen = null;
    _pausedByApp = false;
    _isLive = null;
    _hasPicture = false;
    _current = _duration = Duration.zero;
    return _call('open', {
      'url': url.toString(),
      'headers': headers,
      'startMs': start.inMilliseconds,
    });
  }

  @override
  Future<void> stop() {
    _closedOpens = _opens;
    _playing = false;
    _stopLater?.cancel();
    _stopLater = Timer(const Duration(seconds: 1), () => _call('stop'));
    return _call('pause');
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _stopLater?.cancel();
    await _sub.cancel();
    await _call('dispose');
    await _position.close();
    await _errors.close();
    await _buffering.close();
  }

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Duration get currentPosition => _current;

  @override
  Duration get duration => _duration;

  @override
  bool get isPlaying => _playing;

  bool _hasPicture = false;

  @override
  bool get hasPicture => _hasPicture;

  @override
  Future<void> play() => _call('play');

  @override
  Future<void> pause() => _call('pause');

  @override
  Future<void> seek(Duration to) => _call('seek', {'ms': to.inMilliseconds});

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Stream<bool> get buffering => _buffering.stream;

  @override
  Future<void> preload(int current, List<(int, Uri)> next) => _call('preload', {
    'current': current,
    'items': [
      for (final (index, url) in next) {'index': index, 'url': url.toString()},
    ],
  });

  @override
  Future<void> setVolume(double volume) =>
      _call('setVolume', {'value': volume.clamp(0.0, 1.0)});

  Future<List<MediaTrack>> _tracks(String type) async {
    await _ready;
    final list =
        await _method.invokeListMethod<Map<Object?, Object?>>('tracks', {
          'id': _id,
          'type': type,
        }) ??
        const [];
    return [
      for (final t in list)
        MediaTrack(
          id: '${t['id']}',
          label: t['label'] as String?,
          language: t['language'] as String?,
          selected: t['selected'] == true,
        ),
    ];
  }

  @override
  Future<List<MediaTrack>> audioTracks() => _tracks('audio');

  @override
  Future<void> selectAudioTrack(String id) =>
      _call('selectTrack', {'type': 'audio', 'track': id});

  @override
  Future<List<MediaTrack>> subtitleTracks() => _tracks('text');

  @override
  Future<void> selectSubtitleTrack(String? id) =>
      _call('selectTrack', {'type': 'text', 'track': id});

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) =>
      _Media3View(engine: this, fit: fit);
}

/// The player's picture: a native view the ExoPlayer draws into, kept for
/// the whole player screen.
class _Media3View extends StatefulWidget {
  const _Media3View({required this.engine, required this.fit});

  final Media3Engine engine;
  final BoxFit fit;

  @override
  State<_Media3View> createState() => _Media3ViewState();
}

class _Media3ViewState extends State<_Media3View> {
  @override
  void initState() {
    super.initState();
    _applyFit();
  }

  @override
  void didUpdateWidget(_Media3View old) {
    super.didUpdateWidget(old);
    if (old.fit != widget.fit) _applyFit();
  }

  void _applyFit() => widget.engine._call('setFit', {
    'fit': switch (widget.fit) {
      BoxFit.cover => 'cover',
      BoxFit.fill => 'fill',
      _ => 'contain',
    },
  });

  @override
  Widget build(BuildContext context) {
    const viewType = 'zapline/media3-view';
    final params = {'id': widget.engine._id};
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      onCreatePlatformView: (p) =>
          PlatformViewsService.initSurfaceAndroidView(
              id: p.id,
              viewType: viewType,
              layoutDirection:
                  Directionality.maybeOf(context) ?? TextDirection.ltr,
              creationParams: params,
              creationParamsCodec: const StandardMessageCodec(),
            )
            ..addOnPlatformViewCreatedListener(p.onPlatformViewCreated)
            ..create(),
    );
  }
}
