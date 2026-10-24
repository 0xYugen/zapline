import 'package:flutter/material.dart';
import 'package:lineup_core/lineup_core.dart';

import '../library.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import 'player_screen.dart';

/// Groups on the left, channels on the right. Both lists are lazily built so
/// tens of thousands of channels stay cheap.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({
    super.key,
    required this.library,
    this.autoplayFirst = false,
  });

  final Library library;

  /// Development aid: open the first channel immediately.
  final bool autoplayFirst;

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  /// `null` means all channels.
  String? _group;

  final _firstChannel = FocusNode(debugLabel: 'first channel');

  @override
  void initState() {
    super.initState();
    // `autofocus` is ignored when the previous screen still held focus while
    // this one was built, so request it explicitly after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _firstChannel.requestFocus();
      if (widget.autoplayFirst && _visible.isNotEmpty) _play(_visible, 0);
    });
  }

  @override
  void dispose() {
    _firstChannel.dispose();
    super.dispose();
  }

  List<Channel> get _visible {
    final all = widget.library.channels;
    if (_group == null) return all;
    return [
      for (final c in all)
        if (c.groupTitle == _group) c,
    ];
  }

  void _play(List<Channel> list, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(channels: list, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = widget.library;
    final groups = <String?>[null, ...lib.groups];
    final visible = _visible;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 300,
            color: LineupColors.rail,
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    lib.sourceName ?? 'Lineup',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: FocusTraversalGroup(
                    child: ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, i) {
                        final g = groups[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: FocusCard(
                            selected: g == _group,
                            // Moving focus over a group previews it, like
                            // most TV apps; Select jumps into the list.
                            onFocused: () => setState(() => _group = g),
                            onPressed: () => FocusScope.of(context).nextFocus(),
                            child: Text(
                              g ?? 'All channels',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FocusTraversalGroup(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
                itemCount: visible.length,
                itemExtent: 74,
                itemBuilder: (context, i) {
                  final c = visible[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FocusCard(
                      focusNode: i == 0 ? _firstChannel : null,
                      onPressed: () => _play(visible, i),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              '${c.number ?? i + 1}',
                              style: const TextStyle(
                                fontSize: 16,
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
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (c.catchup != null)
                            const Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Icon(Icons.history, size: 20),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
