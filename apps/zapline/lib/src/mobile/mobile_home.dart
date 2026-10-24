import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../channel_groups.dart';
import '../screens/player_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';
import '../widgets/channel_actions.dart';
import 'mobile_guide.dart';
import 'mobile_widgets.dart';

/// Phone shell: channels, guide, search and settings behind a bottom
/// navigation bar. Each tab keeps its state while another is shown.
class MobileHome extends StatefulWidget {
  const MobileHome({super.key, required this.state});

  final AppState state;

  @override
  State<MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<MobileHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final last = widget.state.resumeChannel;
      if (!mounted || last == null) return;
      final all = widget.state.channels();
      final i = all.indexWhere(
        (c) => c.sourceId == last.sourceId && c.id == last.id,
      );
      if (i >= 0) openPlayer(context, widget.state, all, i);
    });
  }

  static const _destinations = [
    (Icons.live_tv_outlined, Icons.live_tv_rounded, 'Channels'),
    (Icons.view_list_outlined, Icons.view_list_rounded, 'Guide'),
    (Icons.search_rounded, Icons.search_rounded, 'Search'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = IndexedStack(
      index: _tab,
      children: [
        ChannelsTab(state: widget.state),
        MobileGuide(state: widget.state),
        SearchScreen(state: widget.state),
        SettingsScreen(state: widget.state),
      ],
    );
    void select(int i) => setState(() => _tab = i);
    // Sideways, a rail keeps the little height there is for the lists.
    if (isLandscape(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, selected, label) in _destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, color: ZaplineColors.line),
            Expanded(child: tabs),
          ],
        ),
      );
    }
    return Scaffold(
      body: tabs,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: select,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final (icon, selected, label) in _destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}

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

/// A header with the brand and a sync indicator, shared by the tabs.
class MobileHeader extends StatelessWidget {
  const MobileHeader({super.key, required this.state, required this.title});

  final AppState state;
  final String title;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Padding(
      padding: isLandscape(context)
          ? const EdgeInsets.fromLTRB(20, 6, 12, 0)
          : const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isLandscape(context) ? 20 : 24,
                fontWeight: FontWeight.w800,
              ),
            ),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileHeader(state: state, title: 'Zapline'),
            GroupBar(state: state, selected: _group, onSelected: _select),
            const Divider(height: 1, color: ZaplineColors.line),
            Expanded(
              child: locked
                  ? LockedGroupView(state: state)
                  : list.isEmpty
                  ? const EmptyView('No channels in this group.')
                  : ListView.builder(
                      controller: _scroll,
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
}
