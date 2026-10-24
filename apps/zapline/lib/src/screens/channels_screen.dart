import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/channel_tile.dart';
import '../widgets/focus_card.dart';
import 'guide_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'sources_screen.dart';

/// Menu and groups on the left, channels on the right. Both lists are built
/// lazily so tens of thousands of channels stay cheap.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({
    super.key,
    required this.state,
    this.autoplayFirst = false,
  });

  final AppState state;

  /// Development aid: open the first channel immediately.
  final bool autoplayFirst;

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

/// Pseudo-group for favourites; cannot clash with a real group title.
const _favourites = '\u0000favourites';

class _ChannelsScreenState extends State<ChannelsScreen> {
  /// `null` means all channels, [_favourites] the favourites list.
  String? _group;

  final _firstChannel = FocusNode(debugLabel: 'first channel');
  final _menuFirst = FocusNode(debugLabel: 'menu');

  (String?, int)? _cacheKey;
  List<Channel> _cache = const [];

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
    _menuFirst.dispose();
    super.dispose();
  }

  /// Left from the channel list always reaches the menu, even when no menu
  /// item lines up with the focused row.
  KeyEventResult _listKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.focusInDirection(TraversalDirection.left)) {
      return KeyEventResult.handled;
    }
    _menuFirst.requestFocus();
    return KeyEventResult.handled;
  }

  List<Channel> get _visible {
    final key = (_group, widget.state.version);
    if (key != _cacheKey) {
      _cacheKey = key;
      _cache = _group == _favourites
          ? widget.state.favourites()
          : widget.state.channels(group: _group);
    }
    return _cache;
  }

  void _play(List<Channel> list, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          state: widget.state,
          channels: list,
          initialIndex: index,
        ),
      ),
    );
  }

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final state = widget.state;
    final groups = <String?>[
      null,
      if (state.hasFavourites) _favourites,
      ...state.groups,
    ];
    if (!groups.contains(_group)) _group = null;
    final visible = _visible;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 300,
            color: ZaplineColors.rail,
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: FocusTraversalGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        const Text(
                          'Zapline',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: ZaplineColors.focus,
                          ),
                        ),
                        const Spacer(),
                        if (state.isSyncing)
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _MenuItem(
                    focusNode: _menuFirst,
                    icon: Icons.grid_view_rounded,
                    label: 'TV guide',
                    onPressed: () =>
                        _open(GuideScreen(state: state, channels: visible)),
                  ),
                  _MenuItem(
                    icon: Icons.search,
                    label: 'Search',
                    onPressed: () => _open(SearchScreen(state: state)),
                  ),
                  _MenuItem(
                    icon: Icons.dns_outlined,
                    label: 'Sources',
                    onPressed: () => _open(SourcesScreen(state: state)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: ZaplineColors.line, height: 1),
                  ),
                  Expanded(
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
                            onPressed: () => _firstChannel.requestFocus(),
                            child: Row(
                              children: [
                                if (g == _favourites) ...[
                                  const Icon(Icons.star_rounded, size: 20),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    switch (g) {
                                      null => 'All channels',
                                      _favourites => 'Favourites',
                                      _ => g,
                                    },
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
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
                    child: Text(
                      'Hold OK on a channel to add it to favourites',
                      style: TextStyle(
                        fontSize: 13,
                        color: ZaplineColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _listKey,
              child: FocusTraversalGroup(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
                  itemCount: visible.length,
                  itemExtent: 86,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ChannelTile(
                      state: state,
                      channel: visible[i],
                      fallbackNumber: i + 1,
                      focusNode: i == 0 ? _firstChannel : null,
                      onPressed: () => _play(visible, i),
                      onLongPress: () => state.toggleFavourite(visible[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.focusNode,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: FocusCard(
      focusNode: focusNode,
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
