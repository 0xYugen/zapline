import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../channel_groups.dart';
import '../l10n.dart';
import '../screens/player_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/channel_actions.dart';
import '../widgets/channel_logo.dart';
import '../widgets/epg_suggestion.dart';
import '../vod/vod_browse.dart';
import 'mobile_guide.dart';
import 'mobile_widgets.dart';

/// Phone shell: live TV, films and series (when a source has them), guide,
/// favourites and settings behind a bottom navigation bar (a side rail when
/// held sideways). Search sits in the
/// header of every tab. Each tab keeps its state while another is shown.
class MobileHome extends StatefulWidget {
  const MobileHome({super.key, required this.state});

  final AppState state;

  @override
  State<MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<MobileHome> {
  _Tab _tab = _Tab.tv;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) offerFreeEpgIfUseful(context, widget.state);
      final last = widget.state.resumeChannel;
      if (!mounted || last == null) return;
      final all = widget.state.channels();
      final i = widget.state.indexOfChannel(all, last);
      if (i >= 0) openPlayer(context, widget.state, all, i);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l = context.l10n;
    final state = widget.state;
    final vod = state.hasMovies || state.hasShows;
    // Five tabs leave no room for favourites: with films and series they
    // are a pill in the TV tab.
    final tabs = [
      _Tab.tv,
      _Tab.guide,
      if (state.hasMovies) _Tab.movies,
      if (state.hasShows) _Tab.shows,
      if (!vod) _Tab.favourites,
      _Tab.settings,
    ];
    if (!tabs.contains(_tab)) _tab = _Tab.tv;
    final index = tabs.indexOf(_tab);
    final destinations = [
      for (final t in tabs)
        switch (t) {
          _Tab.tv => (
            Icons.live_tv_outlined,
            Icons.live_tv_rounded,
            vod ? l.tv : l.liveTv,
          ),
          _Tab.movies => (Icons.movie_outlined, Icons.movie_rounded, l.movies),
          _Tab.shows => (
            Icons.video_library_outlined,
            Icons.video_library_rounded,
            l.series,
          ),
          _Tab.guide => (
            Icons.calendar_month_outlined,
            Icons.calendar_month_rounded,
            l.guide,
          ),
          _Tab.favourites => (
            Icons.star_outline_rounded,
            Icons.star_rounded,
            l.favourites,
          ),
          _Tab.settings => (
            Icons.settings_outlined,
            Icons.settings_rounded,
            l.settings,
          ),
        },
    ];
    final body = IndexedStack(
      index: index,
      children: [
        for (final t in tabs)
          KeyedSubtree(
            key: ValueKey(t),
            child: switch (t) {
              _Tab.tv => ChannelsTab(state: state),
              _Tab.movies => VodTab(state: state, kind: VodKind.movies),
              _Tab.shows => VodTab(state: state, kind: VodKind.shows),
              _Tab.guide => MobileGuide(state: state),
              _Tab.favourites => FavouritesTab(state: state),
              _Tab.settings => SettingsScreen(state: state),
            },
          ),
      ],
    );
    void select(int i) {
      HapticFeedback.selectionClick();
      setState(() => _tab = tabs[i]);
    }

    // Sideways, a rail keeps the little height there is for the lists.
    if (isLandscape(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, selected, label) in destinations)
                  NavigationRailDestination(
                    icon: _dotted(icon, label),
                    selectedIcon: _dotted(selected, label),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, color: ZaplineColors.line),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: select,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final (icon, selected, label) in destinations)
            NavigationDestination(
              icon: _dotted(icon, label),
              selectedIcon: _dotted(selected, label),
              label: label,
            ),
        ],
      ),
    );
  }

  /// The settings icon carries a dot while a new version waits.
  Widget _dotted(IconData icon, String label) => Badge(
    isLabelVisible:
        label == context.l10n.settings && widget.state.update != null,
    backgroundColor: ZaplineColors.focus,
    smallSize: 9,
    child: Icon(icon),
  );
}

enum _Tab { tv, movies, shows, guide, favourites, settings }

/// A phone held sideways: little height, so headers shrink.
bool isLandscape(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height;
}

void openPlayer(
  BuildContext context,
  AppState state,
  List<Channel> channels,
  int index, {
  Programme? replay,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => PlayerScreen(
      state: state,
      channels: channels,
      initialIndex: index,
      replay: replay,
    ),
  ),
);

/// A tab's header: the logo or a title, a sync indicator and search.
class MobileHeader extends StatelessWidget {
  const MobileHeader({super.key, required this.state, this.title});

  final AppState state;

  /// `null` shows the Zapline logo.
  final String? title;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Padding(
      padding: isLandscape(context)
          ? const EdgeInsets.fromLTRB(20, 4, 8, 0)
          : const EdgeInsets.fromLTRB(20, 10, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: switch (title) {
              final t? => Text(
                t,
                style: TextStyle(
                  fontSize: isLandscape(context) ? 20 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              null => Align(
                alignment: Alignment.centerLeft,
                child: ZaplineLockup(height: isLandscape(context) ? 22 : 26),
              ),
            },
          ),
          if (state.isSyncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ZaplineColors.focus,
                ),
              ),
            ),
          IconButton.filledTonal(
            tooltip: state.hasMovies || state.hasShows
                ? context.l10n.searchTooltipVod
                : context.l10n.searchTooltip,
            style: IconButton.styleFrom(
              backgroundColor: ZaplineColors.surface,
              foregroundColor: ZaplineColors.text,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SearchScreen(state: state),
              ),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
    ),
  );
}

class ChannelsTab extends StatefulWidget {
  const ChannelsTab({super.key, required this.state});

  final AppState state;

  @override
  State<ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<ChannelsTab> {
  String? _group;
  final _cache = ChannelListCache();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(String? g) {
    setState(() => _group = g);
    if (_scroll.hasClients) _scroll.jumpTo(0);
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
        // The last channel watched, a tap away, on the full list only.
        final last = _group == null && state.hasRecents
            ? state.recents().firstOrNull
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileHeader(state: state),
            GroupBar(state: state, selected: _group, onSelected: _select),
            const Divider(height: 1, color: ZaplineColors.line),
            Expanded(
              child: locked
                  ? LockedGroupView(state: state)
                  : list.isEmpty
                  ? EmptyView(context.l10n.noChannelsInGroup)
                  : CustomScrollView(
                      controller: _scroll,
                      slivers: [
                        if (last != null && !isLandscape(context))
                          SliverToBoxAdapter(
                            child: ContinueWatchingCard(
                              state: state,
                              channel: last,
                            ),
                          ),
                        SliverFixedExtentList(
                          itemExtent: MobileChannelRow.height,
                          delegate: SliverChildBuilderDelegate(
                            childCount: list.length,
                            (context, i) => MobileChannelRow(
                              state: state,
                              channel: list[i],
                              number: state.channelNumber(list[i], i),
                              onTap: () => openPlayer(context, state, list, i),
                              onLongPress: () =>
                                  showChannelActions(context, state, list[i]),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// The last channel watched with what's on it now, at the top of the list.
class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({
    super.key,
    required this.state,
    required this.channel,
  });

  final AppState state;
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (now, _) = state.nowNext(channel);
    final t = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: ZaplineColors.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            final recents = state.recents();
            openPlayer(context, state, recents, 0);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    ChannelLogo(channel: channel, width: 104, height: 62),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ZaplineColors.live,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: ZaplineColors.onFocus,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.continueWatching.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: ZaplineColors.focus,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        now == null
                            ? state.displayName(channel)
                            : '${now.title} · ${state.displayName(channel)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (now != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${state.time(now.start)}–${state.time(now.stop)}'
                          ' · ${l.timeLeft(now.stop.difference(t))}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ZaplineColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value:
                                (t.difference(now.start).inSeconds /
                                        now.stop
                                            .difference(now.start)
                                            .inSeconds)
                                    .clamp(0.0, 1.0),
                            minHeight: 3,
                            color: ZaplineColors.focus,
                            backgroundColor: ZaplineColors.line,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Favourite channels, across sources.
class FavouritesTab extends StatelessWidget {
  const FavouritesTab({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final list = state.favourites();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileHeader(state: state, title: context.l10n.favourites),
          const SizedBox(height: 8),
          const Divider(height: 1, color: ZaplineColors.line),
          Expanded(
            child: list.isEmpty
                ? EmptyView(
                    context.l10n.favouritesEmpty,
                    icon: Icons.star_outline_rounded,
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemExtent: MobileChannelRow.height,
                    itemBuilder: (context, i) => MobileChannelRow(
                      state: state,
                      channel: list[i],
                      number: state.channelNumber(list[i], i),
                      onTap: () => openPlayer(context, state, list, i),
                      onLongPress: () =>
                          showChannelActions(context, state, list[i]),
                    ),
                  ),
          ),
        ],
      );
    },
  );
}
