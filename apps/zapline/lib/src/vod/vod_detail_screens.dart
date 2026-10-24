import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import 'vod_player_screen.dart';
import 'vod_widgets.dart';

/// Plays [movie], from where it was left unless [fromStart]. Fetches its
/// details first when not given (they hold the file type to ask for).
Future<void> playMovie(
  BuildContext context,
  AppState state,
  Movie movie, {
  MovieDetails? details,
  bool fromStart = false,
}) async {
  details ??= await state.movieDetails(movie);
  if (!context.mounted) return;
  final key = VodCatalog.movieKey(movie);
  final saved = state.positionOf(key);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VodPlayerScreen(
        state: state,
        items: [
          VodPlayable(
            key: key,
            title: cleanTitle(movie.name),
            url: state.movieUrl(movie, details),
            start: !fromStart && saved != null && saved.resumable
                ? saved.position
                : Duration.zero,
          ),
        ],
      ),
    ),
  );
}

/// The page of a film: picture, information, play or resume, My list and
/// more of the same category.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.state,
    required this.movie,
  });

  final AppState state;
  final Movie movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late final Future<MovieDetails?> _details = widget.state.movieDetails(
    widget.movie,
  );

  Future<void> _play(MovieDetails? d, {bool fromStart = false}) async {
    await playMovie(
      context,
      widget.state,
      widget.movie,
      details: d,
      fromStart: fromStart,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = VodTitle.movie(widget.movie);
    return Scaffold(
      body: FutureBuilder<MovieDetails?>(
        future: _details,
        builder: (context, snap) {
          final d = snap.data;
          final loading = snap.connectionState != ConnectionState.done;
          final saved = widget.state.positionOf(title.key);
          return _DetailPage(
            state: widget.state,
            title: title,
            backdrop: d?.backdropUrl,
            poster: d?.posterUrl ?? title.poster,
            meta: [
              if (title.year != null) '${title.year}',
              if (d?.duration case final t? when t > Duration.zero)
                context.l10n.runtime(t),
              if (d?.genre case final g? when g.isNotEmpty) g,
            ],
            rating: d?.rating ?? title.rating,
            plot: d?.plot,
            director: d?.director,
            cast: d?.cast,
            loading: loading,
            primary: _PlayButton(
              resume: saved != null && saved.resumable ? saved : null,
              label: context.l10n.play,
              onPlay: () => _play(d),
              onStartOver: () => _play(d, fromStart: true),
            ),
            below: [_MoreLikeThis(state: widget.state, title: title)],
          );
        },
      ),
    );
  }
}

/// The page of a series: information, the episode to continue, seasons and
/// their episodes with progress.
class ShowDetailScreen extends StatefulWidget {
  const ShowDetailScreen({super.key, required this.state, required this.show});

  final AppState state;
  final Show show;

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> {
  late Future<ShowDetails> _details = widget.state.showDetails(widget.show);
  int? _season;

  void _retry() => setState(() {
    _details = widget.state.showDetails(widget.show);
  });

  /// The episode to offer: the last one watched, or the one after it when
  /// it was finished, or the very first.
  (Episode, PlaybackPosition?)? _upNext(
    ShowDetails d,
    Map<String, PlaybackPosition> positions,
  ) {
    if (d.episodes.isEmpty) return null;
    PlaybackPosition? latest;
    for (final p in positions.values) {
      if (latest == null || p.updatedAt.isAfter(latest.updatedAt)) latest = p;
    }
    if (latest == null) return (d.episodes.first, null);
    final i = d.episodes.indexWhere((e) => positions[e.id] == latest);
    if (i < 0) return (d.episodes.first, null);
    if (latest.resumable) return (d.episodes[i], latest);
    if (latest.progress >= 0.95 && i + 1 < d.episodes.length) {
      return (d.episodes[i + 1], null);
    }
    return (d.episodes[i], latest);
  }

  Future<void> _play(ShowDetails d, Episode e, {bool fromStart = false}) async {
    final state = widget.state;
    final show = widget.show;
    final from = d.episodes.indexOf(e);
    final positions = state.episodePositions(show);
    final l = context.l10n;
    final items = [
      for (final ep in d.episodes.skip(from))
        VodPlayable(
          key: VodCatalog.episodeKey(show, ep),
          title: cleanTitle(show.name),
          subtitle:
              '${l.episodeCode(ep.season, ep.number)} · ${_episodeTitle(ep)}',
          url: state.episodeUrl(show, ep),
          start: ep == e && !fromStart && (positions[ep.id]?.resumable ?? false)
              ? positions[ep.id]!.position
              : Duration.zero,
        ),
    ];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VodPlayerScreen(state: state, items: items),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = VodTitle.show(widget.show);
    final l = context.l10n;
    return Scaffold(
      body: FutureBuilder<ShowDetails>(
        future: _details,
        builder: (context, snap) {
          final d = snap.data;
          final loading = snap.connectionState != ConnectionState.done;
          final positions = widget.state.episodePositions(widget.show);
          final next = d == null ? null : _upNext(d, positions);
          final seasons = d?.seasons ?? const <int>[];
          final season = seasons.contains(_season)
              ? _season!
              : next?.$1.season ?? seasons.firstOrNull;
          return _DetailPage(
            state: widget.state,
            title: title,
            backdrop: d?.backdropUrl ?? widget.show.backdropUrl,
            poster: d?.coverUrl ?? title.poster,
            meta: [
              if (title.year != null) '${title.year}',
              if (seasons.isNotEmpty)
                seasons.length == 1
                    ? l.seasonNumber(seasons.single)
                    : l.seasonCount(seasons.length),
              if ((d?.genre ?? widget.show.genre) case final g?
                  when g.isNotEmpty)
                g,
            ],
            rating: d?.rating ?? title.rating,
            plot: d?.plot ?? widget.show.plot,
            director: d?.director,
            cast: d?.cast,
            loading: loading,
            primary: switch (next) {
              (final e, final p) => _PlayButton(
                resume: p != null && p.resumable ? p : null,
                label: p != null && p.resumable
                    ? l.continueEpisode(e.season, e.number)
                    : l.playEpisode(e.season, e.number),
                onPlay: () => _play(d!, e),
                onStartOver: () => _play(d!, e, fromStart: true),
              ),
              null => null,
            },
            below: [
              if (snap.hasError && d == null)
                _Message(l.detailsUnavailable, onRetry: _retry)
              else if (d != null && d.episodes.isEmpty)
                _Message(l.noEpisodes)
              else if (d != null && season != null) ...[
                if (seasons.length > 1)
                  _SeasonPills(
                    seasons: seasons,
                    names: d.seasonNames,
                    selected: season,
                    onSelected: (s) {
                      HapticFeedback.selectionClick();
                      setState(() => _season = s);
                    },
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                    child: Text(
                      d.seasonNames[season] ?? l.seasonNumber(season),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                for (final e in d.inSeason(season))
                  _EpisodeRow(
                    episode: e,
                    position: positions[e.id],
                    fallbackImage: d.backdropUrl ?? title.poster,
                    onTap: () => _play(d, e),
                  ),
              ],
              _MoreLikeThis(state: widget.state, title: title),
            ],
          );
        },
      ),
    );
  }
}

String _episodeTitle(Episode e) {
  // Panels often repeat the series name and code in the title.
  final t = e.title
      .replaceFirst(RegExp(r'^.*?[Ss]\d{1,2}\s*[Ee]\d{1,3}\s*[-:.]?\s*'), '')
      .trim();
  return t.isEmpty ? e.title : t;
}

/// The layout both detail pages share.
class _DetailPage extends StatelessWidget {
  const _DetailPage({
    required this.state,
    required this.title,
    required this.backdrop,
    required this.poster,
    required this.meta,
    required this.rating,
    required this.plot,
    required this.director,
    required this.cast,
    required this.loading,
    required this.primary,
    required this.below,
  });

  final AppState state;
  final VodTitle title;
  final Uri? backdrop;
  final Uri? poster;
  final List<String> meta;
  final double? rating;
  final String? plot;
  final String? director;
  final String? cast;
  final bool loading;
  final Widget? primary;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > 720 && size.height > 600;
    // A phone held sideways has little height: a thin picture, small poster.
    final short = size.height < 500;
    final posterWidth = wide ? 170.0 : (short ? 96.0 : 112.0);
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: posterWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), blurRadius: 18),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Poster(url: poster, title: title.name),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: wide ? 30 : 22,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (rating != null && rating! > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: ZaplineColors.focus,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  for (final m in meta)
                    Text(
                      m,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ZaplineColors.textMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final backdropHeight = (size.height * 0.3).clamp(
      90.0,
      wide ? 300.0 : 220.0,
    );
    final top = MediaQuery.paddingOf(context).top;
    // The picture scrolls away with the page; the back button stays.
    final page = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              SizedBox(
                height: backdropHeight + top,
                width: double.infinity,
                child: Backdrop(
                  url: backdrop ?? poster,
                  blur: backdrop == null,
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: top + backdropHeight - posterWidth * 0.75,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: header,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ?primary,
                            if (primary == null && loading)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: ZaplineColors.focus,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            ListenableBuilder(
                              listenable: state,
                              builder: (context, _) {
                                final inList = state.inMyList(title.key);
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      state.toggleMyList(title.key);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ZaplineColors.text,
                                      side: const BorderSide(
                                        color: ZaplineColors.line,
                                      ),
                                      textStyle: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    icon: Icon(
                                      inList
                                          ? Icons.check_rounded
                                          : Icons.add_rounded,
                                      color: inList ? ZaplineColors.ok : null,
                                    ),
                                    label: Text(
                                      inList ? l.inMyList : l.addToMyList,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (plot case final p?
                                when p.trim().isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _Plot(text: p.trim()),
                            ],
                            if (director case final d? when d.trim().isNotEmpty)
                              _Credit(label: l.director, value: d.trim()),
                            if (cast case final c? when c.trim().isNotEmpty)
                              _Credit(label: l.cast, value: c.trim()),
                            if (loading && plot == null)
                              const Padding(
                                padding: EdgeInsets.only(top: 14),
                                child: LinearProgressIndicator(
                                  minHeight: 2,
                                  color: ZaplineColors.focus,
                                  backgroundColor: ZaplineColors.line,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: below,
          ),
        ),
      ],
    );
    return Stack(
      children: [
        page,
        Positioned(
          top: top + 6,
          left: 8,
          child: IconButton(
            tooltip: l.back,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x80000000),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.resume,
    required this.label,
    required this.onPlay,
    required this.onStartOver,
  });

  /// Where to resume from, when partly watched.
  final PlaybackPosition? resume;
  final String label;
  final VoidCallback onPlay;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = resume;
    final text = r == null
        ? label
        : label == l.play
        ? '${l.resume} · ${l.timeLeft(r.duration - r.position)}'
        : label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                autofocus: true,
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: ZaplineColors.focus,
                  foregroundColor: ZaplineColors.onFocus,
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
                label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (r != null) ...[
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: l.startOver,
                style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  backgroundColor: ZaplineColors.surfaceHigh,
                  foregroundColor: ZaplineColors.text,
                ),
                onPressed: onStartOver,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ],
        ),
        if (r != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: r.progress,
                minHeight: 3,
                color: ZaplineColors.focus,
                backgroundColor: ZaplineColors.line,
              ),
            ),
          ),
      ],
    );
  }
}

/// The plot, four lines until tapped.
class _Plot extends StatefulWidget {
  const _Plot({required this.text});

  final String text;

  @override
  State<_Plot> createState() => _PlotState();
}

class _PlotState extends State<_Plot> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => setState(() => _open = !_open),
    child: AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: Text(
        widget.text,
        maxLines: _open ? null : 4,
        overflow: _open ? null : TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14.5, height: 1.45),
      ),
    ),
  );
}

class _Credit extends StatelessWidget {
  const _Credit({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(color: ZaplineColors.textMuted),
          ),
          TextSpan(text: value),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13.5),
    ),
  );
}

class _SeasonPills extends StatelessWidget {
  const _SeasonPills({
    required this.seasons,
    required this.names,
    required this.selected,
    required this.onSelected,
  });

  final List<int> seasons;
  final Map<int, String> names;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      itemCount: seasons.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final s = seasons[i];
        final on = s == selected;
        return ChoiceChip(
          label: Text(names[s] ?? context.l10n.seasonNumber(s)),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => onSelected(s),
          selectedColor: ZaplineColors.focus,
          backgroundColor: ZaplineColors.surfaceHigh,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          labelStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: on ? ZaplineColors.onFocus : ZaplineColors.text,
          ),
        );
      },
    ),
  );
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.position,
    required this.fallbackImage,
    required this.onTap,
  });

  final Episode episode;
  final PlaybackPosition? position;
  final Uri? fallbackImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = episode;
    final p = position;
    final watched = p != null && p.progress >= 0.95;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Poster(
                        url: e.imageUrl ?? fallbackImage,
                        title: '${e.number}',
                      ),
                      const ColoredBox(color: Color(0x33000000)),
                      Center(
                        child: Icon(
                          watched
                              ? Icons.check_circle_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 30,
                          color: watched
                              ? ZaplineColors.ok
                              : const Color(0xE6FFFFFF),
                        ),
                      ),
                      if (p != null && p.progress > 0.02 && !watched)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: LinearProgressIndicator(
                            value: p.progress,
                            minHeight: 3,
                            color: ZaplineColors.focus,
                            backgroundColor: const Color(0x99000000),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.number}. ${_episodeTitle(e)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (e.duration case final d? when d > Duration.zero)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        context.l10n.runtime(d),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ZaplineColors.textMuted,
                        ),
                      ),
                    ),
                  if (e.plot case final plot? when plot.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        plot.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: ZaplineColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(color: ZaplineColors.textMuted)),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
      ],
    ),
  );
}

/// Other titles of the same category.
class _MoreLikeThis extends StatelessWidget {
  const _MoreLikeThis({required this.state, required this.title});

  final AppState state;
  final VodTitle title;

  @override
  Widget build(BuildContext context) {
    final category = title.category;
    if (category == null) return const SizedBox.shrink();
    final others = title.isMovie
        ? [
            for (final m in state.movies(category: category, limit: 21))
              if (m.id != title.movie!.id) VodTitle.movie(m),
          ]
        : [
            for (final s in state.shows(category: category, limit: 21))
              if (s.id != title.show!.id) VodTitle.show(s),
          ];
    if (others.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: VodRow(
        title: context.l10n.moreLikeThis,
        itemCount: others.length,
        itemBuilder: (context, i) => PosterCard(
          title: others[i],
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => others[i].isMovie
                  ? MovieDetailScreen(state: state, movie: others[i].movie!)
                  : ShowDetailScreen(state: state, show: others[i].show!),
            ),
          ),
        ),
      ),
    );
  }
}
