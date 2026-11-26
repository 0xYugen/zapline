import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../countries.dart';
import '../l10n.dart';
import '../theme.dart';
import '../vod/vod_browse.dart';
import '../widgets/channel_actions.dart';
import '../widgets/epg_suggestion.dart';
import '../widgets/brand.dart';
import '../widgets/focus_card.dart';
import '../widgets/sync_steps.dart';
import '../mobile/mobile_widgets.dart' show unlockWithPin;
import 'guide_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import '../layout.dart';

/// The TV and desktop home: a side menu, the groups (shown when moving left)
/// and the channels with their guide in one grid, as TV apps do.
///
/// Each part is its own focus scope and the remote moves between them
/// explicitly: right goes deeper (menu → groups → grid), left comes back
/// (left on a programme airing now opens the groups).
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

/// Where focus is: the menu opens wide, the groups show, or the grid gets
/// the room.
enum _Area { menu, groups, grid }

class _ChannelsScreenState extends State<ChannelsScreen> {
  /// `null` means all channels, [_favourites] and [_recent] the
  /// pseudo-groups.
  String? _group;
  _Area _area = _Area.grid;

  final _grid = GlobalKey<GuideGridState>();
  final _menuFirst = FocusNode(debugLabel: 'menu');
  final _groupNodes = <String?, FocusNode>{};

  (String?, int, int)? _cacheKey;
  List<Channel>? _cache;

  /// The grid was asked for while its channels were still loading: it
  /// takes focus once they are here.
  bool _wantGrid = false;

  /// The channel to reopen at startup, once all channels have loaded.
  Channel? _resume;

  @override
  void initState() {
    super.initState();
    widget.state.lastPlayed.addListener(_backFromPlayer);
    // `autofocus` is ignored when the previous screen still held focus while
    // this one was built, so request it explicitly after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _toGrid();
      offerFreeEpgIfUseful(context, widget.state);
      final db = widget.state.db;
      if (db.setting('holdOkHintShown') == null) {
        db.setSetting('holdOkHintShown', '1');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.holdOkHint),
            duration: const Duration(seconds: 8),
          ),
        );
      }
      if (widget.autoplayFirst && _visible.isNotEmpty) {
        _play(_visible, 0);
      } else if (widget.state.resumeChannel case final last?) {
        _resume = last;
        _resumeWhenLoaded();
      }
    });
  }

  /// Opens [_resume] in the list of all channels, as soon as it is loaded
  /// (off screen, for a large playlist).
  void _resumeWhenLoaded() {
    final last = _resume;
    if (last == null) return;
    final all = widget.state.channelsReady(null);
    if (all == null) return;
    _resume = null;
    final i = widget.state.indexOfChannel(all, last);
    if (i >= 0) _play(all, i);
  }

  /// Back from the player: the grid shows the channel zapped to.
  void _backFromPlayer() {
    final c = widget.state.lastPlayed.value;
    if (c == null || !mounted) return;
    // Recent channels have changed; rebuild before focusing.
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _area == _Area.grid) _grid.currentState?.focusChannel(c);
    });
  }

  @override
  void dispose() {
    widget.state.lastPlayed.removeListener(_backFromPlayer);
    _previewTimer?.cancel();
    _menuFirst.dispose();
    for (final n in _groupNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _groupNode(String? g) =>
      _groupNodes.putIfAbsent(g, () => FocusNode(debugLabel: 'group $g'));

  /// The channels of the group on screen; while a large list loads, the
  /// one shown before stays, and none at the very start.
  List<Channel> get _visible => _loaded ?? const [];

  List<Channel>? get _loaded {
    final state = widget.state;
    // Favourites and recents change without the channels changing.
    final key = (
      _group,
      state.version,
      switch (_group) {
        _favourites => state.favouritesVersion,
        _recent => state.recentsVersion,
        _ => 0,
      },
    );
    if (key != _cacheKey) {
      final list = switch (_group) {
        _favourites => state.favourites(),
        _recent => state.recents(),
        final g => state.channelsReady(g),
      };
      if (list == null) return _cache;
      _cacheKey = key;
      _cache = list;
    }
    return _cache;
  }

  bool get _locked => _group != null && widget.state.isLocked(_group!);

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

  void _toGrid() {
    if (!_locked && _loaded == null) {
      // Still loading: the grid takes focus when its channels arrive.
      setState(() {
        _area = _Area.grid;
        _wantGrid = true;
      });
      return;
    }
    if (_locked || _visible.isEmpty) {
      _toGroups();
      return;
    }
    setState(() => _area = _Area.grid);
    // After the rebuild: the grid may be showing another group by then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _grid.currentState?.focusNow();
    });
  }

  /// Shows the groups and focuses the one in use.
  void _toGroups() {
    setState(() => _area = _Area.groups);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _groupNode(_group).requestFocus();
    });
  }

  void _toMenu() {
    setState(() => _area = _Area.menu);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _menuFirst.requestFocus();
    });
  }

  /// Select on a group: enter its channels, asking for the PIN first when
  /// it is locked.
  /// Moving over a group previews it once focus rests there: holding a
  /// key through the groups doesn't load each one's channels and guide.
  void _preview(String? g) {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && _group != g) setState(() => _group = g);
    });
  }

  Timer? _previewTimer;

  Future<void> _enterGroup(String? g) async {
    _previewTimer?.cancel();
    if (_group != g) setState(() => _group = g);
    final state = widget.state;
    if (g != null && state.isLocked(g)) {
      if (!await unlockWithPin(context, state) || !mounted) return;
      // Rows are built on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _toGrid());
      return;
    }
    _toGrid();
  }

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  /// Arrow keys between the three parts; each part moves inside itself.
  KeyEventResult Function(FocusNode, KeyEvent) _keys({
    VoidCallback? left,
    VoidCallback? right,
  }) => (_, e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final go = switch (e.logicalKey) {
      LogicalKeyboardKey.arrowLeft => left,
      LogicalKeyboardKey.arrowRight => right,
      _ => null,
    };
    if (go == null) return KeyEventResult.ignored;
    final primary = FocusManager.instance.primaryFocus;
    final dir = e.logicalKey == LogicalKeyboardKey.arrowLeft
        ? TraversalDirection.left
        : TraversalDirection.right;
    // Within a part first (menu items side by side don't exist, but keep
    // it general), then across.
    if (primary != null && primary.focusInDirection(dir)) {
      return KeyEventResult.handled;
    }
    go();
    return KeyEventResult.handled;
  };

  /// Keeps track of the part holding focus, mouse users included.
  Widget _part(
    _Area area,
    Widget child, {
    VoidCallback? left,
    VoidCallback? right,
  }) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (has) {
      if (has && _area != area) setState(() => _area = area);
    },
    onKeyEvent: _keys(left: left, right: right),
    child: FocusScope(child: child),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => _build(context),
    );
  }

  String _groupName(String? g) => switch (g) {
    null => context.l10n.allChannels,
    _favourites => context.l10n.favourites,
    _recent => context.l10n.recent,
    _ => g,
  };

  Widget _build(BuildContext context) {
    final state = widget.state;
    final l = context.l10n;
    final groups = <String?>[
      null,
      if (state.hasRecents) _recent,
      if (state.hasFavourites) _favourites,
      ...state.groups,
    ];
    if (!groups.contains(_group)) _group = null;
    final loaded = _loaded;
    final visible = loaded ?? const <Channel>[];
    if (loaded != null && (_wantGrid || _resume != null)) {
      final focusGrid = _wantGrid;
      _wantGrid = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (focusGrid) _toGrid();
        _resumeWhenLoaded();
      });
    }
    final wide = _area == _Area.menu;
    final showGroups = _area != _Area.grid;

    final grid = Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: _locked
          ? _Message(
              icon: Icons.lock_outline_rounded,
              title: l.groupLocked,
              subtitle: l.pressOkForPin,
            )
          : loaded == null
          // A large playlist's first load, off screen.
          ? const Center(
              child: CircularProgressIndicator(color: ZaplineColors.accent),
            )
          : visible.isEmpty && state.isSyncing
          // A playlist just added or received: say it is on its way.
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.loadingYourList,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.loadingYourListHint,
                      style: const TextStyle(
                        fontSize: 16,
                        color: ZaplineColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ValueListenableBuilder(
                      valueListenable: state.syncProgress,
                      builder: (context, progress, _) => SyncSteps(progress),
                    ),
                    const LinearProgressIndicator(
                      color: ZaplineColors.accent,
                      backgroundColor: ZaplineColors.line,
                    ),
                  ],
                ),
              ),
            )
          : visible.isEmpty
          ? _Message(icon: Icons.tv_off_rounded, title: l.noChannelsInGroup)
          : _part(
              _Area.grid,
              GuideGrid(
                key: _grid,
                state: state,
                channels: visible,
                caption: _groupName(_group),
                onExitLeft: _toGroups,
                onLongPress: (c) => showChannelActions(context, state, c),
              ),
            ),
    );

    // Back goes up a level, grid → groups → menu, before leaving the app.
    // The remote's search key (or Ctrl+F) opens search from anywhere here.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.browserSearch): _search,
        const SingleActivator(LogicalKeyboardKey.find): _search,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _search,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _search,
      },
      child: PopScope(
        canPop: _area == _Area.menu,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // In the grid, Back first returns to what's on now.
          final grid = _grid.currentState;
          if (_area == _Area.grid && grid != null && !grid.atNow) {
            grid.focusNow();
          } else {
            _area == _Area.grid ? _toGroups() : _toMenu();
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              // The grid keeps its room; menu and groups open over it.
              Positioned.fill(left: _SideMenu.narrowWidth, child: grid),
              // Refreshing a playlist that already has channels, or one that
              // couldn't be refreshed (an expired subscription, a moved
              // server): said here, details in Settings.
              if (state.isSyncing && visible.isNotEmpty)
                _Badge(
                  leading: const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  text: l.updatingList,
                )
              else if (state.sources
                      .where((s) => state.syncFailure(s.id) != null)
                      .firstOrNull
                  case final failed?)
                _Badge(
                  leading: const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: ZaplineColors.live,
                  ),
                  text: l.sourceUpdateFailedNamed(failed.name),
                ),
              // Dims the grid while the menu or the groups are open; a click on
              // it goes back to the grid.
              Positioned.fill(
                left: _SideMenu.narrowWidth,
                child: IgnorePointer(
                  ignoring: _area == _Area.grid,
                  child: GestureDetector(
                    onTap: _toGrid,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _area == _Area.grid ? 0 : 1,
                      child: const ColoredBox(color: Color(0xA6000000)),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _part(
                      _Area.menu,
                      right: _toGroups,
                      _SideMenu(
                        wide: wide,
                        syncing: state.isSyncing,
                        items: [
                          _MenuEntry(
                            focusNode: _menuFirst,
                            icon: Icons.live_tv_rounded,
                            label: l.liveTv,
                            selected: _group != _favourites,
                            onPressed: () {
                              if (_group == _favourites) {
                                setState(() => _group = null);
                              }
                              _toGrid();
                            },
                          ),
                          _MenuEntry(
                            icon: Icons.star_outline_rounded,
                            label: l.favourites,
                            selected: _group == _favourites,
                            onPressed: () {
                              setState(() => _group = _favourites);
                              _toGrid();
                            },
                          ),
                          if (state.hasMovies)
                            _MenuEntry(
                              icon: Icons.movie_outlined,
                              label: l.movies,
                              onPressed: () => _open(
                                VodScreen(state: state, kind: VodKind.movies),
                              ),
                            ),
                          if (state.hasShows)
                            _MenuEntry(
                              icon: Icons.video_library_outlined,
                              label: l.series,
                              onPressed: () => _open(
                                VodScreen(state: state, kind: VodKind.shows),
                              ),
                            ),
                          // From live TV: channels and the guide; films and series have their own
                          // search.
                          _MenuEntry(
                            icon: Icons.search,
                            label: l.search,
                            onPressed: () => _open(SearchScreen(state: state)),
                          ),
                          _MenuEntry(
                            icon: Icons.settings_outlined,
                            label: l.settings,
                            dot: state.update != null,
                            onPressed: () =>
                                _open(SettingsScreen(state: state)),
                          ),
                        ],
                      ),
                    ),
                    // The groups slide in when moving left from the grid.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: showGroups ? 270 : 0,
                      color: ZaplineColors.surface,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: 270,
                          maxWidth: 270,
                          child: ExcludeFocus(
                            excluding: !showGroups,
                            child: _part(
                              _Area.groups,
                              left: _toMenu,
                              right: _toGrid,
                              _Groups(
                                title: l.groups,
                                groups: groups,
                                selected: _group,
                                nameOf: _groupName,
                                nodeOf: _groupNode,
                                locked: (g) =>
                                    g != null && state.lockedGroups.contains(g)
                                    ? state.isLocked(g)
                                    : null,
                                // Moving over a group previews it, like most TV
                                // apps; Select jumps into the grid.
                                onFocused: _preview,
                                onPressed: _enterGroup,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _search() => _open(SearchScreen(state: widget.state));
}

/// The menu down the left: icons, opening to show their names while it
/// holds focus.
class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.wide,
    required this.syncing,
    required this.items,
  });

  final bool wide;
  final bool syncing;
  final List<_MenuEntry> items;

  static const narrowWidth = 84.0;
  static const wideWidth = 250.0;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOut,
    width: wide ? wideWidth : narrowWidth,
    color: ZaplineColors.rail,
    padding: const EdgeInsets.fromLTRB(14, 28, 14, 16),
    child: ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: wideWidth - 28,
        maxWidth: wideWidth - 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 9, bottom: 28),
              child: Row(
                children: [
                  if (syncing)
                    const SizedBox.square(
                      dimension: 38,
                      child: Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    const ZaplineMark(size: 38),
                  const SizedBox(width: 14),
                  // The name is a picture of text: it stays its size.
                  const Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ZaplineWordmark(height: 22),
                    ),
                  ),
                ],
              ),
            ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                // Narrow, an icon in a square; wide, the name beside it.
                child: SizedBox(
                  width: wide ? wideWidth - 28 : narrowWidth - 28,
                  child: item.copyWith(wide: wide),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _MenuEntry extends StatelessWidget {
  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.selected = false,
    this.dot = false,
    this.wide = true,
  });

  _MenuEntry copyWith({required bool wide}) => _MenuEntry(
    icon: icon,
    label: label,
    onPressed: onPressed,
    focusNode: focusNode,
    selected: selected,
    dot: dot,
    wide: wide,
  );

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  /// The section on screen (live TV).
  final bool selected;

  /// A new version waits behind this entry.
  final bool dot;

  /// With its name; else the icon alone.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final mark = Badge(
      isLabelVisible: dot,
      backgroundColor: ZaplineColors.accent,
      smallSize: 9,
      child: Icon(icon, size: 24),
    );
    final card = FocusCard(
      focusNode: focusNode,
      selected: selected,
      quiet: true,
      onPressed: onPressed,
      radius: 14,
      padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 0, vertical: 15),
      child: wide
          ? Row(
              children: [
                mark,
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          : Center(child: mark),
    );
    // Narrow, the name shows when the mouse rests on the icon.
    return wide ? card : Tooltip(message: label, child: card);
  }
}

/// The groups, opened beside the grid. Long lists are quick to cross:
/// Page Up/Down, Channel +/- and fast-forward/rewind move a screen, and a
/// keyboard's letters go to the next group starting with that letter.
class _Groups extends StatefulWidget {
  const _Groups({
    required this.title,
    required this.groups,
    required this.selected,
    required this.nameOf,
    required this.nodeOf,
    required this.locked,
    required this.onFocused,
    required this.onPressed,
  });

  final String title;
  final List<String?> groups;
  final String? selected;
  final String Function(String?) nameOf;
  final FocusNode Function(String?) nodeOf;

  /// `null` for a group without a lock, else whether it's still locked.
  final bool? Function(String?) locked;
  final ValueChanged<String?> onFocused;
  final ValueChanged<String?> onPressed;

  @override
  State<_Groups> createState() => _GroupsState();
}

class _GroupsState extends State<_Groups> {
  static const _rowHeight = 52.0;
  static final _letter = RegExp('[A-Za-z0-9]');

  /// A row, taller with large system text.
  double get _row => scaledExtent(context, _rowHeight);
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int get _focused {
    final i = widget.groups.indexWhere((g) => widget.nodeOf(g).hasFocus);
    return i < 0 ? widget.groups.indexOf(widget.selected) : i;
  }

  /// Focuses group [i], bringing it on screen first: rows off screen are
  /// not built, so their cards can't take focus yet.
  void _focus(int i) {
    final g = widget.groups[i];
    final node = widget.nodeOf(g);
    if (node.context?.mounted ?? false) {
      node.requestFocus();
      return;
    }
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    pos.jumpTo(
      (i * _row - pos.viewportDimension / 3).clamp(0.0, pos.maxScrollExtent),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.nodeOf(g).requestFocus();
    });
  }

  int get _page {
    final h = _scroll.hasClients ? _scroll.position.viewportDimension : 0.0;
    return h <= 0 ? 8 : (h / _row).floor().clamp(2, 40) - 1;
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final n = widget.groups.length;
    if (n == 0) return KeyEventResult.ignored;
    final at = _focused.clamp(0, n - 1);
    final k = e.logicalKey;
    int? to;
    if (k == LogicalKeyboardKey.pageDown ||
        k == LogicalKeyboardKey.channelDown ||
        k == LogicalKeyboardKey.mediaFastForward) {
      to = (at + _page).clamp(0, n - 1);
    } else if (k == LogicalKeyboardKey.pageUp ||
        k == LogicalKeyboardKey.channelUp ||
        k == LogicalKeyboardKey.mediaRewind) {
      to = (at - _page).clamp(0, n - 1);
    } else if (k == LogicalKeyboardKey.home) {
      to = 0;
    } else if (k == LogicalKeyboardKey.end) {
      to = n - 1;
    } else if (e is KeyDownEvent &&
        k.keyLabel.length == 1 &&
        _letter.hasMatch(k.keyLabel)) {
      // The next group after this one that starts with the letter, past a
      // country tag ("IT | Sport" counts as S).
      final letter = k.keyLabel.toLowerCase();
      for (var step = 1; step <= n; step++) {
        final i = (at + step) % n;
        final name = withoutCountryTag(widget.nameOf(widget.groups[i]));
        if (name.toLowerCase().startsWith(letter)) {
          to = i;
          break;
        }
      }
      if (to == null) return KeyEventResult.ignored;
    } else {
      return KeyEventResult.ignored;
    }
    if (to != at) _focus(to);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 20, 14),
        child: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: ZaplineColors.textMuted,
          ),
        ),
      ),
      Expanded(
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            itemCount: widget.groups.length,
            itemExtent: _row,
            itemBuilder: (context, i) {
              final g = widget.groups[i];
              final lock = widget.locked(g);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: FocusCard(
                  focusNode: widget.nodeOf(g),
                  selected: g == widget.selected,
                  radius: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  onFocused: () => widget.onFocused(g),
                  onPressed: () => widget.onPressed(g),
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
                          widget.nameOf(g),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (lock != null)
                        Icon(
                          lock
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
      ),
    ],
  );
}

/// A small note at the top right of the home, out of the remote's way.
class _Badge extends StatelessWidget {
  const _Badge({required this.leading, required this.text});

  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) => Positioned(
    top: 18,
    right: 28,
    child: IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ZaplineColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(color: ZaplineColors.textMuted),
          ),
      ],
    ),
  );
}
