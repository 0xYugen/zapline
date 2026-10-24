import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zapline_core/zapline_core.dart';

import 'database.dart';
import 'source_record.dart';
import 'source_sync.dart';

/// Opens films and series: fetches their details from the source when
/// first opened (then from the cache, refreshed after a day), and builds
/// the stream URL to play.
class VodCatalog {
  VodCatalog(this.db, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final ZaplineDatabase db;
  final http.Client _http;

  static const _maxAge = Duration(days: 1);

  static String movieKey(Movie m) => 'movie:${m.sourceId}/${m.id}';
  static String showKey(Show s) => 'show:${s.sourceId}/${s.id}';
  static String episodeKey(Show s, Episode e) =>
      'episode:${s.sourceId}/${s.id}/${e.id}';

  XtreamClient _client(SourceRecord source) =>
      XtreamClient(SourceSync.credentialsOf(source), httpClient: _http);

  /// Details of [m]; `null` when the source has none (playlists) and
  /// nothing was cached. [fresh] skips the cache.
  Future<MovieDetails?> movieDetails(
    SourceRecord source,
    Movie m, {
    bool fresh = false,
  }) async {
    final key = movieKey(m);
    final cached = db.vodDetails(key);
    if (source.kind != SourceKind.xtream) return null;
    if (!fresh &&
        cached != null &&
        DateTime.now().toUtc().difference(cached.fetched) < _maxAge) {
      return parseVodInfo(jsonDecode(cached.json));
    }
    try {
      final raw = await _client(source).rawVodInfo(int.parse(m.id));
      db.saveVodDetails(key, jsonEncode(raw));
      return parseVodInfo(raw);
    } on Exception {
      // Offline or the panel failed: show what we had.
      return cached == null ? null : parseVodInfo(jsonDecode(cached.json));
    }
  }

  /// Seasons and episodes of [s]: from the source for Xtream, from the
  /// playlist for M3U.
  Future<ShowDetails> showDetails(
    SourceRecord source,
    Show s, {
    bool fresh = false,
  }) async {
    if (source.kind != SourceKind.xtream) {
      return ShowDetails(
        episodes: db.playlistEpisodes(s.sourceId, s.id),
        plot: s.plot,
        coverUrl: s.coverUrl,
      );
    }
    final key = showKey(s);
    final cached = db.vodDetails(key);
    // A series that changed since the copy was saved is fetched again.
    final stale =
        cached == null ||
        DateTime.now().toUtc().difference(cached.fetched) > _maxAge ||
        (s.updatedAt != null && s.updatedAt!.isAfter(cached.fetched));
    if (!fresh && !stale) return parseSeriesInfo(jsonDecode(cached.json));
    try {
      final raw = await _client(source).rawSeriesInfo(int.parse(s.id));
      db.saveVodDetails(key, jsonEncode(raw));
      return parseSeriesInfo(raw);
    } on Exception {
      if (cached != null) return parseSeriesInfo(jsonDecode(cached.json));
      rethrow;
    }
  }

  /// What to open to play [m].
  Uri movieUrl(SourceRecord source, Movie m, {MovieDetails? details}) =>
      m.streamUrl ??
      _client(source).movieUrl(
        int.parse(m.id),
        details?.containerExtension ?? m.containerExtension ?? 'mp4',
      );

  /// What to open to play [e].
  Uri episodeUrl(SourceRecord source, Episode e) =>
      e.streamUrl ??
      _client(
        source,
      ).episodeUrl(int.parse(e.id), e.containerExtension ?? 'mp4');

  void close() => _http.close();
}
