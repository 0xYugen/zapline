import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
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
          : widget.state.searchProgrammes(q);
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
    final items = <Widget Function()>[
      for (var i = 0; i < _results.length; i++)
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
        () => const Padding(
          padding: EdgeInsets.fromLTRB(4, 16, 0, 12),
          child: Text(
            'In the TV guide',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
      for (final (c, p) in _programmes)
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

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(64, 40, 64, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Search',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            TvTextField(
              builder: (readOnly) => TextField(
                readOnly: readOnly,
                controller: _query,
                autofocus: true,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _run(),
                decoration: const InputDecoration(
                  labelText: 'Channel or programme',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (empty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  'Nothing found.',
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
                onAir ? 'ON NOW' : 'REPLAY',
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
