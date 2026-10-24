import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../layout.dart';
import '../mobile/mobile_widgets.dart';
import '../theme.dart';
import '../widgets/channel_actions.dart';
import '../widgets/channel_logo.dart';
import '../widgets/channel_tile.dart';
import '../widgets/focus_card.dart';
import '../widgets/tv_text_field.dart';
import 'player_screen.dart';

/// Search across all sources: channels (prefix matching, accent-insensitive)
/// and then programmes in the TV guide, results as you type.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Channel> _results = const [];
  List<(Channel, Programme)> _programmes = const [];

  @override
  void initState() {
    super.initState();
    _query.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), _run);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _run() {
    if (!mounted) return;
    final q = _query.text;
    setState(() {
      _results = widget.state.search(q);
      // Titles are matched anywhere in the text, so wait for a few letters.
      _programmes = q.trim().length < 3
          ? const []
          : _byRelevance(widget.state.searchProgrammes(q));
    });
  }

  /// On now first, then coming up, then already aired (most recent first).
  static List<(Channel, Programme)> _byRelevance(
    List<(Channel, Programme)> found,
  ) {
    final now = DateTime.now();
    int rank((Channel, Programme) e) {
      final p = e.$2;
      if (!p.start.isAfter(now) && p.stop.isAfter(now)) return 0;
      return p.start.isAfter(now) ? 1 : 2;
    }

    return [...found]..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final byStart = a.$2.start.compareTo(b.$2.start);
      return rank(a) == 2 ? -byStart : byStart;
    });
  }

  void _play(List<Channel> channels, int i, {Programme? replay}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(
            state: widget.state,
            channels: channels,
            initialIndex: i,
            replay: replay,
          ),
        ),
      );

  /// On air: watch live. Over and in the archive: replay it. Otherwise
  /// the channel, live.
  void _openProgramme(Channel c, Programme p) {
    final now = DateTime.now();
    final past = !p.stop.isAfter(now);
    final replayable = past && widget.state.catchupUrl(c, p) != null;
    _play([c], 0, replay: replayable ? p : null);
  }

  @override
  Widget build(BuildContext context) {
    final empty =
        _query.text.trim().isNotEmpty &&
        _results.isEmpty &&
        _programmes.isEmpty;
    final phone = context.isPhone;
    final items = <Widget Function()>[
      for (var i = 0; i < _results.length; i++)
        if (phone)
          () => SizedBox(
            height: MobileChannelRow.height,
            child: MobileChannelRow(
              state: widget.state,
              channel: _results[i],
              number: widget.state.channelNumber(_results[i], i),
              onTap: () => _play(_results, i),
              onLongPress: () =>
                  showChannelActions(context, widget.state, _results[i]),
            ),
          )
        else
          () => SizedBox(
            height: 86,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChannelTile(
                state: widget.state,
                channel: _results[i],
                number: widget.state.channelNumber(_results[i], i),
                onPressed: () => _play(_results, i),
                onLongPress: () =>
                    showChannelActions(context, widget.state, _results[i]),
              ),
            ),
          ),
      if (_programmes.isNotEmpty)
        () => Padding(
          padding: phone
              ? const EdgeInsets.fromLTRB(16, 16, 16, 4)
              : const EdgeInsets.fromLTRB(4, 16, 0, 12),
          child: Text(
            context.l10n.inTheTvGuide,
            style: TextStyle(
              fontSize: Metrics.of(context).section,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      for (final (c, p) in _programmes)
        if (phone)
          () => _PhoneProgrammeRow(
            state: widget.state,
            channel: c,
            programme: p,
            onTap: () => _openProgramme(c, p),
          )
        else
          () => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ProgrammeRow(
              state: widget.state,
              channel: c,
              programme: p,
              onPressed: () => _openProgramme(c, p),
            ),
          ),
    ];

    final m = Metrics.of(context);
    return Scaffold(
      body: Padding(
        padding: phone
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(64, 40, 64, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: phone
                  ? const EdgeInsets.fromLTRB(20, 12, 20, 0)
                  : EdgeInsets.zero,
              child: Text(
                context.l10n.search,
                style: TextStyle(
                  fontSize: phone ? 24 : 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(height: m.gap * 1.5),
            Padding(
              padding: phone
                  ? const EdgeInsets.symmetric(horizontal: 16)
                  : EdgeInsets.zero,
              child: TvTextField(
                builder: (readOnly) => TextField(
                  readOnly: readOnly,
                  controller: _query,
                  autofocus: !context.isPhone,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _run(),
                  decoration: InputDecoration(
                    labelText: context.l10n.channelOrProgramme,
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            SizedBox(height: m.gap),
            if (empty)
              Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  context.l10n.nothingFound,
                  style: TextStyle(color: ZaplineColors.textMuted),
                ),
              ),
            Expanded(
              // Rebuild on favourite changes so the stars stay current.
              child: ListenableBuilder(
                listenable: widget.state,
                builder: (context, _) => ListView.builder(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: items.length,
                  itemBuilder: (context, i) => items[i](),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgrammeRow extends StatelessWidget {
  const _ProgrammeRow({
    required this.state,
    required this.channel,
    required this.programme,
    required this.onPressed,
  });

  final AppState state;
  final Channel channel;
  final Programme programme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = programme;
    final now = DateTime.now();
    final onAir = !p.start.isAfter(now) && p.stop.isAfter(now);
    final replay = !p.stop.isAfter(now) && state.catchupUrl(channel, p) != null;
    final start = p.start.toLocal();
    final today = DateUtils.isSameDay(start, now);
    return FocusCard(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          ChannelLogo(channel: channel),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${channel.name}  ·  '
                  '${today ? '' : '${start.day}/${start.month} '}'
                  '${state.time(p.start)}–${state.time(p.stop)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ZaplineColors.textMuted),
                ),
              ],
            ),
          ),
          if (onAir || replay)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: onAir ? ZaplineColors.live : ZaplineColors.focus,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                onAir ? context.l10n.onNow : context.l10n.replay,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ZaplineColors.onFocus,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A programme found by search, as a plain phone list row.
class _PhoneProgrammeRow extends StatelessWidget {
  const _PhoneProgrammeRow({
    required this.state,
    required this.channel,
    required this.programme,
    required this.onTap,
  });

  final AppState state;
  final Channel channel;
  final Programme programme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = programme;
    final now = DateTime.now();
    final onAir = !p.start.isAfter(now) && p.stop.isAfter(now);
    final replay = !p.stop.isAfter(now) && state.catchupUrl(channel, p) != null;
    final start = p.start.toLocal();
    final today = DateUtils.isSameDay(start, now);
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${today ? '' : '${start.day}/${start.month} '}'
                    '${state.time(p.start)}  ·  ${channel.name}',
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
              const Icon(Icons.live_tv_rounded, color: ZaplineColors.live)
            else if (replay)
              const Icon(Icons.replay_rounded, color: ZaplineColors.focus),
          ],
        ),
      ),
    );
  }
}
