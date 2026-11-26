import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:intl/intl.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../input_mode.dart';
import '../mobile/programme_sheet.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import '../widgets/focus_card.dart';
import 'player_screen.dart';
import '../layout.dart';

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

  /// A row, taller with large system text.
  double get _rowExtent => scaledExtent(context, _rowHeight);

  late DateTime _from = _floorToStep(DateTime.now().toUtc());
  DateTime get _to => _from.add(_span);

  /// Guide rows for the current window, keyed by channel key.
  final _rows = <String, List<Programme>>{};

  /// Focus nodes keyed by channel key + programme start, kept across builds
  /// so focus survives window changes.
  final _nodes = <String, FocusNode>{};
  final _usedNodes = <String>{};

  /// The focused cell: only the details above the grid follow it, so moving
  /// around doesn't rebuild every row.
  final _selected = ValueNotifier<({Channel channel, Programme? programme})?>(
    null,
  );

  final _scroll = ScrollController();

  /// After paging, the cell in this row covering this time takes focus.
  (int, DateTime)? _pendingFocus;
  int _focusedRow = 0;

  /// Digits typed to jump to a channel number.
  String _digits = '';
  Timer? _digitTimer;

  static DateTime _floorToStep(DateTime t) =>
      DateTime.utc(t.year, t.month, t.day, t.hour, t.minute < 30 ? 0 : 30);

  @override
  void initState() {
    super.initState();
    widget.state.guideVersion.addListener(_guideChanged);
    if (!widget.autofocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCellAt(0, DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    widget.state.guideVersion.removeListener(_guideChanged);
    _digitTimer?.cancel();
    for (final n in _nodes.values) {
      n.dispose();
    }
    _selected.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Programmes arrived or guide links changed: the visible rows load
  /// again, a few queries.
  void _guideChanged() {
    if (mounted) setState(_rows.clear);
  }

  @override
  void didUpdateWidget(GuideGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.channels, widget.channels)) {
      // Other channels (another group, or the list changed): their rows
      // load as they show. Another group starts from the top.
      _rows.clear();
      _earliest = null;
      if (oldWidget.caption != widget.caption) {
        _focusedRow = 0;
        _selected.value = null;
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    }
  }

  /// Whether the grid shows what's on now.
  bool get atNow => _from == _floorToStep(DateTime.now().toUtc());

  /// Moves focus into the grid: what's on now on [row], by default the row
  /// focus was last on.
  void focusNow([int? row]) {
    row ??= _focusedRow;
    final now = _floorToStep(DateTime.now().toUtc());
    if (_from != now) {
      setState(() {
        _from = now;
        _rows.clear();
        _pendingFocus = (row!, DateTime.now().toUtc());
      });
      return;
    }
    _focusCellAt(row, DateTime.now().toUtc());
  }

  /// Focuses [c]'s row, if it is in the grid (back from the player, on
  /// the channel zapped to).
  void focusChannel(Channel c) {
    final i = widget.state.indexOfChannel(widget.channels, c);
    if (i >= 0) focusNow(i);
  }

  /// Row [i]'s programmes in the window. Rows not loaded yet around it
  /// load in one query: a page of new rows costs one, not one each.
  List<Programme> _row(int i) {
    final list = widget.channels;
    final key = ZaplineDatabase.channelKey(list[i]);
    final cached = _rows[key];
    if (cached != null) return cached;
    final batch = [
      for (
        var j = (i - 8).clamp(0, list.length);
        j < list.length && j < i + 24;
        j++
      )
        if (!_rows.containsKey(ZaplineDatabase.channelKey(list[j]))) list[j],
    ];
    final found = widget.state.guideRows(batch, _from, _to);
    for (final c in batch) {
      final k = ZaplineDatabase.channelKey(c);
      _rows[k] = found[k] ?? const <Programme>[];
    }
    return _rows[key]!;
  }

  DateTime? _earliest;

  /// How far back the grid goes: as far as the channels keep an archive
  /// (a week at most), and at least a day.
  DateTime get _earliestFrom {
    final cached = _earliest;
    if (cached != null) return cached;
    var days = 1;
    for (final c in widget.channels) {
      final d = c.catchup?.days ?? 0;
      if (d > days) days = d > 7 ? 7 : d;
      if (days == 7) break;
    }
    return _earliest = _floorToStep(
      DateTime.now().toUtc().subtract(Duration(days: days)),
    );
  }

  void _page(int steps, {required int row, required DateTime focusAt}) {
    var next = _from.add(_step * steps);
    if (next.isBefore(_earliestFrom)) {
      if (!_from.isAfter(_earliestFrom)) return;
      next = _earliestFrom;
    }
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

  /// Rows that fit on screen, for Page Up/Down.
  int get _pageRows {
    final h = _scroll.hasClients ? _scroll.position.viewportDimension : 0.0;
    return h <= 0 ? 8 : (h / _rowExtent).floor().clamp(1, 50);
  }

  /// Moves focus [rows] rows up or down, at the time focus is on.
  void _moveRows(int rows) {
    final n = widget.channels.length;
    if (n == 0) return;
    final target = (_focusedRow + rows).clamp(0, n - 1);
    if (target == _focusedRow) return;
    final p = _selected.value?.programme;
    final at = p == null
        ? (atNow ? DateTime.now().toUtc() : _from)
        : (p.start.isBefore(_from) ? _from : p.start);
    _focusCellAt(target, at);
  }

  static final _digitKeys = {
    for (var i = 0; i <= 9; i++) ...{
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + i): '$i',
      LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + i): '$i',
    },
  };

  void _typeDigit(String d) {
    _digitTimer?.cancel();
    if (_digits.length < 4) setState(() => _digits += d);
    _digitTimer = Timer(const Duration(milliseconds: 1200), _applyDigits);
  }

  void _applyDigits() {
    _digitTimer?.cancel();
    final n = int.tryParse(_digits);
    setState(() => _digits = '');
    if (n == null) return;
    final list = widget.channels;
    for (var i = 0; i < list.length; i++) {
      if (widget.state.channelNumber(list[i], i) == n) {
        return _focusCellAt(i, atNow ? DateTime.now().toUtc() : _from);
      }
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return KeyEventResult.ignored;
    final sel = _selected.value;
    final k = e.logicalKey;
    if (_digitKeys[k] case final d? when e is KeyDownEvent) {
      _typeDigit(d);
      return KeyEventResult.handled;
    }
    if (_digits.isNotEmpty &&
        (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter)) {
      _applyDigits();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.pageDown ||
        k == LogicalKeyboardKey.channelDown) {
      _moveRows(_pageRows - 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.pageUp || k == LogicalKeyboardKey.channelUp) {
      _moveRows(-(_pageRows - 1));
      return KeyEventResult.handled;
    }
    // Fast-forward and rewind move a whole window: tonight is a few
    // presses away, not twenty.
    if (k == LogicalKeyboardKey.mediaFastForward) {
      _page(_span.inMinutes ~/ _step.inMinutes, row: _focusedRow, focusAt: _to);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaRewind) {
      _page(
        -(_span.inMinutes ~/ _step.inMinutes),
        row: _focusedRow,
        focusAt: _from.subtract(_span),
      );
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      if (primary.focusInDirection(TraversalDirection.right)) {
        return KeyEventResult.handled;
      }
      _page(1, row: _focusedRow, focusAt: _to);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      if (primary.focusInDirection(TraversalDirection.left)) {
        return KeyEventResult.handled;
      }
      // Left past what's on now leaves the grid, unless the channel keeps
      // an archive to go back into; at the archive's start it leaves too.
      final exit = widget.onExitLeft;
      final archived = (sel?.channel.catchup?.days ?? 0) > 0;
      final atNow = !_from.isAfter(_floorToStep(DateTime.now().toUtc()));
      final atStart = !_from.isAfter(_earliestFrom);
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
  /// has already aired and the provider keeps it. A programme still to
  /// come opens its details, where it can be set as a reminder.
  void _play(int index, [Programme? programme]) {
    final c = widget.channels[index];
    final now = DateTime.now().toUtc();
    if (programme != null && programme.start.isAfter(now)) {
      showProgrammeSheet(
        context,
        state: widget.state,
        channels: widget.channels,
        index: index,
        programme: programme,
      );
      return;
    }
    final replay =
        programme != null &&
            programme.start.isBefore(now) &&
            !programme.isAiringAt(now) &&
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

    // A soft light behind the programme in focus, as TV launchers have:
    // drawn once, it costs nothing as the focus moves.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          top: -160,
          right: -120,
          width: 820,
          height: 520,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0x7A2B4A7A),
                    Color(0x4D6A3D6E),
                    Color(0x00000000),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
        _guideColumn(),
      ],
    );
  }

  Widget _guideColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 150,
          child: ValueListenableBuilder(
            valueListenable: _selected,
            builder: (context, selected, _) =>
                _Details(selected: selected, state: widget.state),
          ),
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
                                      if (!atNow)
                                        TextButton(
                                          onPressed: focusNow,
                                          child: Text(context.l10n.now),
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
                              controller: _scroll,
                              itemCount: widget.channels.length,
                              itemExtent: _rowExtent,
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
                        if (_digits.isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _DigitBadge(
                              digits: _digits,
                              name: _numbered(int.tryParse(_digits)),
                            ),
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

  /// The name of the channel numbered [n] in the grid, if any.
  String? _numbered(int? n) {
    if (n == null) return null;
    final list = widget.channels;
    for (var i = 0; i < list.length; i++) {
      if (widget.state.channelNumber(list[i], i) == n) {
        return widget.state.displayName(list[i]);
      }
    }
    return null;
  }

  Widget _buildRow(int i, double pxPerMin) {
    final c = widget.channels[i];
    final key = ZaplineDatabase.channelKey(c);
    final programmes = _row(i);
    final cells = <Widget>[];
    final now = DateTime.now().toUtc();

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
      final past = p.stop.isBefore(now);
      cells.add(
        _cell(
          nodeKey: '$key|${p.start.millisecondsSinceEpoch}',
          left: left,
          width: width,
          label: p.title,
          time: '${widget.state.time(p.start)}–${widget.state.time(p.stop)}',
          onAir: !past && !now.isBefore(p.start)
              ? now.difference(p.start).inSeconds /
                    p.stop.difference(p.start).inSeconds
              : null,
          dim: past,
          replayable: past && canReplay(c, p),
          reminder: p.start.isAfter(now) && widget.state.hasReminder(c, p),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.state.isFavourite(c))
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: ZaplineColors.accent,
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
    String? time,
    double? onAir,
    required bool dim,
    bool replayable = false,
    bool reminder = false,
    required VoidCallback onFocus,
    required VoidCallback onPressed,
    VoidCallback? onLongPress,
  }) {
    final icon = replayable
        ? Icons.history
        : reminder
        ? Icons.notifications_active_rounded
        : null;
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: width - 4,
      // What's on now stands out a little.
      child: FocusCard(
        focusNode: _node(nodeKey),
        radius: 10,
        selected: onAir != null,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onFocused: onFocus,
        onPressed: onPressed,
        onLongPress: onLongPress,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Dim past programmes unless they can still be
                        // watched.
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: dim && !replayable
                              ? ZaplineColors.textMuted
                              : null,
                        ),
                      ),
                      // The times, where there is room for them.
                      if (time != null && width > 150)
                        Opacity(
                          opacity: 0.6,
                          child: Text(
                            time,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
    _selected.value = (channel: c, programme: p);
  }

  /// Focuses [row]'s cell covering [at]; a row scrolled away is brought
  /// into view first, its cells exist only once it is built.
  void _focusCellAt(int row, DateTime at, {bool retried = false}) {
    if (row >= widget.channels.length) return;
    final c = widget.channels[row];
    final key = ZaplineDatabase.channelKey(c);
    final programmes = _row(row);
    final p = programmes
        .where((p) => !at.isBefore(p.start) && at.isBefore(p.stop))
        .firstOrNull;
    final nodeKey = p == null
        ? (programmes.isEmpty
              ? '$key|none'
              : '$key|${(at.isBefore(_from) || !at.isBefore(_to) ? programmes.last : programmes.first).start.millisecondsSinceEpoch}')
        : '$key|${p.start.millisecondsSinceEpoch}';
    final node = _nodes[nodeKey];
    // A node outlives its row: scrolled away, the row is gone.
    if (node != null && (node.context?.mounted ?? false)) {
      node.requestFocus();
      return;
    }
    if (retried || !_scroll.hasClients) return;
    final pos = _scroll.position;
    // A third of the way down, so the rows around it show too.
    pos.jumpTo(
      (row * _rowExtent - pos.viewportDimension / 3).clamp(
        0.0,
        pos.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCellAt(row, at, retried: true);
    });
  }
}

/// The number typed on the remote and the channel it jumps to.
class _DigitBadge extends StatelessWidget {
  const _DigitBadge({required this.digits, required this.name});

  final String digits;
  final String? name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
    decoration: BoxDecoration(
      color: ZaplineColors.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ZaplineColors.accent, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          digits,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            color: ZaplineColors.accent,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (name != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              name!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.selected, required this.state});

  final ({Channel channel, Programme? programme})? selected;
  final AppState state;

  String time(DateTime t) => state.time(t);

  @override
  Widget build(BuildContext context) {
    final s = selected;
    if (s == null) return const SizedBox.shrink();
    final p = s.programme;
    final description = p == null ? null : state.programmeDescription(p);
    final now = DateTime.now().toUtc();
    final airing = p != null && !now.isBefore(p.start) && now.isBefore(p.stop);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (p == null
                  ? state.displayName(s.channel)
                  : '${state.displayName(s.channel)} · ${_day(context, p.start)}'
                        '${time(p.start)}–${time(p.stop)}')
              .toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
            color: ZaplineColors.accent,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          p?.title ?? context.l10n.noGuideInfo,
          // The full title for screen readers too.
          semanticsLabel: p?.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 40,
            height: 1.15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        // How far into what's on now.
        if (airing)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: SizedBox(
              width: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value:
                      now.difference(p.start).inSeconds /
                      p.stop.difference(p.start).inSeconds,
                  minHeight: 4,
                  color: ZaplineColors.accent,
                  backgroundColor: ZaplineColors.line,
                ),
              ),
            ),
          ),
        if (description != null) ...[
          const SizedBox(height: 6),
          Text(
            description,
            maxLines: airing ? 1 : 2,
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

/// "Tomorrow " or "Fri 28 " before a programme's time when it isn't today.
String _day(BuildContext context, DateTime t) {
  final l = t.toLocal(), now = DateTime.now();
  final days = DateTime(
    l.year,
    l.month,
    l.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  return switch (days) {
    0 => '',
    1 => '${context.l10n.tomorrow} ',
    -1 => '${context.l10n.yesterday} ',
    _ =>
      '${DateFormat.MMMEd(Localizations.localeOf(context).toString()).format(l)} ',
  };
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
                fontWeight: FontWeight.w500,
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
        child: Container(width: 2, color: ZaplineColors.accent),
      ),
    );
  }
}
