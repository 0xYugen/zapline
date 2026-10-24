import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lineup_core/lineup_core.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/channel_tile.dart';
import '../widgets/tv_text_field.dart';
import 'player_screen.dart';

/// Channel search across all sources. Prefix matching, accent-insensitive,
/// results as you type.
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

  @override
  void initState() {
    super.initState();
    _query.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), _run);
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
    setState(() => _results = widget.state.search(_query.text));
  }

  void _play(int i) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(
        state: widget.state,
        channels: _results,
        initialIndex: i,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final empty = _query.text.trim().isNotEmpty && _results.isEmpty;
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
              child: TextField(
                controller: _query,
                autofocus: true,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _run(),
                decoration: const InputDecoration(
                  labelText: 'Channel name',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (empty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  'No channels found.',
                  style: TextStyle(color: LineupColors.textMuted),
                ),
              ),
            Expanded(
              // Rebuild on favourite changes so the stars stay current.
              child: ListenableBuilder(
                listenable: widget.state,
                builder: (context, _) => ListView.builder(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: _results.length,
                  itemExtent: 86,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ChannelTile(
                      state: widget.state,
                      channel: _results[i],
                      fallbackNumber: i + 1,
                      onPressed: () => _play(i),
                      onLongPress: () =>
                          widget.state.toggleFavourite(_results[i]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
