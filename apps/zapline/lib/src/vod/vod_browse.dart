import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../screens/search_screen.dart' show SearchScope;
import '../mobile/mobile_home.dart';
import '../mobile/mobile_widgets.dart';
import '../layout.dart';
import '../theme.dart';
import 'vod_detail_screens.dart';
import 'vod_widgets.dart';

enum VodKind { movies, shows }

/// Films or series as a page of their own (TV and desktop, where the
/// channel list is the home screen).
class VodScreen extends StatelessWidget {
  const VodScreen({super.key, required this.state, required this.kind});

  final AppState state;
  final VodKind kind;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: VodTab(state: state, kind: kind),
  );
}

/// Films or series: a featured title, rows to continue, My list, recently
/// added and one per category; a category or My list opens as a grid.
class VodTab extends StatefulWidget {
  const VodTab({super.key, required this.state, required this.kind});

  final AppState state;
  final VodKind kind;

  @override
  State<VodTab> createState() => _VodTabState();
}

/// Pill values besides category names.
const _home = '\u0000home';
const _myList = '\u0000mylist';

class _VodTabState extends State<VodTab> {
  String _selected = _home;
  final _scroll = ScrollController();

  bool get _movies => widget.kind == VodKind.movies;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(String v) {
    HapticFeedback.selectionClick();
    setState(() => _selected = v);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  List<VodTitle> _titles({
    String? category,
    bool newest = false,
    int limit = 1 << 30,
  }) {
    final s = widget.state;
    return _movies
        ? [
            for (final m in s.movies(
              category: category,
              newest: newest,
              limit: limit,
            ))
              VodTitle.movie(m),
          ]
        : [
            for (final x in s.shows(
              category: category,
              newest: newest,
              limit: limit,
            ))
              VodTitle.show(x),
          ];
  }

  Future<void> _openCategories(List<({String title, int count})> all) async {
    final l = context.l10n;
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                l.categories,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final (value, label, count) in [
              (_home, l.allTitles, null),
              (_myList, l.myList, null),
              for (final c in all)
                (c.title, c.title.isEmpty ? l.noGroup : c.title, c.count),
            ])
              ListTile(
                selected: value == _selected,
                selectedColor: ZaplineColors.focus,
                title: Text(label),
                trailing: count == null
                    ? null
                    : Text(
                        '$count',
                        style: const TextStyle(color: ZaplineColors.textMuted),
                      ),
                onTap: () => Navigator.of(sheet).pop(value),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _select(picked);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) {
      final l = context.l10n;
      final state = widget.state;
      final categories = _movies
          ? state.movieCategories()
          : state.showCategories();
      if (_selected != _home &&
          _selected != _myList &&
          !categories.any((c) => c.title == _selected)) {
        _selected = _home;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileHeader(
            state: state,
            title: _movies ? l.movies : l.series,
            searchScope: _movies ? SearchScope.movies : SearchScope.shows,
          ),
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    tooltip: l.categories,
                    onPressed: () => _openCategories(categories),
                    icon: const Icon(Icons.segment_rounded),
                  ),
                ),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
                    children: [
                      for (final (value, label, icon) in [
                        (_home, l.allTitles, null),
                        (_myList, l.myList, Icons.bookmark_rounded),
                        for (final c in categories.take(30))
                          (
                            c.title,
                            c.title.isEmpty ? l.noGroup : c.title,
                            null,
                          ),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Pill(
                            label: label,
                            icon: icon,
                            selected: value == _selected,
                            onTap: () => _select(value),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ZaplineColors.line),
          Expanded(
            child: switch (_selected) {
              _home => _homeView(context, categories),
              _myList => _grid(
                _movies
                    ? [for (final m in state.myMovies()) VodTitle.movie(m)]
                    : [for (final s in state.myShows()) VodTitle.show(s)],
                empty: l.myListEmpty,
              ),
              final c => _grid(_titles(category: c), empty: l.noTitles),
            },
          ),
        ],
      );
    },
  );

  Widget _grid(List<VodTitle> titles, {required String empty}) => titles.isEmpty
      ? EmptyView(empty, icon: Icons.movie_outlined)
      : PosterGrid(state: widget.state, titles: titles, controller: _scroll);

  Widget _homeView(
    BuildContext context,
    List<({String title, int count})> categories,
  ) {
    final l = context.l10n;
    final state = widget.state;
    final resume = [
      for (final c in state.continueWatching())
        if ((c.movie != null) == _movies) c,
    ];
    final mine = _movies
        ? [for (final m in state.myMovies().take(20)) VodTitle.movie(m)]
        : [for (final s in state.myShows().take(20)) VodTitle.show(s)];
    final recent = _titles(newest: true, limit: 20);
    final featured = resume.isEmpty
        ? recent.firstOrNull
        : _movies
        ? VodTitle.movie(resume.first.movie!)
        : VodTitle.show(resume.first.show!);

    final sections = <Widget Function(BuildContext)>[
      if (featured != null && MediaQuery.sizeOf(context).height > 500)
        (context) => _Featured(
          state: state,
          title: featured,
          label: resume.isEmpty ? l.recentlyAdded : l.continueWatching,
        ),
      if (resume.isNotEmpty)
        (context) => VodRow(
          title: l.continueWatching,
          itemCount: resume.length,
          itemBuilder: (context, i) {
            final c = resume[i];
            final t = c.movie != null
                ? VodTitle.movie(c.movie!)
                : VodTitle.show(c.show!);
            return PosterCard(
              title: t,
              progress: c.position.progress,
              caption: c.movie != null
                  ? l.timeLeft(c.position.duration - c.position.position)
                  : null,
              onTap: () => c.movie != null
                  ? playMovie(context, state, c.movie!)
                  : openTitle(context, state, t),
            );
          },
        ),
      if (mine.isNotEmpty)
        (context) => VodRow(
          title: l.myList,
          itemCount: mine.length,
          onSeeAll: () => _select(_myList),
          itemBuilder: (context, i) => PosterCard(
            title: mine[i],
            onTap: () => openTitle(context, state, mine[i]),
          ),
        ),
      if (recent.isNotEmpty)
        (context) => VodRow(
          title: l.recentlyAdded,
          itemCount: recent.length,
          itemBuilder: (context, i) => PosterCard(
            title: recent[i],
            onTap: () => openTitle(context, state, recent[i]),
          ),
        ),
      for (final c in categories)
        (context) {
          // Built only when scrolled near, so big catalogues stay quick.
          final titles = _titles(category: c.title, limit: 20);
          if (titles.isEmpty) return const SizedBox.shrink();
          return VodRow(
            title: c.title.isEmpty ? l.noGroup : c.title,
            itemCount: titles.length,
            onSeeAll: c.count > titles.length ? () => _select(c.title) : null,
            itemBuilder: (context, i) => PosterCard(
              title: titles[i],
              onTap: () => openTitle(context, state, titles[i]),
            ),
          );
        },
    ];
    if (sections.isEmpty) {
      return EmptyView(l.noTitles, icon: Icons.movie_outlined);
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: sections.length,
      itemBuilder: (context, i) => sections[i](context),
    );
  }
}

/// The title at the top: a big poster over its blurred picture.
class _Featured extends StatelessWidget {
  const _Featured({
    required this.state,
    required this.title,
    required this.label,
  });

  final AppState state;
  final VodTitle title;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final meta = titleMeta(title, extra: title.category);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 210,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Backdrop(
                url: title.show?.backdropUrl ?? title.poster,
                blur: title.show?.backdropUrl == null,
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => openTitle(context, state, title),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 120,
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Poster(
                                url: title.poster,
                                title: title.name,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: ZaplineColors.focus,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              if (meta.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: ZaplineColors.textMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                autofocus: FormFactor.isTv,
                                onPressed: () => title.isMovie
                                    ? playMovie(context, state, title.movie!)
                                    : openTitle(context, state, title),
                                style: FilledButton.styleFrom(
                                  backgroundColor: ZaplineColors.focus,
                                  foregroundColor: ZaplineColors.onFocus,
                                  textStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ).copyWith(side: focusRing),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(
                                  title.isMovie &&
                                          (state
                                                  .positionOf(title.key)
                                                  ?.resumable ??
                                              false)
                                      ? l.resume
                                      : l.play,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
