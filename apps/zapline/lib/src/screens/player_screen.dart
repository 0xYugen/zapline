import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../input_mode.dart';
import '../playback/playback_engine.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import '../widgets/focus_card.dart';

/// Full-screen player for live channels and catch-up.
///
/// Remote keys: Up/Down and Channel+/- zap, digits jump to a channel number,
/// Left restarts the current programme from the archive, Right returns to
/// live, Select opens the channel list, Info toggles the info bar, Back
/// exits. The info bar shows the
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

  /// The channel list over the picture.
  bool _list = false;
  final _focus = FocusNode(debugLabel: 'player');
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
    _focus.dispose();
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
    if (replay == null) widget.state.markWatched(_channel);
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
      final channels = widget.channels;
      for (var i = 0; i < channels.length; i++) {
        if (widget.state.channelNumber(channels[i], i) == n) return _goTo(i);
      }
    });
  }

  static final _digitKeys = {
    for (var i = 0; i <= 9; i++) ...{
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + i): '$i',
      LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + i): '$i',
    },
  };

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    // The channel list moves focus itself.
    if (_list) return KeyEventResult.ignored;
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final digit = _digitKeys[k];
    if (digit != null && e is KeyDownEvent) {
      _typeDigit(digit);
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.channelUp ||
        k == LogicalKeyboardKey.pageUp) {
      _zap(-1);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.channelDown ||
        k == LogicalKeyboardKey.pageDown) {
      _zap(1);
    } else if (k == LogicalKeyboardKey.arrowLeft && _restartable != null) {
      _restart();
    } else if (k == LogicalKeyboardKey.arrowRight && _replay != null) {
      _goLive();
    } else if (e is KeyDownEvent &&
        (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.contextMenu)) {
      _openList();
    } else if (k == LogicalKeyboardKey.info ||
        k == LogicalKeyboardKey.keyI ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight) {
      _overlay ? setState(() => _overlay = false) : _showOverlay();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _openList() {
    _hideTimer?.cancel();
    setState(() {
      _list = true;
      _overlay = false;
    });
  }

  void _closeList() {
    setState(() => _list = false);
    _focus.requestFocus();
  }

  void _restart() {
    _replay = _restartable;
    _open();
  }

  void _goLive() {
    _replay = null;
    _open();
  }

  String _hm(DateTime t) => widget.state.time(t);

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
    return PopScope(
      // Back closes the channel list before leaving the player.
      canPop: !_list,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _list) _closeList();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Listener(
            // Mouse: moving shows the info bar, the wheel zaps.
            onPointerHover: (_) {
              if (!_overlay) _showOverlay();
            },
            onPointerSignal: (e) {
              if (e is PointerScrollEvent && e.scrollDelta.dy != 0) {
                _zap(e.scrollDelta.dy > 0 ? 1 : -1);
              }
            },
            child: GestureDetector(
              onTap: _showOverlay,
              onVerticalDragEnd: (d) =>
                  _zap((d.primaryVelocity ?? 0) < 0 ? 1 : -1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _engine.buildView(fit: widget.state.settings.videoFit),
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
                          color: ZaplineColors.focus,
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
                    // Rebuild when switching between mouse and keys.
                    child: ListenableBuilder(
                      listenable: InputMode.instance,
                      builder: (context, _) => _infoBar(c),
                    ),
                  ),
                  if (_list)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: 400,
                      child: _ChannelList(
                        state: widget.state,
                        channels: widget.channels,
                        current: _index,
                        onSelected: (i) {
                          _closeList();
                          _goTo(i);
                        },
                      ),
                    ),
                ],
              ),
            ),
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
          style: const TextStyle(fontSize: 18, color: ZaplineColors.textMuted),
        ),
        const SizedBox(height: 16),
        Text(
          _error!,
          style: const TextStyle(fontSize: 14, color: ZaplineColors.textMuted),
        ),
      ],
    ),
  );

  /// Buttons for mouse and touch users. Not focusable: remote and keyboard
  /// users have keys for all of these.
  Widget _pointerControls() => ExcludeFocus(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _zap(-1),
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          tooltip: 'Previous channel (Page Up)',
        ),
        IconButton(
          onPressed: () => _zap(1),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          tooltip: 'Next channel (Page Down)',
        ),
        IconButton(
          onPressed: _openList,
          icon: const Icon(Icons.list_rounded),
          tooltip: 'Channel list (Enter)',
        ),
        if (_replay != null)
          TextButton.icon(
            onPressed: _goLive,
            icon: const Icon(Icons.live_tv_rounded),
            label: const Text('Back to live'),
          )
        else if (_restartable != null)
          TextButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('From the start'),
          ),
      ],
    ),
  );

  Widget _infoBar(Channel c) => Container(
    height: 140,
    padding: const EdgeInsets.symmetric(horizontal: 48),
    color: ZaplineColors.ground.withValues(alpha: 0.94),
    child: Row(
      children: [
        Text(
          '${widget.state.channelNumber(c, _index)}',
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: ZaplineColors.focus,
          ),
        ),
        const SizedBox(width: 24),
        ChannelLogo(channel: c, width: 84, height: 60),
        const SizedBox(width: 24),
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
                  color: ZaplineColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (InputMode.instance.pointer) _pointerControls(),
            if (_hint case (final icon, final text)
                when !InputMode.instance.pointer)
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
                color: ZaplineColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Channels of the list being watched, over the left of the picture. Opens
/// on the current channel; OK switches, Back closes.
class _ChannelList extends StatefulWidget {
  const _ChannelList({
    required this.state,
    required this.channels,
    required this.current,
    required this.onSelected,
  });

  final AppState state;
  final List<Channel> channels;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  State<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<_ChannelList> {
  static const _rowHeight = 72.0;

  late final _scroll = ScrollController(
    initialScrollOffset: (widget.current - 3).clamp(0, 1 << 30) * _rowHeight,
  );

  final _currentFocus = FocusNode(debugLabel: 'current channel');

  @override
  void initState() {
    super.initState();
    // The player holds focus, so autofocus alone would not move it here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _currentFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _currentFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: ZaplineColors.ground.withValues(alpha: 0.94),
    child: FocusTraversalGroup(
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        itemCount: widget.channels.length,
        itemExtent: _rowHeight,
        itemBuilder: (context, i) {
          final c = widget.channels[i];
          final (now, _) = widget.state.nowNext(c);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FocusCard(
              focusNode: i == widget.current ? _currentFocus : null,
              selected: i == widget.current,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onPressed: () => widget.onSelected(i),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${widget.state.channelNumber(c, i)}',
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  ChannelLogo(channel: c, width: 48, height: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (now != null)
                          // Inherits the card's colour so it stays readable
                          // on the focused row.
                          Opacity(
                            opacity: 0.75,
                            child: Text(
                              now.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
      color: live ? ZaplineColors.live : ZaplineColors.focus,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      live ? 'LIVE' : 'CATCH-UP',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: ZaplineColors.onFocus,
      ),
    ),
  );
}
