import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../input_mode.dart';
import '../l10n.dart';
import '../layout.dart';
import '../mobile/programme_sheet.dart';
import '../playback/playback_engine.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import '../widgets/channel_versions.dart';
import '../widgets/focus_card.dart';
import '../widgets/tracks_sheet.dart';

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

  /// Another version of the channel (4K, HD…) picked or fallen back to.
  Channel? _version;

  /// Versions that failed to play on this channel, by id.
  final _failed = <String>{};

  Channel get _channel => _version ?? widget.channels[_index];

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
          if (!mounted) return;
          if (_tryNextVersion()) return;
          setState(() => _error = e);
        }),
      );
    _open();
  }

  /// Phones play full screen and sideways, like any video app.
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
    if (_phoneChrome) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(const []);
    }
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
      _error = url == null ? _noArchive : null;
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
    _version = null;
    _failed.clear();
    _open();
  }

  void _goTo(int index) {
    if (index == _index && _replay == null) return;
    _index = index;
    _replay = null;
    _version = null;
    _failed.clear();
    _open();
  }

  /// When a live version fails, plays the next one that hasn't (a 4K
  /// stream the connection can't keep up with falls back to Full HD).
  bool _tryNextVersion() {
    if (_replay != null) return false;
    _failed.add(_channel.id);
    final next = widget.state
        .versionsOf(_channel)
        .where((v) => !_failed.contains(v.id))
        .firstOrNull;
    if (next == null) return false;
    _version = next;
    _open();
    return true;
  }

  Future<void> _pickVersion() async {
    final picked = await pickChannelVersion(context, widget.state, _channel);
    if (picked == null || !mounted) return;
    if (picked.remember) widget.state.preferVersion(picked.channel);
    if (picked.channel.id == _channel.id) return;
    _version = picked.channel;
    _failed.clear();
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
      return '${context.l10n.catchUpLine(replay.title)}  ·  '
          '${_hm(replay.start)}–${_hm(replay.stop)}';
    }
    final (now, next) = widget.state.nowNext(c);
    return [
      if (now != null) context.l10n.nowLine(now.title),
      if (next != null) '${_hm(next.start)} ${next.title}',
      if (now == null && next == null) c.groupTitle ?? '',
    ].join('   ·   ');
  }

  /// Remote hint as (icon, text); icons rather than ◀ ▶ characters, which
  /// Android renders as colour emoji.
  (IconData, String)? get _hint {
    if (_replay != null) {
      return (Icons.arrow_forward_rounded, context.l10n.backToLive);
    }
    if (_restartable != null) {
      return (Icons.arrow_back_rounded, context.l10n.watchFromStart);
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
              behavior: HitTestBehavior.opaque,
              onTap: () => context.isPhone && _overlay
                  ? setState(() => _overlay = false)
                  : _showOverlay(),
              onVerticalDragEnd: (d) =>
                  _zap((d.primaryVelocity ?? 0) < 0 ? 1 : -1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Android draws the picture in a native view that would
                  // swallow taps, leaving no way to bring the controls back.
                  IgnorePointer(
                    child: _engine.buildView(
                      fit: widget.state.settings.videoFit,
                    ),
                  ),
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
                  if (context.isPhone)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !_overlay,
                        child: AnimatedOpacity(
                          opacity: _overlay ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: _phoneControls(c),
                        ),
                      ),
                    )
                  else
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
                  if (_list && context.isPhone)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _closeList,
                        child: const ColoredBox(color: Colors.black45),
                      ),
                    ),
                  if (_list)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: MediaQuery.sizeOf(context).width < 480
                          ? MediaQuery.sizeOf(context).width
                          : 400,
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

  void _cycleFit() {
    final s = widget.state.settings;
    s.videoFit = switch (s.videoFit) {
      BoxFit.contain => BoxFit.cover,
      BoxFit.cover => BoxFit.fill,
      _ => BoxFit.contain,
    };
    widget.state.settingsChanged();
    _showOverlay();
  }

  /// Touch controls on phones: back, channel and tools on top; previous
  /// channel, from the start / back to live and next channel in the middle;
  /// the programme with what comes next and its progress below. Tapping
  /// the picture shows or hides them.
  Widget _phoneControls(Channel c) {
    final l = context.l10n;
    final replay = _replay;
    final (now, next) = widget.state.nowNext(c);
    final p = replay ?? now;
    final t = DateTime.now();
    final progress = p == null || replay != null
        ? null
        : (t.difference(p.start).inSeconds /
                  p.stop.difference(p.start).inSeconds)
              .clamp(0.0, 1.0);
    const shadow = [Shadow(blurRadius: 8)];

    Widget tool(IconData icon, String tip, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IconButton(
        tooltip: tip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          _hideTimer?.cancel();
          onTap();
        },
        icon: Icon(icon),
      ),
    );

    Widget round(
      IconData icon,
      String tip,
      VoidCallback onTap, {
      double size = 60,
      String? caption,
    }) => Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          onTap();
          _showOverlay();
        },
        child: Tooltip(
          message: tip,
          child: SizedBox.square(
            dimension: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: size * 0.46, color: Colors.white),
                if (caption != null)
                  Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xC0000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xD9000000),
          ],
          stops: [0, 0.32, 0.58, 1],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: l.back,
                    color: Colors.white,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  // Upright there is little room: the tools come first.
                  if (MediaQuery.sizeOf(context).width >= 600) ...[
                    ChannelLogo(channel: c, width: 52, height: 36),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${widget.state.channelNumber(c, _index)} · '
                                '${widget.state.displayName(c)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  shadows: shadow,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 0,
                              child: FittedBox(
                                child: _Badge(live: replay == null),
                              ),
                            ),
                          ],
                        ),
                        if (c.groupTitle != null)
                          Text(
                            c.groupTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFC9D2DE),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (p != null)
                    tool(Icons.info_outline_rounded, l.programmeInfo, () {
                      _showInfo(c, p);
                    }),
                  if (widget.state.versionsOf(c).length > 1)
                    tool(Icons.hd_outlined, l.channelVersion, _pickVersion),
                  tool(Icons.subtitles_outlined, l.audioAndSubtitles, _tracks),
                  tool(Icons.aspect_ratio_rounded, l.pictureSize, _cycleFit),
                  tool(
                    Icons.format_list_bulleted_rounded,
                    l.channelList,
                    _openList,
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    round(
                      Icons.skip_previous_rounded,
                      l.previousChannel,
                      () => _zap(-1),
                    ),
                    const SizedBox(width: 48),
                    if (replay != null)
                      round(
                        Icons.live_tv_rounded,
                        l.backToLive,
                        _goLive,
                        size: 76,
                        caption: l.liveShort,
                      )
                    else if (_restartable != null)
                      round(
                        Icons.replay_rounded,
                        l.watchFromStart,
                        _restart,
                        size: 76,
                        caption: l.startShort,
                      )
                    else
                      const SizedBox(width: 76),
                    const SizedBox(width: 48),
                    round(
                      Icons.skip_next_rounded,
                      l.nextChannel,
                      () => _zap(1),
                    ),
                  ],
                ),
              ),
              if (p != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                shadows: shadow,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_hm(p.start)}–${_hm(p.stop)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFC9D2DE),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              replay == null && next != null
                                  ? l.nextAt(_hm(next.start), next.title)
                                  : '',
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFC9D2DE),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, box) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Container(
                                height: 4,
                                width: box.maxWidth * progress,
                                decoration: BoxDecoration(
                                  color: ZaplineColors.focus,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Positioned(
                                left: box.maxWidth * progress - 7,
                                top: -5,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: ZaplineColors.focus,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.swipeHint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFC9D2DE),
                                ),
                              ),
                            ),
                            Text(
                              l.timeLeft(p.stop.difference(t)),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC9D2DE),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The programme's sheet; its actions act on this player.
  void _showInfo(Channel c, Programme p) => showProgrammeSheet(
    context,
    state: widget.state,
    channels: widget.channels,
    index: _index,
    programme: p,
    onPlay: (replay) {
      _replay = replay;
      _open();
    },
  );

  Future<void> _tracks() =>
      showTracksSheet(context, _engine, onPicked: _showOverlay);

  /// Set as [_error] when a replay has no archive; translated when shown
  /// (opening can happen before translations are available).
  static const _noArchive = '\u0000no-archive';

  Widget _errorView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _replay == null
              ? context.l10n.channelUnavailable
              : context.l10n.archiveUnavailable,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          _replay == null
              ? (InputMode.instance.touch
                    ? context.l10n.tryAnotherChannelTouch
                    : context.l10n.tryAnotherChannelKeys)
              : context.l10n.pressRightForLive,
          style: const TextStyle(fontSize: 18, color: ZaplineColors.textMuted),
        ),
        const SizedBox(height: 16),
        Text(
          _error == _noArchive ? context.l10n.noArchive : _error!,
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
          tooltip: context.l10n.prevChannelKey,
        ),
        IconButton(
          onPressed: () => _zap(1),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          tooltip: context.l10n.nextChannelKey,
        ),
        IconButton(
          onPressed: _openList,
          icon: const Icon(Icons.list_rounded),
          tooltip: context.l10n.channelListKey,
        ),
        if (_replay != null)
          TextButton.icon(
            onPressed: _goLive,
            icon: const Icon(Icons.live_tv_rounded),
            label: Text(context.l10n.backToLive),
          )
        else if (_restartable != null)
          TextButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay_rounded),
            label: Text(context.l10n.fromTheStart),
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
                      widget.state.displayName(c),
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
                          widget.state.displayName(c),
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
      live ? context.l10n.liveBadge : context.l10n.catchUpBadge,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: ZaplineColors.onFocus,
      ),
    ),
  );
}
