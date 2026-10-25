import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../input_mode.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import '../widgets/focus_card.dart';
import 'player_screen.dart';

/// The TV guide on a screen of its own.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.state, required this.channels});

  final AppState state;
  final List<Channel> channels;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 0),
      child: GuideGrid(state: state, channels: channels, autofocus: true),
    ),
  );
}

/// Channels and their programmes in one grid: what's on now and next.
///
/// Shows a fixed two-hour window that pages by half an hour when the D-pad
/// reaches an edge, the way TV guides behave on a remote. Rows are built
/// lazily and each row loads only its own programmes for the visible window,
/// so the grid stays cheap with tens of thousands of channels.
class GuideGrid extends StatefulWidget {
  const GuideGrid({
    super.key,
    required this.state,
    required this.channels,
    this.autofocus = false,
    this.caption,
    this.onExitLeft,
    this.onLongPress,
  });

  final AppState state;
  final List<Channel> channels;

  /// Focus what's on now on the first channel once built.
  final bool autofocus;

  /// Shown over the channel column, with the day (the group's name).
  final String? caption;

  /// Left on a programme airing now: leave the grid (to the groups) instead
  /// of going back in time.
  final VoidCallback? onExitLeft;

  /// Holding OK on a channel's programme (favourites, hiding, its guide).
  final void Function(Channel)? onLongPress;

  @override
  State<GuideGrid> createState() => GuideGridState();
}

class GuideGridState extends State<GuideGrid> {
  static const _span = Duration(hours: 2);
  static const _step = Duration(minutes: 30);
  static const _labelWidth = 240.0;
  static const _rowHeight = 64.0;

  late DateTime _from = _floorToStep(DateTime.now().toUtc());
  DateTime get _to => _from.add(_span);

  /// Guide rows for the current window, keyed by channel key.
  final _rows = <String, List<Programme>>{};

  /// Focus nodes keyed by channel key + programme start, kept across builds
  /// so focus survives window changes.
  final _nodes = <String, FocusNode>{};
  final _usedNodes = <String>{};

  ({Channel channel, Programme? programme})? _selected;

  /// After paging, the cell in this row covering this time takes focus.
  (int, DateTime)? _pendingFocus;
  int _focusedRow = 0;

  static DateTime _floorToStep(DateTime t) =>
      DateTime.utc(t.year, t.month, t.day, t.hour, t.minute < 30 ? 0 : 30);

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(GuideGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The guide may have changed (a sync, a channel's programmes asked of
    // its source): the visible rows load again, a few queries.
    _rows.clear();
    // Another group starts from the top.
    if (!identical(oldWidget.channels, widget.channels)) {
      _focusedRow = 0;
      _selected = null;
    }
  }

  /// Moves focus into the grid: [row]'s programme on now, back at the
  /// current time.
  void focusNow([int row = 0]) {
    final now = _floorToStep(DateTime.now().toUtc());
    if (_from != now) {
      setState(() {
        _from = now;
        _rows.clear();
        _pendingFocus = (row, DateTime.now().toUtc());
      });
      return;
    }
    _focusCellAt(row, DateTime.now().toUtc());
  }

  List<Programme> _row(Channel c) {
    final key = ZaplineDatabase.channelKey(c);
    return _rows[key] ??=
        widget.state.guide([c], _from, _to)[key] ?? const <Programme>[];
  }

  void _page(int steps, {required int row, required DateTime focusAt}) {
    final earliest = _floorToStep(
      DateTime.now().toUtc().subtract(const Duration(days: 1)),
    );
    final next = _from.add(_step * steps);
    if (next.isBefore(earliest)) return;
    setState(() {
      _from = next;
      _rows.clear();
      _pendingFocus = (row, focusAt);
    });
  }

  /// Pages without moving focus to a particular cell.
  void _pagePointer(int steps) =>
      _page(steps, row: _focusedRow, focusAt: _from.add(_step * steps));

  FocusNode _node(String key) {
    _usedNodes.add(key);
    return _nodes.putIfAbsent(key, () => FocusNode(debugLabel: key));
  }

  void _pruneNodes() {
    _nodes.removeWhere((k, n) {
      if (_usedNodes.contains(k)) return false;
      if (n.hasFocus) return false;
      n.dispose();
      return true;
    });
    _usedNodes.clear();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return KeyEventResult.ignored;
    final sel = _selected;
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (primary.focusInDirection(TraversalDirection.right)) {
        return KeyEventResult.handled;
      }
      _page(1, row: _focusedRow, focusAt: _to);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (primary.focusInDirection(TraversalDirection.left)) {
        return KeyEventResult.handled;
      }
      // Left past what's on now leaves the grid, unless the channel keeps
      // an archive to go back into; at the archive's start it leaves too.
      final exit = widget.onExitLeft;
      final archived = (sel?.channel.catchup?.days ?? 0) > 0;
      final earliest = _floorToStep(
        DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );
      final atNow = !_from.isAfter(_floorToStep(DateTime.now().toUtc()));
      final atStart = _from.subtract(_step).isBefore(earliest);
      if (exit != null && ((atNow && !archived) || atStart)) {
        exit();
        return KeyEventResult.handled;
      }
      final at = sel?.programme?.start ?? _from;
      _page(
        -1,
        row: _focusedRow,
        focusAt: at.subtract(const Duration(minutes: 1)),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Plays the channel live, or replays [programme] from the archive when it
  /// has already aired and the provider keeps it.
  void _play(int index, [Programme? programme]) {
    final c = widget.channels[index];
    final replay =
        programme != null &&
            programme.start.isBefore(DateTime.now().toUtc()) &&
            !programme.isAiringAt(DateTime.now().toUtc()) &&
            widget.state.catchupUrl(c, programme) != null
        ? programme
        : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          state: widget.state,
          channels: widget.channels,
          initialIndex: index,
          replay: replay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingFocus;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingFocus = null;
        _focusCellAt(pending.$1, pending.$2);
        _pruneNodes();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pruneNodes());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 128,
          child: _Details(selected: _selected, time: widget.state.time),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final pxPerMin = (box.maxWidth - _labelWidth) / _span.inMinutes;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      _Ruler(
                        caption: widget.caption,
                        time: widget.state.time,
                        from: _from,
                        span: _span,
                        step: _step,
                        labelWidth: _labelWidth,
                        pxPerMin: pxPerMin,
                      ),
                      // Mouse users page with these; the D-pad pages at
                      // the grid edges.
                      Positioned(
                        right: 0,
                        top: 0,
                        child: ListenableBuilder(
                          listenable: InputMode.instance,
                          builder: (context, _) => InputMode.instance.pointer
                              ? ExcludeFocus(
                                  child: Row(
                                    children: [
                                      IconButton(
                                        iconSize: 22,
                                        onPressed: () => _pagePointer(-1),
                                        icon: Icon(
                                          Icons.chevron_left_rounded,
                                          semanticLabel: context.l10n.earlier,
                                        ),
                                      ),
                                      IconButton(
                                        iconSize: 22,
                                        onPressed: () => _pagePointer(1),
                                        icon: Icon(
                                          Icons.chevron_right_rounded,
                                          semanticLabel: context.l10n.later,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Listener(
                          // Horizontal wheel or Shift+wheel moves in time.
                          onPointerSignal: (e) {
                            if (e is! PointerScrollEvent) return;
                            final dx = e.scrollDelta.dx != 0
                                ? e.scrollDelta.dx
                                : (HardwareKeyboard.instance.isShiftPressed
                                      ? e.scrollDelta.dy
                                      : 0.0);
                            if (dx != 0) _pagePointer(dx > 0 ? 1 : -1);
                          },
                          child: Focus(
                            canRequestFocus: false,
                            skipTraversal: true,
                            onKeyEvent: _onKey,
                            child: ListView.builder(
                              itemCount: widget.channels.length,
                              itemExtent: _rowHeight,
                              itemBuilder: (context, i) =>
                                  _buildRow(i, pxPerMin),
                            ),
                          ),
                        ),
                        _NowLine(
                          from: _from,
                          to: _to,
                          left: _labelWidth,
                          pxPerMin: pxPerMin,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRow(int i, double pxPerMin) {
    final c = widget.channels[i];
    final key = ZaplineDatabase.channelKey(c);
    final programmes = _row(c);
    final cells = <Widget>[];

    if (programmes.isEmpty) {
      cells.add(
        _cell(
          nodeKey: '$key|none',
          left: 0,
          width: _span.inMinutes * pxPerMin,
          label: context.l10n.noGuideInfo,
          dim: true,
          onFocus: () => _select(i, c, null),
          onPressed: () => _play(i),
          onLongPress: _longPress(c),
        ),
      );
    }
    for (final p in programmes) {
      final s = p.start.isBefore(_from) ? _from : p.start;
      final e = p.stop.isAfter(_to) ? _to : p.stop;
      final left = s.difference(_from).inMinutes * pxPerMin;
      final width = e.difference(s).inMinutes * pxPerMin;
      if (width < 4) continue;
      cells.add(
        _cell(
          nodeKey: '$key|${p.start.millisecondsSinceEpoch}',
          left: left,
          width: width,
          label: p.title,
          dim: p.stop.isBefore(DateTime.now().toUtc()),
          replayable:
              p.stop.isBefore(DateTime.now().toUtc()) && canReplay(c, p),
          onFocus: () => _select(i, c, p),
          onPressed: () => _play(i, p),
          onLongPress: _longPress(c),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Row(
              children: [
                ChannelLogo(channel: c, width: 52, height: 36),
                const SizedBox(width: 10),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${widget.state.channelNumber(c, i)}',
                    style: const TextStyle(
                      color: ZaplineColors.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.state.displayName(c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          Expanded(child: Stack(children: cells)),
        ],
      ),
    );
  }

  Widget _cell({
    required String nodeKey,
    required double left,
    required double width,
    required String label,
    required bool dim,
    bool replayable = false,
    required VoidCallback onFocus,
    required VoidCallback onPressed,
    VoidCallback? onLongPress,
  }) {
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: width - 4,
      child: FocusCard(
        focusNode: _node(nodeKey),
        radius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onFocused: onFocus,
        onPressed: onPressed,
        onLongPress: onLongPress,
        child: Row(
          children: [
            if (replayable) ...[
              const Icon(Icons.history, size: 18),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Dim past programmes unless they can still be watched.
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: dim && !replayable ? ZaplineColors.textMuted : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _longPress(Channel c) {
    final f = widget.onLongPress;
    return f == null ? null : () => f(c);
  }

  void _select(int row, Channel c, Programme? p) {
    _focusedRow = row;
    setState(() => _selected = (channel: c, programme: p));
  }

  void _focusCellAt(int row, DateTime at) {
    if (row >= widget.channels.length) return;
    final c = widget.channels[row];
    final key = ZaplineDatabase.channelKey(c);
    final programmes = _row(c);
    final p = programmes
        .where((p) => !at.isBefore(p.start) && at.isBefore(p.stop))
        .firstOrNull;
    final nodeKey = p == null
        ? (programmes.isEmpty
              ? '$key|none'
              : '$key|${(at.isBefore(_from) || !at.isBefore(_to) ? programmes.last : programmes.first).start.millisecondsSinceEpoch}')
        : '$key|${p.start.millisecondsSinceEpoch}';
    _nodes[nodeKey]?.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    if (!widget.autofocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCellAt(0, DateTime.now().toUtc());
    });
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.selected, required this.time});

  final ({Channel channel, Programme? programme})? selected;
  final String Function(DateTime) time;

  @override
  Widget build(BuildContext context) {
    final s = selected;
    if (s == null) return const SizedBox.shrink();
    final p = s.programme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p == null
              ? s.channel.name
              : '${s.channel.name} · ${time(p.start)}–${time(p.stop)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ZaplineColors.focus,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          p?.title ?? context.l10n.noGuideInfo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        if (p?.description != null) ...[
          const SizedBox(height: 6),
          Text(
            p!.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              color: ZaplineColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({
    this.caption,
    required this.time,
    required this.from,
    required this.span,
    required this.step,
    required this.labelWidth,
    required this.pxPerMin,
  });

  final String? caption;
  final String Function(DateTime) time;
  final DateTime from;
  final Duration span;
  final Duration step;
  final double labelWidth;
  final double pxPerMin;

  @override
  Widget build(BuildContext context) {
    final l = from.toLocal();
    final today = DateTime.now();
    final sameDay = l.day == today.day && l.month == today.month;
    final marks = <Widget>[];
    for (var t = from; t.isBefore(from.add(span)); t = t.add(step)) {
      marks.add(
        Positioned(
          left: t.difference(from).inMinutes * pxPerMin,
          top: 8,
          child: Text(
            time(t),
            style: const TextStyle(
              color: ZaplineColors.textMuted,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              [
                ?caption,
                sameDay ? context.l10n.today : '${l.day}/${l.month}',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: ZaplineColors.textMuted,
              ),
            ),
          ),
          Expanded(child: Stack(children: marks)),
        ],
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({
    required this.from,
    required this.to,
    required this.left,
    required this.pxPerMin,
  });

  final DateTime from;
  final DateTime to;
  final double left;
  final double pxPerMin;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    if (now.isBefore(from) || !now.isBefore(to)) return const SizedBox.shrink();
    return Positioned(
      left: left + now.difference(from).inMinutes * pxPerMin,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(width: 2, color: ZaplineColors.live),
      ),
    );
  }
}
