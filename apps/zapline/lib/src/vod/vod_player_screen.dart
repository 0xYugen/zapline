import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../layout.dart';
import '../playback/playback_engine.dart';
import '../theme.dart';
import '../cast/cast_ui.dart';
import '../widgets/tracks_sheet.dart';

/// Something the VOD player can play: a film or an episode.
class VodPlayable {
  const VodPlayable({
    required this.key,
    required this.title,
    required this.url,
    this.subtitle,
    this.start = Duration.zero,
  });

  /// Where its position is saved (see [VodCatalog.movieKey]).
  final String key;
  final String title;
  final String? subtitle;
  final Uri? url;
  final Duration start;
}

/// Plays films and episodes: seek bar, pause, ±10 s, audio and subtitles,
/// and the next episode when one ends. Remembers where playback stopped.
class VodPlayerScreen extends StatefulWidget {
  const VodPlayerScreen({
    super.key,
    required this.state,
    required this.items,
    this.initialIndex = 0,
  });

  final AppState state;

  /// The film, or the episodes from the chosen one to the season's end.
  final List<VodPlayable> items;
  final int initialIndex;

  @override
  State<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends State<VodPlayerScreen> {
  final PlaybackEngine _engine = createDefaultEngine();
  late int _index = widget.initialIndex;
  final _focus = FocusNode(debugLabel: 'vod player');

  Timer? _tick;
  Timer? _hideTimer;
  StreamSubscription<String>? _errors;
  StreamSubscription<String>? _keys;
  String? _error;
  bool _overlay = true;
  BoxFit _fit = BoxFit.contain;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  /// While the seek bar is dragged, where it is.
  double? _dragging;
  DateTime _lastSave = DateTime.now();
  bool _ended = false;

  VodPlayable get _item => widget.items[_index];
  bool get _hasNext => _index + 1 < widget.items.length;

  @override
  void initState() {
    super.initState();
    _errors = _engine.errors.listen((e) {
      if (mounted) setState(() => _error = e);
    });
    _keys = widget.state.remoteKeys.stream.listen((k) {
      if (k == 'toggle') _togglePlay();
    });
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) => _poll());
    _open(_item.start);
  }

  bool _phoneChrome = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_phoneChrome && context.isPhone) {
      _phoneChrome = true;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    _save();
    // After this frame: listeners can't rebuild while the tree is torn down.
    Future.microtask(widget.state.positionsChanged);
    if (_phoneChrome) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(const []);
    }
    _tick?.cancel();
    _hideTimer?.cancel();
    _errors?.cancel();
    _keys?.cancel();
    widget.state.nowPlaying = null;
    _engine.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _open(Duration start) async {
    final url = _item.url;
    setState(() {
      _error = url == null ? context.l10n.videoUnavailable : null;
      _position = start;
      _duration = Duration.zero;
      _ended = false;
    });
    _showOverlay();
    widget.state.nowPlaying = (title: _item.title, subtitle: _item.subtitle);
    if (url != null) await _engine.open(url, start: start);
  }

  Future<void> _sendToTv() async {
    final request = castRequestFor(
      widget.state,
      vodKey: _item.key,
      position: _engine.currentPosition,
    );
    if (request == null) return;
    await sendToTv(
      context,
      widget.state,
      request: request,
      title: _item.title,
      stopHere: () => Navigator.of(context).pop(),
    );
  }

  void _poll() {
    if (!mounted) return;
    final pos = _engine.currentPosition;
    final dur = _engine.duration;
    final playing = _engine.isPlaying;
    final ended =
        dur > Duration.zero &&
        !playing &&
        pos >= dur - const Duration(milliseconds: 1500);
    if (pos != _position || dur != _duration || playing != _playing) {
      setState(() {
        _position = pos;
        _duration = dur;
        _playing = playing;
      });
    }
    if (DateTime.now().difference(_lastSave) > const Duration(seconds: 10)) {
      _save();
    }
    if (ended && !_ended) {
      _ended = true;
      _save();
      if (_hasNext) {
        _next();
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  void _save() {
    _lastSave = DateTime.now();
    if (_duration > Duration.zero) {
      widget.state.savePosition(_item.key, _position, _duration);
    }
  }

  void _next() {
    _save();
    setState(() => _index++);
    _open(Duration.zero);
  }

  void _showOverlay() {
    setState(() => _overlay = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _playing && _dragging == null) {
        setState(() => _overlay = false);
      }
    });
  }

  Future<void> _togglePlay() async {
    _playing ? await _engine.pause() : await _engine.play();
    _poll();
    _showOverlay();
  }

  Future<void> _seekBy(Duration d) async {
    var to = _engine.currentPosition + d;
    if (to < Duration.zero) to = Duration.zero;
    if (_duration > Duration.zero && to > _duration) to = _duration;
    setState(() => _position = to);
    await _engine.seek(to);
    _showOverlay();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.mediaRewind) {
      _seekBy(const Duration(seconds: -10));
    } else if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.mediaFastForward) {
      _seekBy(const Duration(seconds: 10));
    } else if (e is KeyDownEvent &&
        (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.space ||
            k == LogicalKeyboardKey.mediaPlayPause)) {
      _overlay ? _togglePlay() : _showOverlay();
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown) {
      _showOverlay();
      return KeyEventResult.ignored;
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final remaining = _duration - _position;
    final offerNext =
        _hasNext &&
        _duration > Duration.zero &&
        remaining < const Duration(seconds: 30);
    // Saved as the page starts closing, so the page below already shows
    // where to resume from.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                _overlay ? setState(() => _overlay = false) : _showOverlay(),
            onDoubleTapDown: (d) {
              final w = MediaQuery.sizeOf(context).width;
              _seekBy(Duration(seconds: d.localPosition.dx < w / 2 ? -10 : 10));
            },
            onDoubleTap: () {},
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The native video view would swallow taps otherwise.
                IgnorePointer(child: _engine.buildView(fit: _fit)),
                if (_error != null) _errorView(_error!),
                if (_duration == Duration.zero && _error == null)
                  const Center(
                    child: CircularProgressIndicator(
                      color: ZaplineColors.focus,
                    ),
                  ),
                AnimatedOpacity(
                  opacity: _overlay ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_overlay,
                    child: _controls(l),
                  ),
                ),
                if (offerNext)
                  Positioned(
                    right: 24,
                    bottom: _overlay ? 104 : 32,
                    child: FilledButton.icon(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: ZaplineColors.text,
                        foregroundColor: ZaplineColors.ground,
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      icon: const Icon(Icons.skip_next_rounded),
                      label: Text(l.nextEpisodeIn(remaining.inSeconds)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: ZaplineColors.live,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );

  Widget _controls(AppLocalizations l) {
    final total = _duration.inMilliseconds.toDouble();
    final value =
        _dragging ??
        (total <= 0 ? 0.0 : _position.inMilliseconds.clamp(0, total) / total);
    final shown = _dragging == null
        ? _position
        : Duration(milliseconds: (_dragging! * total).round());
    Widget round(IconData icon, String tip, VoidCallback onTap, double size) =>
        IconButton(
          tooltip: tip,
          iconSize: size,
          color: Colors.white,
          onPressed: onTap,
          icon: Icon(icon),
        );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.25, 0.65, 1],
          colors: [
            Color(0xB3000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0xCC000000),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  round(
                    Icons.arrow_back_rounded,
                    l.back,
                    () => Navigator.of(context).maybePop(),
                    26,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_item.subtitle case final s?)
                          Text(
                            s,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: ZaplineColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  round(Icons.cast_rounded, l.castButton, _sendToTv, 24),
                  round(
                    Icons.subtitles_outlined,
                    l.audioAndSubtitles,
                    () => showTracksSheet(
                      context,
                      _engine,
                      onPicked: _showOverlay,
                    ),
                    24,
                  ),
                  round(
                    _fit == BoxFit.contain
                        ? Icons.fit_screen_outlined
                        : Icons.crop_free_rounded,
                    l.pictureSize,
                    () {
                      setState(
                        () => _fit = _fit == BoxFit.contain
                            ? BoxFit.cover
                            : BoxFit.contain,
                      );
                      _showOverlay();
                    },
                    24,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  round(
                    Icons.replay_10_rounded,
                    l.rewind10,
                    () => _seekBy(const Duration(seconds: -10)),
                    40,
                  ),
                  const SizedBox(width: 28),
                  Material(
                    color: const Color(0x33FFFFFF),
                    shape: const CircleBorder(),
                    child: round(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      _playing ? l.pause : l.play,
                      _togglePlay,
                      52,
                    ),
                  ),
                  const SizedBox(width: 28),
                  round(
                    Icons.forward_10_rounded,
                    l.forward10,
                    () => _seekBy(const Duration(seconds: 10)),
                    40,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text(
                    _clock(shown),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: ZaplineColors.focus,
                        inactiveTrackColor: const Color(0x55FFFFFF),
                        thumbColor: ZaplineColors.focus,
                        overlayColor: const Color(0x33F5B841),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                      ),
                      child: Slider(
                        value: value.toDouble(),
                        onChangeStart: total <= 0
                            ? null
                            : (v) {
                                _hideTimer?.cancel();
                                setState(() => _dragging = v);
                              },
                        onChanged: total <= 0
                            ? null
                            : (v) => setState(() => _dragging = v),
                        onChangeEnd: total <= 0
                            ? null
                            : (v) async {
                                final to = Duration(
                                  milliseconds: (v * total).round(),
                                );
                                setState(() {
                                  _dragging = null;
                                  _position = to;
                                });
                                await _engine.seek(to);
                                _showOverlay();
                              },
                      ),
                    ),
                  ),
                  Text(
                    _duration > Duration.zero
                        ? '-${_clock(_duration - shown)}'
                        : '--:--',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ZaplineColors.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (_hasNext)
                    round(Icons.skip_next_rounded, l.nextEpisode, _next, 26),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
