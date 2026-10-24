import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../channel_groups.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import 'mobile_home.dart';
import 'mobile_widgets.dart';

/// The guide on a phone: what's on at a chosen time on every channel of a
/// group, one row each. A grid needs a TV-sized screen; here a tap opens the
/// channel's own schedule instead.
class MobileGuide extends StatefulWidget {
  const MobileGuide({super.key, required this.state});

  final AppState state;

  @override
  State<MobileGuide> createState() => _MobileGuideState();
}

class _MobileGuideState extends State<MobileGuide> {
  String? _group;

  /// `null` means now.
  DateTime? _at;
  final _cache = ChannelListCache();

  DateTime get _tonight {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 21);
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at ?? now),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(alwaysUse24HourFormat: widget.state.settings.clock24h),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(
      () => _at = DateTime(now.year, now.month, now.day, t.hour, t.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        if (!groupsOf(state).contains(_group)) _group = null;
        final locked = _group != null && state.isLocked(_group!);
        final list = locked ? const <Channel>[] : _cache.get(state, _group);
        final at = _at;
        final tonight = _tonight;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileHeader(state: state, title: context.l10n.tvGuide),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _TimeChip(
                    label: context.l10n.now,
                    selected: at == null,
                    onTap: () => setState(() => _at = null),
                  ),
                  if (DateTime.now().isBefore(tonight))
                    _TimeChip(
                      label: context.l10n.tonightAt(
                        state.time(tonight.toUtc()),
                      ),
                      selected: at == tonight,
                      onTap: () => setState(() => _at = tonight),
                    ),
                  _TimeChip(
                    label: at == null || at == tonight
                        ? context.l10n.pickTime
                        : context.l10n.atTime(state.time(at.toUtc())),
                    icon: Icons.schedule_rounded,
                    selected: at != null && at != tonight,
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
            GroupBar(
              state: state,
              selected: _group,
              onSelected: (g) => setState(() => _group = g),
            ),
            const Divider(height: 1, color: ZaplineColors.line),
            Expanded(
              child: locked
                  ? LockedGroupView(state: state)
                  : list.isEmpty
                  ? EmptyView(context.l10n.noChannelsInGroup)
                  : ListView.builder(
                      itemCount: list.length,
                      itemExtent: 92,
                      itemBuilder: (context, i) => _WhatsOnRow(
                        state: state,
                        channel: list[i],
                        at: (at ?? DateTime.now()).toUtc(),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChannelScheduleScreen(
                              state: state,
                              channels: list,
                              index: i,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
    child: Material(
      color: selected ? ZaplineColors.focus : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? ZaplineColors.focus : ZaplineColors.line,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? ZaplineColors.onFocus : ZaplineColors.text,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? ZaplineColors.onFocus : ZaplineColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// What's on [channel] at [at], and what comes after.
class _WhatsOnRow extends StatelessWidget {
  const _WhatsOnRow({
    required this.state,
    required this.channel,
    required this.at,
    required this.onTap,
  });

  final AppState state;
  final Channel channel;
  final DateTime at;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final programmes = state.schedule(
      channel,
      at,
      at.add(const Duration(hours: 6)),
    );
    final current = programmes
        .where((p) => !p.start.isAfter(at) && p.stop.isAfter(at))
        .firstOrNull;
    final next = programmes.where((p) => p.start.isAfter(at)).firstOrNull;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChannelLogo(channel: channel, width: 56, height: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ZaplineColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    current?.title ?? context.l10n.noGuideAtTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: current == null
                          ? ZaplineColors.textMuted
                          : ZaplineColors.text,
                    ),
                  ),
                  Text(
                    [
                      if (current != null)
                        '${state.time(current.start)}–'
                            '${state.time(current.stop)}',
                      if (next != null)
                        context.l10n.thenAt(state.time(next.start), next.title),
                    ].join('  ·  '),
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
            const Icon(
              Icons.chevron_right_rounded,
              color: ZaplineColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// One channel's programmes, day by day. Tapping a programme plays it live
/// when it's on, replays it when it's in the archive, otherwise shows its
/// details.
class ChannelScheduleScreen extends StatefulWidget {
  const ChannelScheduleScreen({
    super.key,
    required this.state,
    required this.channels,
    required this.index,
  });

  final AppState state;
  final List<Channel> channels;
  final int index;

  @override
  State<ChannelScheduleScreen> createState() => _ChannelScheduleScreenState();
}

class _ChannelScheduleScreenState extends State<ChannelScheduleScreen> {
  static const _rowHeight = 76.0;

  Channel get _channel => widget.channels[widget.index];

  late final Map<DateTime, List<Programme>> _days = _load();
  late DateTime _day = _initialDay();
  final _scroll = ScrollController();

  static DateTime _dateOf(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  Map<DateTime, List<Programme>> _load() {
    final today = _dateOf(DateTime.now());
    final all = widget.state.schedule(
      _channel,
      today.subtract(const Duration(days: 7)).toUtc(),
      today.add(const Duration(days: 15)).toUtc(),
    );
    final days = <DateTime, List<Programme>>{};
    for (final p in all) {
      (days[_dateOf(p.start)] ??= []).add(p);
    }
    return days;
  }

  DateTime _initialDay() {
    final today = _dateOf(DateTime.now());
    if (_days.containsKey(today) || _days.isEmpty) return today;
    return _days.keys.first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToNow() {
    final list = _days[_day];
    if (list == null || !_scroll.hasClients) return;
    final now = DateTime.now();
    final i = list.indexWhere((p) => p.stop.isAfter(now));
    if (i <= 0) return;
    _scroll.jumpTo(
      ((i - 1) * _rowHeight).clamp(0, _scroll.position.maxScrollExtent),
    );
  }

  String _dayLabel(DateTime d) {
    final today = _dateOf(DateTime.now());
    final diff = d.difference(today).inDays;
    final l = context.l10n;
    if (diff == 0) return l.today;
    if (diff == -1) return l.yesterday;
    if (diff == 1) return l.tomorrow;
    // "Mon 27" / "lun 27" in the app's language.
    return DateFormat.MEd(Localizations.localeOf(context).toString())
        .format(d)
        .replaceAll(RegExp(r'[/.]\d+$'), '');
  }

  void _open(Programme p) {
    final now = DateTime.now();
    final onAir = !p.start.isAfter(now) && p.stop.isAfter(now);
    final replay =
        !onAir &&
        !p.stop.isAfter(now) &&
        widget.state.catchupUrl(_channel, p) != null;
    if (onAir || replay) {
      openPlayer(
        context,
        widget.state,
        widget.channels,
        widget.index,
        replay: replay ? p : null,
      );
    } else {
      _details(p);
    }
  }

  void _details(Programme p) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${_dayLabel(_dateOf(p.start))}  ·  '
            '${widget.state.time(p.start)}–${widget.state.time(p.stop)}'
            '${p.category == null ? '' : '  ·  ${p.category}'}',
            style: const TextStyle(color: ZaplineColors.textMuted),
          ),
          if (p.description case final d? when d.isNotEmpty) ...[
            const SizedBox(height: 12),
            Flexible(child: SingleChildScrollView(child: Text(d))),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final days = _days.keys.toList()..sort();
    final list = _days[_day] ?? const <Programme>[];
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ChannelLogo(channel: _channel, width: 44, height: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.watchLive,
            onPressed: () =>
                openPlayer(context, state, widget.channels, widget.index),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 32),
            color: ZaplineColors.focus,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (days.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final d in days)
                    _TimeChip(
                      label: _dayLabel(d),
                      selected: d == _day,
                      onTap: () {
                        setState(() => _day = d);
                        if (_scroll.hasClients) _scroll.jumpTo(0);
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _scrollToNow(),
                        );
                      },
                    ),
                ],
              ),
            ),
          const Divider(height: 1, color: ZaplineColors.line),
          Expanded(
            child: list.isEmpty
                ? EmptyView(
                    context.l10n.noGuideForChannel,
                    icon: Icons.event_busy_outlined,
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: list.length,
                    itemExtent: _rowHeight,
                    itemBuilder: (context, i) {
                      final p = list[i];
                      final onAir =
                          !p.start.isAfter(now) && p.stop.isAfter(now);
                      final past = !p.stop.isAfter(now);
                      final replay =
                          past && state.catchupUrl(_channel, p) != null;
                      return InkWell(
                        onTap: () => _open(p),
                        onLongPress: () => _details(p),
                        child: Container(
                          color: onAir
                              ? ZaplineColors.surfaceHigh
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                  state.time(p.start),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: past && !onAir
                                        ? ZaplineColors.textMuted
                                        : ZaplineColors.text,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: past && !onAir && !replay
                                            ? ZaplineColors.textMuted
                                            : ZaplineColors.text,
                                      ),
                                    ),
                                    if (p.description case final d?
                                        when d.isNotEmpty)
                                      Text(
                                        d,
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
                              if (onAir)
                                _Badge(context.l10n.onNow, ZaplineColors.live)
                              else if (replay)
                                const Icon(
                                  Icons.replay_rounded,
                                  color: ZaplineColors.focus,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: ZaplineColors.onFocus,
      ),
    ),
  );
}
