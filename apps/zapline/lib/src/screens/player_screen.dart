import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../input_mode.dart';
import '../l10n.dart';
import '../layout.dart';
import '../mobile/programme_sheet.dart';
import '../playback/playback_engine.dart';
import '../theme.dart';
import '../cast/cast_ui.dart';
import '../widgets/channel_logo.dart';
import '../widgets/channel_versions.dart';
import '../widgets/focus_card.dart';
import '../widgets/tracks_sheet.dart';
import 'search_screen.dart';

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

  /// The list being zapped through; digits typed for a channel outside it
  /// switch to all channels.
  late List<Channel> _channels = widget.channels;
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

  Channel get _channel => _version ?? _channels[_index];

  // ------------------------------------------------------------ zapping

  /// Keys pressed closer together than this are one burst: the info bar
  /// follows every press, the stream opens once the keys stop. A single
  /// press opens at once.
  static const _zapPause = Duration(milliseconds: 350);
  DateTime _lastZapAt = DateTime(0);
  Timer? _zapTimer;

  /// Bumped by every open, so one superseded while it waited stops there.
  int _openSeq = 0;

  /// What plays now and what played before it, for "back to the last
  /// channel" (0 on the remote, or the options).
  _Tuned? _playing;
  _Tuned? _previous;

  // ----------------------------------------------- loading and recovery

  /// Waiting for the first picture, or stalled to fill the buffer.
  bool _opening = false;
  bool _stalled = false;

  /// Shown only after a short wait, so quick zaps don't flash it.
  final _spinner = ValueNotifier<bool>(false);
  Timer? _spinnerDelay;

  /// Automatic attempts after a live stream failed or stalled.
  static const _maxRetries = 3;
  int _retries = 0;
  Timer? _retryTimer;
  Timer? _openTimeout;
  Timer? _stallTimer;

  // -------------------------------------------- what's on, cached

  /// What's on the current channel; read once per open and refreshed by
  /// [_clock] and when guides arrive, not on every build.
  Programme? _now;
  Programme? _next;

  /// [_now] when it can be watched from the start.
  Programme? _restartable;
  Timer? _clock;

  /// How far a vertical drag on the picture went; `null` when it started
  /// at the top edge (the system bar) and must not zap.
  double? _dragFrom;

  /// OK held down: options instead of the channel list.
  DateTime? _okDownAt;
  bool _okLong = false;
  Timer? _okTimer;

  @override
  void initState() {
    super.initState();
    widget.state.guideVersion.addListener(_guideArrived);
    _subs
      ..add(
        // A phone that sent this channel here works as the remote.
        widget.state.remoteKeys.stream.listen((k) {
          if (k == 'up') _zap(-1);
          if (k == 'down') _zap(1);
        }),
      )
      ..add(
        // Zap ends when playback position first advances on the new stream.
        // (Resolution events are not enough: two channels often share it.)
        _engine.position.listen((p) {
          if (p <= Duration.zero || !mounted) return;
          if (_opening) {
            _opening = false;
            _openTimeout?.cancel();
            _updateSpinner();
          }
          if (_retries > 0) {
            // Playing again: the next failure gets its full set of tries.
            setState(() => _retries = 0);
          }
          if (_zapWatch.isRunning) {
            _zapWatch.stop();
            setState(() => _lastZap = _zapWatch.elapsed);
          }
        }),
      )
      ..add(
        _engine.buffering.listen((b) {
          if (!mounted || b == _stalled) return;
          _stalled = b;
          _stallTimer?.cancel();
          // A picture frozen this long won't come back by itself.
          if (b && !_opening) {
            _stallTimer = Timer(const Duration(seconds: 20), () {
              if (mounted && _stalled) _onFailure(_streamTimeout);
            });
          }
          _updateSpinner();
        }),
      )
      ..add(
        _engine.errors.listen((e) {
          if (mounted) _onFailure(e);
        }),
      );
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(_readGuide);
    });
    _readGuide();
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
    widget.state.guideVersion.removeListener(_guideArrived);
    for (final t in [
      _hideTimer,
      _digitTimer,
      _zapTimer,
      _spinnerDelay,
      _retryTimer,
      _openTimeout,
      _stallTimer,
      _clock,
      _okTimer,
    ]) {
      t?.cancel();
    }
    for (final s in _subs) {
      s.cancel();
    }
    widget.state.nowPlaying = null;
    // The list the user came from follows the channel they ended on; told
    // once this frame is done, not while the tree is being taken down.
    final lastPlayed = widget.state.lastPlayed, last = _channels[_index];
    scheduleMicrotask(() => lastPlayed.value = last);
    _engine.dispose();
    _focus.dispose();
    _spinner.dispose();
    super.dispose();
  }

  void _guideArrived() {
    if (mounted) setState(_readGuide);
  }

  void _readGuide() {
    if (_replay != null) {
      _now = _next = _restartable = null;
      return;
    }
    final c = _channel;
    final (now, next) = widget.state.nowNext(c);
    _now = now;
    _next = next;
    _restartable = now != null && widget.state.catchupUrl(c, now) != null
        ? now
        : null;
  }

  /// Moves playback to a TV or PC running Zapline; this phone stops.
  Future<void> _sendToTv() async {
    final request = castRequestFor(widget.state, channel: _channel);
    if (request == null) return;
    await sendToTv(
      context,
      widget.state,
      request: request,
      title: widget.state.displayName(_channel),
      stopHere: () => Navigator.of(context).pop(),
      channels: _channels,
      index: _index,
    );
  }

  void _updateSpinner() {
    final want =
        (_opening || _stalled || _retryTimer != null) && _error == null;
    if (!want) {
      _spinnerDelay?.cancel();
      _spinnerDelay = null;
      _spinner.value = false;
    } else if (!_spinner.value && _spinnerDelay == null) {
      _spinnerDelay = Timer(const Duration(milliseconds: 400), () {
        _spinnerDelay = null;
        if (mounted) _spinner.value = true;
      });
    }
  }

  Future<void> _open({bool retry = false}) async {
    final seq = ++_openSeq;
    _zapTimer?.cancel();
    _retryTimer?.cancel();
    _retryTimer = null;
    _openTimeout?.cancel();
    _stallTimer?.cancel();
    if (!retry) _retries = 0;
    final replay = _replay;
    final url = replay == null
        ? widget.state.playable(_channel).streamUrl
        : widget.state.catchupUrl(_channel, replay);
    setState(() {
      _error = url == null ? _noArchive : null;
      _lastZap = null;
      _readGuide();
    });
    if (!retry) _showOverlay();
    // Stop first so a late position event from the old stream cannot end
    // the measurement early.
    _zapWatch.stop();
    _opening = url != null;
    _stalled = false;
    _updateSpinner();
    await _engine.stop();
    if (url == null || seq != _openSeq || !mounted) return;
    if (replay == null) {
      widget.state.markWatched(_channel);
      final tuned = _Tuned(_channels, _index);
      if (_playing case final p? when !p.same(tuned)) _previous = p;
      _playing = tuned;
    }
    widget.state.nowPlaying = (
      title: widget.state.displayName(_channel),
      subtitle: (replay ?? _now)?.title,
    );
    _openTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted && _opening && _engine.currentPosition == Duration.zero) {
        _onFailure(_streamTimeout);
      }
    });
    _zapWatch
      ..reset()
      ..start();
    await _engine.open(url, headers: _channel.httpHeaders);
  }

  /// Playback failed: another version of the channel, then a few new
  /// attempts with growing pauses, then the error with a way to retry.
  void _onFailure(String error) {
    _openTimeout?.cancel();
    _stallTimer?.cancel();
    _opening = _stalled = false;
    if (_tryNextVersion()) return;
    if (_retries < _maxRetries) {
      _retries++;
      _engine.stop();
      setState(() {});
      _retryTimer = Timer(Duration(seconds: [1, 3, 6][_retries - 1]), () {
        _retryTimer = null;
        if (mounted) _open(retry: true);
      });
      _updateSpinner();
      return;
    }
    setState(() => _error = error);
    _updateSpinner();
  }

  /// Tries again from the first attempt, after the automatic ones gave up.
  void _retryNow() {
    _failed.clear();
    _version = null;
    _open();
  }

  void _zap(int delta) {
    final n = _channels.length;
    if (n == 0) return;
    _index = (_index + delta + n) % n;
    _replay = null;
    _version = null;
    _failed.clear();
    _scheduleOpen();
  }

  /// Opens at once, unless keys come in a burst (a held Up, quick taps):
  /// then the info bar follows and only the channel stopped on opens, so a
  /// cheap stick never starts a dozen players it throws away.
  void _scheduleOpen() {
    final now = DateTime.now();
    final burst = now.difference(_lastZapAt) < _zapPause;
    _lastZapAt = now;
    _zapTimer?.cancel();
    if (!burst) {
      _open();
      return;
    }
    _openSeq++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _openTimeout?.cancel();
    _engine.stop();
    _opening = true;
    _stalled = false;
    _updateSpinner();
    setState(() {
      _error = null;
      _lastZap = null;
      _readGuide();
    });
    _showOverlay();
    _zapTimer = Timer(_zapPause, _open);
  }

  void _goTo(int index, [List<Channel>? list]) {
    if (list != null && !identical(list, _channels)) {
      _channels = list;
    } else if (index == _index && _replay == null) {
      return;
    }
    _index = index;
    _replay = null;
    _version = null;
    _failed.clear();
    _open();
  }

  /// Back to the channel watched before this one.
  void _recall() {
    final p = _previous;
    if (p == null || p.index >= p.channels.length) return;
    _goTo(p.index, p.channels);
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
    _open(retry: true);
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

  void _showOverlay() {
    _hideTimer?.cancel();
    setState(() => _overlay = true);
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _overlay = false);
    });
  }

  /// The channel [number] stands for: in the list being watched, or else
  /// among all channels. `null` when there is none.
  (List<Channel>, int)? _channelNumbered(int number) {
    int find(List<Channel> list) {
      for (var i = 0; i < list.length; i++) {
        if (widget.state.channelNumber(list[i], i) == number) return i;
      }
      return -1;
    }

    final here = find(_channels);
    if (here >= 0) return (_channels, here);
    final all = widget.state.channels();
    final there = find(all);
    return there >= 0 ? (all, there) : null;
  }

  void _typeDigit(String d) {
    _digitTimer?.cancel();
    if (_digits.length < 4) setState(() => _digits += d);
    _digitTimer = Timer(const Duration(milliseconds: 1500), _applyDigits);
  }

  void _applyDigits() {
    _digitTimer?.cancel();
    final n = int.tryParse(_digits);
    setState(() => _digits = '');
    if (n == null) return;
    final found = _channelNumbered(n);
    if (found != null) return _goTo(found.$2, found.$1);
    // A lone 0 goes back to the last channel, as on most TV remotes.
    if (n == 0) _recall();
  }

  static final _digitKeys = {
    for (var i = 0; i <= 9; i++) ...{
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + i): '$i',
      LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + i): '$i',
    },
  };

  static final _okKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    // The channel list moves focus itself.
    if (_list) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (_okKeys.contains(k)) return _onOk(e);
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
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
    } else if (e is KeyDownEvent && k == LogicalKeyboardKey.contextMenu) {
      _openOptions();
    } else if (e is KeyDownEvent && k == LogicalKeyboardKey.backspace) {
      _recall();
    } else if (e is KeyDownEvent &&
        (k == LogicalKeyboardKey.browserSearch ||
            k == LogicalKeyboardKey.find)) {
      // Search takes the player's place: what's picked there plays in a
      // new one, instead of a player stacked on this one.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SearchScreen(state: widget.state),
        ),
      );
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

  /// OK: digits typed are applied at once, an error is retried, otherwise
  /// the channel list opens. Held down it opens the options; this works on
  /// remotes that send no key repeats too (Fire TV).
  KeyEventResult _onOk(KeyEvent e) {
    switch (e) {
      case KeyDownEvent():
        _okDownAt = DateTime.now();
        _okLong = false;
        _okTimer?.cancel();
        _okTimer = Timer(const Duration(milliseconds: 550), _okHeld);
      case KeyRepeatEvent():
        _okHeld();
      case KeyUpEvent():
        _okTimer?.cancel();
        // A release left over from the screen before opens nothing.
        if (_okDownAt == null || _okLong) break;
        _okDownAt = null;
        if (_digits.isNotEmpty) {
          _applyDigits();
        } else if (_error != null && _error != _noArchive) {
          _retryNow();
        } else {
          _openList();
        }
    }
    return KeyEventResult.handled;
  }

  void _okHeld() {
    _okTimer?.cancel();
    if (_okDownAt == null || _okLong || !mounted) return;
    _okLong = true;
    _okDownAt = null;
    _openOptions();
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
    final now = _now, next = _next;
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

  String _fitName(BoxFit fit) => switch (fit) {
    BoxFit.cover => context.l10n.fitZoom,
    BoxFit.fill => context.l10n.fitStretch,
    _ => context.l10n.fitFit,
  };

  /// Remote and keyboard options for what's playing: audio and subtitles,
  /// picture size, version, programme details, favourite, last channel.
  Future<void> _openOptions() async {
    _hideTimer?.cancel();
    final state = widget.state;
    final l = context.l10n;
    final c = _channel;
    final p = _replay ?? _now;
    final previous = _previous;
    final back = previous == null || previous.index >= previous.channels.length
        ? null
        : previous.channels[previous.index];
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) {
          void close(VoidCallback then) {
            Navigator.of(dialog).pop();
            then();
          }

          final favourite = state.isFavourite(c);
          var first = true;
          Widget action(IconData icon, String label, VoidCallback onPressed) {
            final autofocus = first;
            first = false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FocusCard(
                autofocus: autofocus,
                onPressed: onPressed,
                child: Row(
                  children: [
                    Icon(icon, size: 22),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Material(
                color: ZaplineColors.surface,
                borderRadius: BorderRadius.circular(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                          child: Text(
                            state.displayName(c),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        action(
                          Icons.subtitles_outlined,
                          l.audioAndSubtitles,
                          () => close(_tracks),
                        ),
                        action(
                          Icons.aspect_ratio_rounded,
                          l.pictureSizeIs(_fitName(state.settings.videoFit)),
                          () {
                            _cycleFit();
                            setDialog(() {});
                          },
                        ),
                        if (state.versionsOf(c).length > 1)
                          action(
                            Icons.hd_outlined,
                            l.channelVersion,
                            () => close(_pickVersion),
                          ),
                        if (_replay != null)
                          action(
                            Icons.live_tv_rounded,
                            l.backToLive,
                            () => close(_goLive),
                          )
                        else if (_restartable != null)
                          action(
                            Icons.replay_rounded,
                            l.watchFromStart,
                            () => close(_restart),
                          ),
                        if (p != null)
                          action(
                            Icons.info_outline_rounded,
                            l.programmeInfo,
                            () => close(() => _showInfo(c, p)),
                          ),
                        action(
                          favourite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          favourite
                              ? l.removeFromFavourites
                              : l.addToFavourites,
                          () {
                            state.toggleFavourite(c);
                            setDialog(() {});
                          },
                        ),
                        if (back != null)
                          action(
                            Icons.history_rounded,
                            l.backToChannel(state.displayName(back)),
                            () => close(_recall),
                          ),
                        action(
                          Icons.format_list_bulleted_rounded,
                          l.channelList,
                          () => close(_openList),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (mounted) _focus.requestFocus();
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
              // A deliberate swipe zaps; a short drag, or one from the top
              // edge pulling down the system bar, does not.
              onVerticalDragStart: (d) {
                _dragFrom = d.localPosition.dy < 40 ? null : 0;
              },
              onVerticalDragUpdate: (d) {
                if (_dragFrom != null) _dragFrom = _dragFrom! + d.delta.dy;
              },
              onVerticalDragEnd: (d) {
                final moved = _dragFrom;
                _dragFrom = null;
                if (moved == null) return;
                final v = d.primaryVelocity ?? 0;
                if (moved.abs() >= 72 || v.abs() >= 900) {
                  _zap((moved.abs() >= 72 ? moved : v) < 0 ? 1 : -1);
                }
              },
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
                  ValueListenableBuilder<bool>(
                    valueListenable: _spinner,
                    builder: (context, on, _) =>
                        on ? _loadingView() : const SizedBox.shrink(),
                  ),
                  if (_error != null) _errorView(),
                  if (_digits.isNotEmpty)
                    Positioned(top: 40, right: 56, child: _digitPreview()),
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
                        channels: _channels,
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
    // Only the picture changes: no need to reload every list.
    widget.state.displayChanged();
    setState(() {});
    _showOverlay();
  }

  /// Touch controls on phones: back, channel and tools on top; previous
  /// channel, from the start / back to live and next channel in the middle;
  /// the programme with what comes next and its progress below. Tapping
  /// the picture shows or hides them.
  Widget _phoneControls(Channel c) {
    final l = context.l10n;
    final replay = _replay;
    final next = _next;
    final p = replay ?? _now;
    final t = DateTime.now();
    final progress = p == null || replay != null
        ? null
        : (t.difference(p.start).inSeconds /
                  p.stop.difference(p.start).inSeconds)
              .clamp(0.0, 1.0);
    const shadow = [Shadow(blurRadius: 8)];

    Widget tool(IconData icon, String tip, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton(
        tooltip: tip,
        // Up to six tools share the top row of a phone held upright.
        visualDensity: VisualDensity.compact,
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
            // A caption inside a circle can't grow much with large text.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
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
                  ..._tools(c, p, tool),
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

  /// The phone's tools, most used last (nearest the thumb). Upright there
  /// is room for the channel's name and three of them: the rest go in a
  /// "More" menu.
  List<Widget> _tools(
    Channel c,
    Programme? p,
    Widget Function(IconData, String, VoidCallback) tool,
  ) {
    final l = context.l10n;
    final state = widget.state;
    final favourite = state.isFavourite(c);
    final all = <(IconData, String, VoidCallback)>[
      if (p != null)
        (Icons.info_outline_rounded, l.programmeInfo, () => _showInfo(c, p)),
      (
        favourite ? Icons.star_rounded : Icons.star_outline_rounded,
        favourite ? l.removeFromFavourites : l.addToFavourites,
        () => setState(() => state.toggleFavourite(c)),
      ),
      (Icons.cast_rounded, l.castButton, _sendToTv),
      if (state.versionsOf(c).length > 1)
        (Icons.hd_outlined, l.channelVersion, _pickVersion),
      (Icons.aspect_ratio_rounded, l.pictureSize, _cycleFit),
      (Icons.subtitles_outlined, l.audioAndSubtitles, _tracks),
      (Icons.format_list_bulleted_rounded, l.channelList, _openList),
    ];
    if (MediaQuery.sizeOf(context).width >= 600) {
      return [for (final (i, t, f) in all) tool(i, t, f)];
    }
    final shown = all.sublist(all.length - 2);
    final more = all.sublist(0, all.length - 2);
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: PopupMenuButton<VoidCallback>(
          tooltip: l.moreOptions,
          icon: const Icon(Icons.more_horiz_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
          ),
          onOpened: () => _hideTimer?.cancel(),
          onCanceled: _showOverlay,
          onSelected: (f) => f(),
          itemBuilder: (_) => [
            for (final (icon, text, f) in more)
              PopupMenuItem(
                value: f,
                child: Row(
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 14),
                    Flexible(child: Text(text)),
                  ],
                ),
              ),
          ],
        ),
      ),
      for (final (i, t, f) in shown) tool(i, t, f),
    ];
  }

  /// The programme's sheet; its actions act on this player.
  void _showInfo(Channel c, Programme p) => showProgrammeSheet(
    context,
    state: widget.state,
    channels: _channels,
    index: _index,
    programme: p,
    onPlay: (replay) {
      _replay = replay;
      _open();
    },
  );

  Future<void> _tracks() =>
      showTracksSheet(context, _engine, onPicked: _showOverlay);

  /// Set as [_error] when a replay has no archive or a stream never
  /// started; translated when shown (opening can happen before
  /// translations are available).
  static const _noArchive = '\u0000no-archive';
  static const _streamTimeout = '\u0000timeout';

  /// The number being typed, with the channel it will open.
  Widget _digitPreview() {
    final n = int.tryParse(_digits);
    final found = n == null ? null : _channelNumbered(n);
    final name = found == null
        ? (n == null || n == 0 ? null : context.l10n.noChannelNumber(n))
        : widget.state.displayName(found.$1[found.$2]);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
      decoration: BoxDecoration(
        color: ZaplineColors.ground.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _digits,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w800,
              color: ZaplineColors.focus,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (name != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: found == null
                      ? ZaplineColors.textMuted
                      : ZaplineColors.text,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A spinner while the channel starts or the stream catches up, with the
  /// attempt when it reconnects by itself.
  Widget _loadingView() => IgnorePointer(
    child: Center(
      child: Semantics(
        label: context.l10n.loadingChannel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 56,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                color: ZaplineColors.focus,
              ),
            ),
            if (_retries > 0) ...[
              const SizedBox(height: 18),
              Text(
                context.l10n.reconnecting(_retries, _maxRetries),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 8)],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _errorView() {
    final l = context.l10n;
    final noArchive = _error == _noArchive;
    final keys = !InputMode.instance.touch && !InputMode.instance.pointer;
    final detail = switch (_error) {
      _noArchive => l.noArchive,
      _streamTimeout => l.streamTimeout,
      final e? => e,
      null => '',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _replay == null ? l.channelUnavailable : l.archiveUnavailable,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              noArchive
                  ? l.pressRightForLive
                  : keys
                  ? l.pressOkToRetry
                  : l.tryAnotherChannelTouch,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: ZaplineColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              detail,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: ZaplineColors.textMuted,
              ),
            ),
            if (!keys) ...[
              const SizedBox(height: 20),
              ExcludeFocus(
                child: noArchive
                    ? FilledButton.icon(
                        onPressed: _goLive,
                        icon: const Icon(Icons.live_tv_rounded),
                        label: Text(l.backToLive),
                      )
                    : FilledButton.icon(
                        onPressed: _retryNow,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l.retry),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
        IconButton(
          onPressed: _openOptions,
          icon: const Icon(Icons.tune_rounded),
          tooltip: context.l10n.playerOptions,
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
            if (!InputMode.instance.pointer)
              for (final (icon, text) in [
                ?_hint,
                (
                  Icons.radio_button_checked_rounded,
                  context.l10n.holdOkForOptions,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
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
                ),
            Text(
              // The zap time only matters when measuring engines and
              // devices; users see the clock.
              kReleaseMode || _lastZap == null
                  ? _hm(DateTime.now())
                  : '${_engine.name} · zap ${_lastZap!.inMilliseconds} ms',
              style: const TextStyle(
                fontSize: 16,
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

/// A channel tuned in: the list it was in and where.
class _Tuned {
  const _Tuned(this.channels, this.index);

  final List<Channel> channels;
  final int index;

  bool same(_Tuned o) =>
      ZaplineDatabase.channelKey(channels[index]) ==
      ZaplineDatabase.channelKey(o.channels[o.index]);
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
    initialScrollOffset:
        (widget.current - 3).clamp(0, 1 << 30) *
        scaledExtent(context, _rowHeight),
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
        itemExtent: scaledExtent(context, _rowHeight),
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
                          // The card's own colour, faded: readable on the
                          // focused row without a layer per row.
                          Builder(
                            builder: (context) => Text(
                              now.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: DefaultTextStyle.of(context).style.color
                                    ?.withValues(alpha: 0.75),
                              ),
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
