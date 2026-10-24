import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lineup_core/lineup_core.dart';

import '../app_state.dart';
import '../playback/playback_engine.dart';
import '../theme.dart';

/// Full-screen player for live channels and catch-up.
///
/// Remote keys: Up/Down and Channel+/- zap, digits jump to a channel number,
/// Left restarts the current programme from the archive, Right returns to
/// live, Select toggles the info bar, Back exits. The info bar shows the
/// measured zap time (request → first frame) to compare engines and devices.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.state,
    required this.channels,
    required this.initialIndex,
    this.replay,
  });

  final AppState state;
  final List<Channel> channels;
  final int initialIndex;

  /// Start by replaying this programme of the initial channel.
  final Programme? replay;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final PlaybackEngine _engine = createDefaultEngine();
  late int _index = widget.initialIndex;

  /// The archived programme being replayed, `null` when live.
  late Programme? _replay = widget.replay;

  final _zapWatch = Stopwatch();
  Duration? _lastZap;
  String? _error;
  bool _overlay = true;
  Timer? _hideTimer;
  final _subs = <StreamSubscription<Object?>>[];

  /// Digits typed on the remote, applied after a short pause.
  String _digits = '';
  Timer? _digitTimer;

  Channel get _channel => widget.channels[_index];

  @override
  void initState() {
    super.initState();
    _subs
      ..add(
        // Zap ends when playback position first advances on the new stream.
        // (Resolution events are not enough: two channels often share it.)
        _engine.position.listen((p) {
          if (p > Duration.zero && _zapWatch.isRunning) {
            _zapWatch.stop();
            setState(() => _lastZap = _zapWatch.elapsed);
          }
        }),
      )
      ..add(
        _engine.errors.listen((e) {
          if (mounted) setState(() => _error = e);
        }),
      );
    _open();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _digitTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _engine.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final replay = _replay;
    final url = replay == null
        ? _channel.streamUrl
        : widget.state.catchupUrl(_channel, replay);
    setState(() {
      _error = url == null ? 'No archive for this programme' : null;
      _lastZap = null;
    });
    _showOverlay();
    // Stop first so a late position event from the old stream cannot end
    // the measurement early.
    _zapWatch.stop();
    await _engine.stop();
    if (url == null) return;
    _zapWatch
      ..reset()
      ..start();
    await _engine.open(url, headers: _channel.httpHeaders);
  }

  void _zap(int delta) {
    final n = widget.channels.length;
    _index = (_index + delta + n) % n;
    _replay = null;
    _open();
  }

  void _goTo(int index) {
    if (index == _index && _replay == null) return;
    _index = index;
    _replay = null;
    _open();
  }

  /// The live programme of the current channel if it can be replayed.
  Programme? get _restartable {
    if (_replay != null) return null;
    final (now, _) = widget.state.nowNext(_channel);
    if (now == null) return null;
    return widget.state.catchupUrl(_channel, now) == null ? null : now;
  }

  void _showOverlay() {
    _hideTimer?.cancel();
    setState(() => _overlay = true);
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _overlay = false);
    });
  }

  void _typeDigit(String d) {
    _digitTimer?.cancel();
    if (_digits.length < 4) setState(() => _digits += d);
    _digitTimer = Timer(const Duration(milliseconds: 1500), () {
      final n = int.tryParse(_digits);
      setState(() => _digits = '');
      if (n == null) return;
      final i = widget.channels.indexWhere((c) => c.number == n);
      if (i >= 0) _goTo(i);
    });
  }

  static final _digitKeys = {
    for (var i = 0; i <= 9; i++) ...{
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + i): '$i',
      LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + i): '$i',
    },
  };

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final digit = _digitKeys[k];
    if (digit != null && e is KeyDownEvent) {
      _typeDigit(digit);
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.channelUp) {
      _zap(-1);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.channelDown) {
      _zap(1);
    } else if (k == LogicalKeyboardKey.arrowLeft && _restartable != null) {
      _replay = _restartable;
      _open();
    } else if (k == LogicalKeyboardKey.arrowRight && _replay != null) {
      _replay = null;
      _open();
    } else if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight) {
      _overlay ? setState(() => _overlay = false) : _showOverlay();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static String _hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  String _infoLine(Channel c) {
    final replay = _replay;
    if (replay != null) {
      return 'Catch-up: ${replay.title}  ·  '
          '${_hm(replay.start)}–${_hm(replay.stop)}';
    }
    final (now, next) = widget.state.nowNext(c);
    return [
      if (now != null) 'Now: ${now.title}',
      if (next != null) '${_hm(next.start)} ${next.title}',
      if (now == null && next == null) c.groupTitle ?? '',
    ].join('   ·   ');
  }

  /// Remote hint as (icon, text); icons rather than ◀ ▶ characters, which
  /// Android renders as colour emoji.
  (IconData, String)? get _hint {
    if (_replay != null) return (Icons.arrow_forward_rounded, 'Back to live');
    if (_restartable != null) {
      return (Icons.arrow_back_rounded, 'Watch from the start');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = _channel;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          onTap: _showOverlay,
          onVerticalDragEnd: (d) => _zap((d.primaryVelocity ?? 0) < 0 ? 1 : -1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _engine.buildView(),
              if (_error != null) _errorView(),
              if (_digits.isNotEmpty)
                Positioned(
                  top: 40,
                  right: 56,
                  child: Text(
                    _digits,
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: LineupColors.focus,
                      fontFeatures: [FontFeature.tabularFigures()],
                      shadows: [Shadow(blurRadius: 12)],
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                left: 0,
                right: 0,
                bottom: _overlay ? 0 : -160,
                child: _infoBar(c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _replay == null
              ? 'This channel is not available right now'
              : 'This programme is not available in the archive',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          _replay == null
              ? 'Press Up or Down to try another channel.'
              : 'Press Right to go back to live.',
          style: const TextStyle(fontSize: 18, color: LineupColors.textMuted),
        ),
        const SizedBox(height: 16),
        Text(
          _error!,
          style: const TextStyle(fontSize: 14, color: LineupColors.textMuted),
        ),
      ],
    ),
  );

  Widget _infoBar(Channel c) => Container(
    height: 140,
    padding: const EdgeInsets.symmetric(horizontal: 48),
    color: LineupColors.ground.withValues(alpha: 0.94),
    child: Row(
      children: [
        Text(
          '${c.number ?? _index + 1}',
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: LineupColors.focus,
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _Badge(live: _replay == null),
                ],
              ),
              Text(
                _infoLine(c),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  color: LineupColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_hint case (final icon, final text))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            Text(
              _lastZap == null
                  ? '${_engine.name} · tuning…'
                  : '${_engine.name} · zap ${_lastZap!.inMilliseconds} ms',
              style: const TextStyle(
                fontSize: 14,
                color: LineupColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: live ? LineupColors.live : LineupColors.focus,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      live ? 'LIVE' : 'CATCH-UP',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: LineupColors.onFocus,
      ),
    ),
  );
}
