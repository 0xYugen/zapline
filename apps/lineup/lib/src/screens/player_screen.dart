import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lineup_core/lineup_core.dart';

import '../playback/playback_engine.dart';
import '../theme.dart';

/// Full-screen live player with channel zapping.
///
/// Up/Down and Channel+/- zap, Select toggles the info bar, Back exits.
/// The info bar shows the measured zap time (request → first frame), the
/// key Phase 0 metric to compare engines and devices.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.channels,
    required this.initialIndex,
  });

  final List<Channel> channels;
  final int initialIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final PlaybackEngine _engine = createDefaultEngine();
  late int _index = widget.initialIndex;

  final _zapWatch = Stopwatch();
  Duration? _lastZap;
  String? _error;
  bool _overlay = true;
  Timer? _hideTimer;
  final _subs = <StreamSubscription<Object?>>[];

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
    for (final s in _subs) {
      s.cancel();
    }
    _engine.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _error = null;
      _lastZap = null;
    });
    _showOverlay();
    // Stop first so a late position event from the old channel cannot end
    // the measurement early.
    _zapWatch.stop();
    await _engine.stop();
    _zapWatch
      ..reset()
      ..start();
    await _engine.open(_channel.streamUrl, headers: _channel.httpHeaders);
  }

  void _zap(int delta) {
    final n = widget.channels.length;
    _index = (_index + delta + n) % n;
    _open();
  }

  void _showOverlay() {
    _hideTimer?.cancel();
    setState(() => _overlay = true);
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _overlay = false);
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.channelUp) {
      _zap(-1);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.channelDown) {
      _zap(1);
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
              if (_error != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'This channel is not available right now',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Press Up or Down to try another channel.',
                        style: TextStyle(
                          fontSize: 18,
                          color: LineupColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: LineupColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                left: 0,
                right: 0,
                bottom: _overlay ? 0 : -160,
                child: Container(
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
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (c.groupTitle != null)
                              Text(
                                c.groupTitle!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: LineupColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _lastZap == null
                            ? '${_engine.name} · tuning…'
                            : '${_engine.name} · zap '
                                  '${_lastZap!.inMilliseconds} ms',
                        style: const TextStyle(
                          fontSize: 16,
                          color: LineupColors.textMuted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
