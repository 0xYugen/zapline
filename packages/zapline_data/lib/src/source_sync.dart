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
      // Guides the user added come first: for the channels they cover they
      // are usually right where a panel's own guide is off (a time zone
      // left on summer time). Each channel takes one guide only.
      final extra = source.extraGuideUrls.map(Uri.parse).toList();
      final urls = {...extra, ...guideUrls};
      final claimed = <String>{};
      // Programmes only for the guide channels some channel could use:
      // free guides list thousands of channels nobody here watches.
      final wants = db.guideWants();
      for (final url in urls) {
        try {
          // Each guide has its own shift, set by the user.
          final shift = extra.contains(url)
              ? source.shiftOf(url.toString())
              : source.guideOffset;
          final before = Set.of(claimed);
          final r = await _importGuide(
            url,
            now,
            onProgress,
            guide.programmes,
            shift,
            claimed,
            wants.isEmpty ? null : wants,
          );
          // A guide the user didn't shift is lined up with the guides
          // before it, for when it is off by an hour or more. (An unchanged
          // guide was lined up when it was imported.)
          if (shift == Duration.zero && r.starts.isNotEmpty) {
            db.alignGuide(r.starts, before, now: now);
          }
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
    db.maintain();
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
      final categories = await client.vodCategories();
      final names = {for (final c in categories) c.id: c.name};
      final list = await _byCategory(
        categories,
        (id) => client.vodStreams(categoryId: id),
        (v) => v.categoryId,
        (v) => v.streamId < 0
            ? null
            : Movie(
                sourceId: sourceId,
                id: '${v.streamId}',
                name: v.name,
                category: names[v.categoryId],
                posterUrl: url(v.iconUrl),
                rating: readRating(v.rating),
                addedAt: v.addedAt,
                containerExtension: v.containerExtension,
              ),
      );
      db.replaceMovies(sourceId, list);
      // Already stored; nothing for the caller to write.
      movies = null;
    } on Exception {
      movies = null;
    }
    try {
      final categories = await client.seriesCategories();
      final names = {for (final c in categories) c.id: c.name};
      shows = await _byCategory(
        categories,
        (id) => client.series(categoryId: id),
        (v) => v.categoryId,
        (v) => v.seriesId < 0
            ? null
            : Show(
                sourceId: sourceId,
                id: '${v.seriesId}',
                name: v.name,
                category: names[v.categoryId],
                coverUrl: url(v.coverUrl),
                backdropUrl: url(v.backdropUrl),
                rating: readRating(v.rating),
                plot: v.plot,
                genre: v.genre,
                releaseDate: v.releaseDate,
                updatedAt: v.lastModified,
              ),
      );
    } on Exception {
      shows = null;
    }
    return (movies, shows);
  }

  /// A panel's films or series asked for one category at a time, one
  /// after the other: a list of 100k films comes as one JSON answer of
  /// tens of megabytes, decoded whole in memory on a TV stick; a category
  /// at a time only one category's answer is held, as it is turned into
  /// [T]s. Falls back to the whole list in one go when the panel has no
  /// categories, fails on one, or ignores the category asked for (some
  /// send everything every time).
  Future<List<T>> _byCategory<R, T extends Object>(
    List<XtreamCategory> categories,
    Future<List<R>> Function(String? categoryId) fetch,
    String? Function(R) categoryOf,
    T? Function(R) convert,
  ) async {
    List<T> all(List<R> raw) => [for (final r in raw) ?convert(r)];
    if (categories.isEmpty) return all(await fetch(null));
    final out = <T>[];
    try {
      for (final c in categories) {
        final raw = await fetch(c.id);
        // A film can be in more than one category, listed under another
        // as its own; most of them from elsewhere means the category was
        // ignored.
        final elsewhere = raw.where((r) => categoryOf(r) != c.id).length;
        if (raw.length > 1 && elsewhere * 2 > raw.length) {
          return all(await fetch(null));
        }
        out.addAll(all(raw));
      }
    } on Exception {
      return all(await fetch(null));
    }
    return out;
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
    // Like the guides: one more try on a busy server, and no waiting for
    // ever on one that stopped sending.
    final res = await _sendRetrying(uri);
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
    Set<String> claimed,
    GuideWants? wants,
  ) async {
    onProgress?.call(
      SyncProgress(SyncStage.guide, count: offset, message: url.host),
    );
    // The same guide, imported lately with the same settings: ask the
    // server whether it changed, and keep what is there when it didn't.
    // Which channels are wanted is part of it: a guide imported for other
    // channels has to come again.
    final params =
        '${guidePast.inMinutes}/${guideAhead.inMinutes}/${shift.inMinutes}'
        '${wants == null ? '' : '/${wants.fingerprint}'}';
    final known = db.guideFeed(url.toString());
    final usable =
        known != null &&
        known.params == params &&
        (known.etag != null || known.lastModified != null) &&
        now.difference(known.fetchedAt) < _unchangedFor &&
        known.ids.every((id) => !claimed.contains(id)) &&
        db.guideHasProgrammes(known.ids, now);
    final res = await _sendRetrying(
      url,
      headers: {
        if (usable && known.etag != null) 'If-None-Match': known.etag!,
        if (usable && known.lastModified != null)
          'If-Modified-Since': known.lastModified!,
      },
    );
    if (res.statusCode == 304 && usable) {
      claimed.addAll(known.ids);
      return GuideImportResult(
        channels: known.channels,
        programmes: known.programmes,
      );
    }
    db.forgetGuideFeed(url.toString());
    var count = offset;
    Object? failure;
    var whole = false;
    // Channels this guide has that nobody wants: only what airs around now
    // is kept for them, and another guide may still bring theirs whole.
    final unwanted = <String>{};
    final items =
        XmltvParser(
          // Widen the window by the shift so no programme is lost to it.
          from: now.subtract(guidePast).subtract(shift),
          to: now.add(guideAhead).subtract(shift),
          onComplete: () => whole = true,
          wanted: wants == null
              ? null
              : (c) {
                  if (wants(c)) return true;
                  unwanted.add(c.id.toLowerCase());
                  return false;
                },
          around: now.subtract(shift),
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
    // A download cut short or a broken bit of XML keeps what came before
    // it; the guide only fails when nothing at all could be read.
    final safe = items.transform(
      StreamTransformer<XmltvItem, XmltvItem>.fromHandlers(
        handleError: (e, st, sink) {
          failure ??= e;
          sink.close();
        },
      ),
    );
    final r = await db.importGuide(safe, claimed: claimed, now: now);
    claimed.removeAll(unwanted);
    if (r.programmes == 0 && failure != null) throw failure!;
    // Only a guide that arrived whole is worth keeping as is next time.
    final etag = res.headers['etag'];
    final modified = res.headers['last-modified'];
    if (whole && failure == null && (etag != null || modified != null)) {
      db.saveGuideFeed(
        GuideFeed(
          url: url.toString(),
          etag: etag,
          lastModified: modified,
          params: params,
          ids: r.starts.keys.toSet().difference(unwanted),
          channels: r.channels,
          programmes: r.programmes,
          fetchedAt: now,
        ),
      );
    }
    return r;
  }

  /// How long a guide the server says is unchanged is kept without
  /// downloading it again. Past that, the window of days kept has moved on
  /// enough that the far end is worth reading again.
  static const _unchangedFor = Duration(hours: 20);

  /// Playlists and guides are big downloads from servers that are
  /// sometimes busy: one more try after a short wait, and no waiting
  /// forever on a server that stopped answering. A 304 (with [headers]
  /// asking whether the guide changed) comes back as is.
  Future<http.StreamedResponse> _sendRetrying(
    Uri url, {
    Map<String, String> headers = const {},
  }) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final res = await _send(
          url,
          headers: headers,
        ).timeout(const Duration(seconds: 30));
        if (res.statusCode == 304) return res;
        return http.StreamedResponse(
          res.stream.timeout(const Duration(seconds: 45)),
          res.statusCode,
          headers: res.headers,
        );
      } on Object catch (e) {
        final retry = switch (e) {
          SyncException(:final message) =>
            message.startsWith('HTTP 5') || message.startsWith('HTTP 429'),
          _ => true,
        };
        if (!retry || attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
  }

  Future<http.StreamedResponse> _send(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final res = await _http.send(
      http.Request('GET', uri)
        ..headers['User-Agent'] = userAgent
        ..headers.addAll(headers),
    );
    if (res.statusCode == 304 && headers.isNotEmpty) {
      await res.stream.drain<void>();
      return res;
    }
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
