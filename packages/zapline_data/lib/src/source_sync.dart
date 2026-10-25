import 'dart:async';
import 'dart:io' show gzip;

import 'package:http/http.dart' as http;
import 'package:zapline_core/zapline_core.dart';

import 'database.dart';
import 'source_record.dart';

enum SyncStage { channels, guide, linking, done }

class SyncProgress {
  const SyncProgress(this.stage, {this.count = 0, this.message});

  final SyncStage stage;

  /// Items processed so far in [stage] (channels, then programmes).
  final int count;
  final String? message;

  @override
  String toString() => '${stage.name} $count ${message ?? ''}'.trim();
}

class SyncResult {
  const SyncResult({
    required this.channels,
    required this.guide,
    required this.coverage,
    this.guideErrors = const [],
    this.movies = 0,
    this.shows = 0,
  });

  final int channels;

  /// Films and series in the source's catalogue.
  final int movies;
  final int shows;
  final GuideImportResult guide;
  final GuideCoverage coverage;

  /// Guides that failed to download or parse; channels still synced.
  final List<String> guideErrors;
}

class SyncException implements Exception {
  SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads a source's channels and guides into a [ZaplineDatabase].
///
/// Guides are kept for [guidePast] back and [guideAhead] forward; anything
/// outside that window is dropped while parsing, so even very large XMLTV
/// files stay within a bounded memory and disk budget.
class SourceSync {
  SourceSync(
    this.db, {
    http.Client? httpClient,
    this.guidePast = const Duration(days: 1),
    this.guideAhead = const Duration(days: 7),
  }) : _http = httpClient ?? http.Client();

  final ZaplineDatabase db;
  final Duration guidePast;
  final Duration guideAhead;
  final http.Client _http;

  static const userAgent = XtreamClient.defaultUserAgent;

  Future<SyncResult> sync(
    SourceRecord source, {
    bool includeGuide = true,
    void Function(SyncProgress)? onProgress,
  }) async {
    onProgress?.call(const SyncProgress(SyncStage.channels));
    final fetched = switch (source.kind) {
      SourceKind.xtream => await _xtream(source),
      SourceKind.m3u => await _m3u(source),
      SourceKind.stalker => throw SyncException(
        'Stalker portals are not supported yet',
      ),
    };
    final _Fetched(:channels, :guideUrls, :offset) = fetched;
    if (!fetched.written) db.replaceChannels(source.id, channels);
    // A catalogue that failed to load keeps the previous one.
    if (fetched.movies case final movies?) {
      db.replaceMovies(source.id, movies);
    }
    if (fetched.shows case final shows?) {
      db.replaceShows(
        source.id,
        shows,
        playlistEpisodes: fetched.playlistEpisodes,
      );
    }
    db.applyGroupVisibility(source.id, source.groupFilter);
    final channelCount = fetched.written
        ? db.channelCount(sourceId: source.id)
        : channels.length;
    onProgress?.call(SyncProgress(SyncStage.channels, count: channelCount));

    var guide = const GuideImportResult(channels: 0, programmes: 0);
    final errors = <String>[];
    if (includeGuide) {
      final now = DateTime.now().toUtc();
      final urls = {...guideUrls, ...source.extraGuideUrls.map(Uri.parse)};
      // Each guide channel's coming programmes are replaced once per sync.
      final replaced = <String>{};
      for (final url in urls) {
        try {
          final r = await _importGuide(
            url,
            now,
            onProgress,
            guide.programmes,
            source.guideOffset,
            replaced,
          );
          guide = GuideImportResult(
            channels: guide.channels + r.channels,
            programmes: guide.programmes + r.programmes,
          );
        } catch (e) {
          errors.add(redactSecrets('${url.host}: $e'));
        }
      }
      db.pruneProgrammes(now.subtract(guidePast));
    }

    onProgress?.call(const SyncProgress(SyncStage.linking));
    final coverage = db.rebuildGuideLinks();
    db.markSynced(source.id, DateTime.now().toUtc(), serverOffset: offset);
    onProgress?.call(SyncProgress(SyncStage.done, count: coverage.matched));
    return SyncResult(
      channels: channelCount,
      guide: guide,
      coverage: coverage,
      guideErrors: errors,
      movies: db.movieCount(sourceId: source.id),
      shows: db.showCount(sourceId: source.id),
    );
  }

  Future<_Fetched> _xtream(SourceRecord s) async {
    final client = XtreamClient(credentialsOf(s), httpClient: _http);
    final XtreamAccount account;
    try {
      account = await client.authenticate();
    } on XtreamException catch (e) {
      throw SyncException(e.message);
    }
    if (!account.isActive) {
      throw SyncException('Account status: ${account.status}');
    }
    final categories = {
      for (final c in await client.liveCategories()) c.id: c.name,
    };
    final ext = account.preferredLiveExtension;
    final channels = [
      for (final st in await client.liveStreams())
        if (st.streamId >= 0)
          Channel(
            sourceId: s.id,
            id: '${st.streamId}',
            name: st.name,
            number: st.number,
            // Stored without the account's credentials (see
            // hideCredentials); they go back in when the stream opens.
            streamUrl: hideCredentials(
              client.liveUrl(st.streamId, extension: ext),
              s.username,
              s.password,
            ),
            groupTitle: categories[st.categoryId],
            logoUrl: (st.iconUrl == null || st.iconUrl!.isEmpty)
                ? null
                : Uri.tryParse(st.iconUrl!),
            epgChannelId: st.epgChannelId,
            catchup: st.hasArchive
                ? CatchupInfo(mode: CatchupMode.xtream, days: st.archiveDays)
                : null,
            httpHeaders: const {'User-Agent': userAgent},
          ),
    ];
    // Written now, so the big catalogue lists below don't share memory
    // with the channel list on small devices.
    db.replaceChannels(s.id, channels);
    final (movies, shows) = await _xtreamCatalogue(client, s.id);
    return _Fetched(
      channels: const [],
      written: true,
      guideUrls: [client.xmltvUrl],
      offset: account.serverUtcOffset,
      movies: movies,
      shows: shows,
    );
  }

  /// Films and series; `null` for a list the panel failed to send, so a
  /// flaky panel doesn't wipe the catalogue.
  Future<(List<Movie>?, List<Show>?)> _xtreamCatalogue(
    XtreamClient client,
    String sourceId,
  ) async {
    Uri? url(String? s) => s == null || s.isEmpty ? null : Uri.tryParse(s);
    List<Movie>? movies;
    List<Show>? shows;
    try {
      final categories = {
        for (final c in await client.vodCategories()) c.id: c.name,
      };
      db.replaceMovies(sourceId, [
        for (final v in await client.vodStreams())
          if (v.streamId >= 0)
            Movie(
              sourceId: sourceId,
              id: '${v.streamId}',
              name: v.name,
              category: categories[v.categoryId],
              posterUrl: url(v.iconUrl),
              rating: readRating(v.rating),
              addedAt: v.addedAt,
              containerExtension: v.containerExtension,
            ),
      ]);
      // Already stored; nothing for the caller to write.
      movies = null;
    } on Exception {
      movies = null;
    }
    try {
      final categories = {
        for (final c in await client.seriesCategories()) c.id: c.name,
      };
      shows = [
        for (final v in await client.series())
          if (v.seriesId >= 0)
            Show(
              sourceId: sourceId,
              id: '${v.seriesId}',
              name: v.name,
              category: categories[v.categoryId],
              coverUrl: url(v.coverUrl),
              backdropUrl: url(v.backdropUrl),
              rating: readRating(v.rating),
              plot: v.plot,
              genre: v.genre,
              releaseDate: v.releaseDate,
              updatedAt: v.lastModified,
            ),
      ];
    } on Exception {
      shows = null;
    }
    return (movies, shows);
  }

  /// Where and how to log in to an Xtream source.
  static XtreamCredentials credentialsOf(SourceRecord s) {
    final u = Uri.parse(s.url.contains('://') ? s.url : 'http://${s.url}');
    return XtreamCredentials(
      baseUrl: Uri(
        scheme: u.scheme,
        host: u.host,
        port: u.hasPort ? u.port : null,
      ),
      username: s.username,
      password: s.password,
    );
  }

  Future<_Fetched> _m3u(SourceRecord s) async {
    final uri = Uri.tryParse(s.url);
    if (uri == null || !uri.hasScheme) throw SyncException('Not a valid URL');
    final res = await _send(uri);
    final parser = M3uParser();
    final channels = <Channel>[];
    final movies = <Movie>[];
    final shows = <String, Show>{};
    final episodes = <(String, Episode)>[];
    // Panels' playlists carry the account in every stream address.
    final creds = s.username.isNotEmpty && s.password.isNotEmpty
        ? (s.username, s.password)
        : credentialsInLink(s.url);
    var i = 0;
    await for (final e in parser.parseBytes(res.stream)) {
      final raw = Uri.tryParse(e.url);
      if (raw == null) continue;
      final stream = creds == null
          ? raw
          : hideCredentials(raw, creds.$1, creds.$2);
      i++;
      final logo = e.tvgLogo == null ? null : Uri.tryParse(e.tvgLogo!);
      // Films and episodes are not channels.
      final kind = classifyM3uEntry(e);
      final ep = kind == M3uKind.episode ? parseEpisodeName(e.title) : null;
      if (ep != null) {
        final id = ep.show.toLowerCase();
        shows.putIfAbsent(
          id,
          () => Show(
            sourceId: s.id,
            id: id,
            name: ep.show,
            category: e.group,
            coverUrl: logo,
          ),
        );
        episodes.add((
          id,
          Episode(
            id: '${ep.season}x${ep.episode}',
            season: ep.season,
            number: ep.episode,
            title: e.title,
            streamUrl: stream,
          ),
        ));
        continue;
      }
      if (kind != M3uKind.live) {
        movies.add(
          Movie(
            sourceId: s.id,
            id: '$i',
            name: e.title,
            category: e.group,
            posterUrl: logo,
            streamUrl: stream,
          ),
        );
        continue;
      }
      channels.add(
        Channel(
          sourceId: s.id,
          id: '$i',
          name: e.title,
          number: e.tvgChno ?? i,
          streamUrl: stream,
          groupTitle: e.group,
          logoUrl: e.tvgLogo == null ? null : Uri.tryParse(e.tvgLogo!),
          epgChannelId: e.tvgId,
          catchup: _m3uCatchup(e),
          httpHeaders: e.httpHeaders,
        ),
      );
    }
    if (channels.isEmpty && movies.isEmpty && shows.isEmpty) {
      throw SyncException('The playlist contains no channels');
    }
    return _Fetched(
      channels: channels,
      guideUrls: parser.header.epgUrls,
      movies: movies,
      shows: shows.values.toList(),
      playlistEpisodes: episodes,
    );
  }

  static CatchupInfo? _m3uCatchup(M3uEntry e) {
    final mode = switch (e.catchup?.toLowerCase()) {
      null => null,
      'default' => CatchupMode.defaultMode,
      'append' => CatchupMode.append,
      'shift' || 'timeshift' => CatchupMode.shift,
      'flussonic' ||
      'flussonic-hls' ||
      'flussonic-ts' ||
      'fs' => CatchupMode.flussonic,
      'xc' => CatchupMode.xtream,
      'vod' => CatchupMode.vod,
      _ => null,
    };
    if (mode == null) return null;
    return CatchupInfo(
      mode: mode,
      days: e.catchupDays,
      source: e.catchupSource,
    );
  }

  Future<GuideImportResult> _importGuide(
    Uri url,
    DateTime now,
    void Function(SyncProgress)? onProgress,
    int offset,
    Duration shift,
    Set<String> replaced,
  ) async {
    onProgress?.call(
      SyncProgress(SyncStage.guide, count: offset, message: url.host),
    );
    final res = await _send(url);
    var count = offset;
    final items =
        XmltvParser(
          // Widen the window by the shift so no programme is lost to it.
          from: now.subtract(guidePast).subtract(shift),
          to: now.add(guideAhead).subtract(shift),
        ).parseBytes(_maybeGunzip(res.stream)).map((item) {
          if (item is! XmltvProgramme) return item;
          if (++count % 2000 == 0) {
            onProgress?.call(
              SyncProgress(SyncStage.guide, count: count, message: url.host),
            );
          }
          return shift == Duration.zero
              ? item
              : XmltvProgramme(item.programme.shifted(shift));
        });
    return db.importGuide(items, replaced: replaced, now: now);
  }

  Future<http.StreamedResponse> _send(Uri uri) async {
    final res = await _http.send(
      http.Request('GET', uri)..headers['User-Agent'] = userAgent,
    );
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      throw SyncException('HTTP ${res.statusCode} from ${uri.host}');
    }
    return res;
  }

  /// Guides are often served as `.xml.gz`, sometimes without a matching
  /// Content-Encoding, so detect gzip by its magic bytes instead.
  ///
  /// Written as async generators so pausing the consumer (a slow parser on
  /// a low-end device) pauses the download instead of buffering it.
  static Stream<List<int>> _maybeGunzip(Stream<List<int>> bytes) async* {
    final it = StreamIterator(bytes);
    List<int>? first;
    while (await it.moveNext()) {
      if (it.current.isNotEmpty) {
        first = it.current;
        break;
      }
    }
    if (first == null) return;
    final head = first;

    Stream<List<int>> all() async* {
      yield head;
      while (await it.moveNext()) {
        yield it.current;
      }
    }

    final isGzip = head.length >= 2 && head[0] == 0x1f && head[1] == 0x8b;
    yield* isGzip ? gzip.decoder.bind(all()) : all();
  }
}

/// What a source sent: channels, guide links and its catalogue.
class _Fetched {
  const _Fetched({
    required this.channels,
    required this.guideUrls,
    this.offset,
    this.written = false,
    this.movies,
    this.shows,
    this.playlistEpisodes = const [],
  });

  final List<Channel> channels;
  final List<Uri> guideUrls;
  final Duration? offset;

  /// The channels are already in the database.
  final bool written;
  final List<Movie>? movies;
  final List<Show>? shows;
  final List<(String, Episode)> playlistEpisodes;
}
