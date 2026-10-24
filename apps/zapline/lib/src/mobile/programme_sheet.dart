import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import 'mobile_home.dart';

/// Details of one programme with what can be done with it: watch it live,
/// from the start or from the archive, or be reminded when it starts.
Future<void> showProgrammeSheet(
  BuildContext context, {
  required AppState state,
  required List<Channel> channels,
  required int index,
  required Programme programme,
  void Function(Programme? replay)? onPlay,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => _ProgrammeSheet(
    state: state,
    channels: channels,
    index: index,
    programme: programme,
    onPlay: onPlay,
  ),
);

class _ProgrammeSheet extends StatefulWidget {
  const _ProgrammeSheet({
    required this.state,
    required this.channels,
    required this.index,
    required this.programme,
    this.onPlay,
  });

  /// From inside the player: play here instead of opening another player.
  final void Function(Programme? replay)? onPlay;

  final AppState state;
  final List<Channel> channels;
  final int index;
  final Programme programme;

  @override
  State<_ProgrammeSheet> createState() => _ProgrammeSheetState();
}

class _ProgrammeSheetState extends State<_ProgrammeSheet> {
  Channel get _channel => widget.channels[widget.index];

  void _play({Programme? replay}) {
    Navigator.of(context).pop();
    if (widget.onPlay case final play?) return play(replay);
    openPlayer(
      context,
      widget.state,
      widget.channels,
      widget.index,
      replay: replay,
    );
  }

  /// "TODAY 21:20", "TOMORROW 06:00", "MON 27 21:20".
  String _when(Programme p) {
    final l = context.l10n;
    final start = p.start.toLocal();
    final now = DateTime.now();
    final days = DateTime(
      start.year,
      start.month,
      start.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final day = switch (days) {
      0 => l.today,
      1 => l.tomorrow,
      -1 => l.yesterday,
      _ => DateFormat.MMMEd(
        Localizations.localeOf(context).toString(),
      ).format(start),
    };
    return '$day ${widget.state.time(p.start)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = widget.state;
    final p = widget.programme;
    final c = _channel;
    final now = DateTime.now();
    final onAir = !p.start.isAfter(now) && p.stop.isAfter(now);
    final past = !p.stop.isAfter(now);
    final archived = state.catchupUrl(c, p) != null;
    final next = state
        .schedule(c, p.stop, p.stop.add(const Duration(hours: 6)))
        .where((e) => !e.start.isBefore(p.stop))
        .firstOrNull;
    final reminded = state.hasReminder(c, p);

    final (badge, badgeColor) = onAir
        ? (l.onNow, ZaplineColors.live)
        : past
        ? (archived ? l.replay : _when(p).toUpperCase(), ZaplineColors.focus)
        : (_when(p).toUpperCase(), ZaplineColors.focus);

    // Primary action first; the channel is always one tap away.
    final actions = <(IconData, String, VoidCallback, bool)>[
      if (onAir) (Icons.play_arrow_rounded, l.watch, () => _play(), true),
      if (onAir && archived)
        (Icons.replay_rounded, l.fromTheStart, () => _play(replay: p), false),
      if (past && archived)
        (Icons.replay_rounded, l.replayAction, () => _play(replay: p), true),
      if (!past && !onAir)
        (
          reminded
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          reminded ? l.reminderSet : l.remindMe,
          () => setState(() => state.toggleReminder(c, p)),
          true,
        ),
      if (!onAir) (Icons.live_tv_rounded, l.watchChannel, () => _play(), false),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChannelLogo(channel: c, width: 52, height: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.displayName(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ZaplineColors.textMuted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ZaplineColors.onFocus,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            p.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            [
              '${state.time(p.start)}–${state.time(p.stop)}',
              ?p.category,
              ?p.episode,
            ].join('  ·  '),
            style: const TextStyle(color: ZaplineColors.textMuted),
          ),
          if (onAir) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value:
                    (now.difference(p.start).inSeconds /
                            p.stop.difference(p.start).inSeconds)
                        .clamp(0.0, 1.0),
                minHeight: 4,
                color: ZaplineColors.focus,
                backgroundColor: ZaplineColors.line,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.timeLeft(p.stop.difference(now)),
              style: const TextStyle(
                fontSize: 13,
                color: ZaplineColors.textMuted,
              ),
            ),
          ],
          if (p.description case final d? when d.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              d,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xFFC9D2DE),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (icon, label, onTap, primary) in actions)
                primary
                    ? FilledButton.icon(
                        onPressed: onTap,
                        icon: Icon(icon),
                        label: Text(label),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: onTap,
                        icon: Icon(icon),
                        label: Text(label),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          foregroundColor: ZaplineColors.text,
                          side: const BorderSide(color: ZaplineColors.line),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: ZaplineColors.line),
            const SizedBox(height: 12),
            Text(
              l.nextAt(state.time(next.start), next.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: ZaplineColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
