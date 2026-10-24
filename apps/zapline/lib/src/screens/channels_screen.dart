import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/channel_actions.dart';
import '../widgets/channel_tile.dart';
import '../widgets/brand.dart';
import '../widgets/focus_card.dart';
import '../widgets/pin_pad.dart';
import 'guide_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
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

/// Pseudo-groups; they cannot clash with a real group title.
const _favourites = '\u0000favourites';
const _recent = '\u0000recent';

class _ChannelsScreenState extends State<ChannelsScreen> {
  /// `null` means all channels, [_favourites] and [_recent] the
  /// pseudo-groups.
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
      if (widget.autoplayFirst && _visible.isNotEmpty) {
        _play(_visible, 0);
      } else if (widget.state.resumeChannel case final last?) {
        final all = widget.state.channels();
        final i = all.indexWhere(
          (c) => c.sourceId == last.sourceId && c.id == last.id,
        );
        if (i >= 0) _play(all, i);
      }
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
      _cache = switch (_group) {
        _favourites => widget.state.favourites(),
        _recent => widget.state.recents(),
        final g => widget.state.channels(group: g),
      };
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

  /// Select on a group: enter its channels, asking for the PIN first when
  /// it is locked.
  Future<void> _enterGroup(String? g) async {
    final state = widget.state;
    if (g != null && state.isLocked(g)) {
      final pin = await askPin(context, title: 'Enter the PIN');
      if (pin == null || !mounted) return;
      if (!state.unlock(pin)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Wrong PIN')));
        return;
      }
      // Rows are built on the next frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _firstChannel.requestFocus(),
      );
      return;
    }
    _firstChannel.requestFocus();
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
      if (state.hasRecents) _recent,
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
                        const ZaplineLockup(height: 26),
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
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onPressed: () => _open(SettingsScreen(state: state)),
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
                            onPressed: () => _enterGroup(g),
                            child: Row(
                              children: [
                                if (switch (g) {
                                      _favourites => Icons.star_rounded,
                                      _recent => Icons.history_rounded,
                                      _ => null,
                                    }
                                    case final icon?) ...[
                                  Icon(icon, size: 20),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    switch (g) {
                                      null => 'All channels',
                                      _favourites => 'Favourites',
                                      _recent => 'Recent',
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
                                if (g != null && state.lockedGroups.contains(g))
                                  Icon(
                                    state.isLocked(g)
                                        ? Icons.lock_outline_rounded
                                        : Icons.lock_open_rounded,
                                    size: 18,
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
                      'Hold OK on a channel for favourites, hiding and its '
                      'guide',
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
          if (_group != null && state.isLocked(_group!))
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'This group is locked',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Press OK to enter the PIN.',
                      style: TextStyle(color: ZaplineColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
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
                        number: state.channelNumber(visible[i], i),
                        focusNode: i == 0 ? _firstChannel : null,
                        onPressed: () => _play(visible, i),
                        onLongPress: () =>
                            showChannelActions(context, state, visible[i]),
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
