import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lineup_core/lineup_core.dart';
import 'package:lineup_data/lineup_data.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import '../widgets/focus_card.dart';
import 'player_screen.dart';

/// TV guide grid.
///
/// Shows a fixed two-hour window that pages by half an hour when the D-pad
/// reaches an edge, the way TV guides behave on a remote. Rows are built
/// lazily and each row loads only its own programmes for the visible window,
/// so the grid stays cheap with tens of thousands of channels.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.state, required this.channels});

  final AppState state;
  final List<Channel> channels;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  static const _span = Duration(hours: 2);
  static const _step = Duration(minutes: 30);
  static const _labelWidth = 260.0;
  static const _rowHeight = 68.0;

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

  List<Programme> _row(Channel c) {
    final key = LineupDatabase.channelKey(c);
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

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(48, 32, 48, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 150, child: _Details(selected: _selected)),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final pxPerMin =
                      (box.maxWidth - _labelWidth) / _span.inMinutes;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Ruler(
                        from: _from,
                        span: _span,
                        step: _step,
                        labelWidth: _labelWidth,
                        pxPerMin: pxPerMin,
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Focus(
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
        ),
      ),
    );
  }

  Widget _buildRow(int i, double pxPerMin) {
    final c = widget.channels[i];
    final key = LineupDatabase.channelKey(c);
    final programmes = _row(c);
    final cells = <Widget>[];

    if (programmes.isEmpty) {
      cells.add(
        _cell(
          nodeKey: '$key|none',
          left: 0,
          width: _span.inMinutes * pxPerMin,
          label: 'No guide information',
          dim: true,
          onFocus: () => _select(i, c, null),
          onPressed: () => _play(i),
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
                ChannelLogo(channel: c, width: 44, height: 32),
                const SizedBox(width: 10),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${c.number ?? i + 1}',
                    style: const TextStyle(
                      color: LineupColors.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    c.name,
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
                  color: dim && !replayable ? LineupColors.textMuted : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(int row, Channel c, Programme? p) {
    _focusedRow = row;
    setState(() => _selected = (channel: c, programme: p));
  }

  void _focusCellAt(int row, DateTime at) {
    if (row >= widget.channels.length) return;
    final c = widget.channels[row];
    final key = LineupDatabase.channelKey(c);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCellAt(0, DateTime.now().toUtc());
    });
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.selected});

  final ({Channel channel, Programme? programme})? selected;

  @override
  Widget build(BuildContext context) {
    final s = selected;
    if (s == null) return const SizedBox.shrink();
    final p = s.programme;
    String hm(DateTime t) {
      final l = t.toLocal();
      return '${l.hour.toString().padLeft(2, '0')}:'
          '${l.minute.toString().padLeft(2, '0')}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p == null
              ? s.channel.name
              : '${s.channel.name} · ${hm(p.start)}–${hm(p.stop)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: LineupColors.focus,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          p?.title ?? 'No guide information',
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
              color: LineupColors.textMuted,
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
    required this.from,
    required this.span,
    required this.step,
    required this.labelWidth,
    required this.pxPerMin,
  });

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
      final lt = t.toLocal();
      marks.add(
        Positioned(
          left: t.difference(from).inMinutes * pxPerMin,
          top: 8,
          child: Text(
            '${lt.hour.toString().padLeft(2, '0')}:'
            '${lt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: LineupColors.textMuted,
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
              sameDay ? 'Today' : '${l.day}/${l.month}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: LineupColors.textMuted,
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
        child: Container(width: 2, color: LineupColors.live),
      ),
    );
  }
}
