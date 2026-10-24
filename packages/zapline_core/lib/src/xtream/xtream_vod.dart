import '../models/vod.dart';
import 'xtream_models.dart';

// Xtream panels describe films and series with loosely typed JSON: numbers
// as strings, lists or maps for the same field, empty strings for "none".

double? readRating(Object? v) {
  final d = switch (v) {
    num n => n.toDouble(),
    String s => double.tryParse(s.trim().replaceAll(',', '.')),
    _ => null,
  };
  // Some panels use 0–5, most 0–10; 0 means "no rating".
  if (d == null || d <= 0) return null;
  return d > 10 ? d / 10 : d;
}

Uri? readUrl(Object? v) {
  final s = switch (v) {
    List<Object?> l when l.isNotEmpty => readString(l.first),
    _ => readString(v),
  };
  if (s == null) return null;
  final u = Uri.tryParse(s.trim());
  return u != null && u.hasScheme && u.host.isNotEmpty ? u : null;
}

Duration? _readDuration(Map<Object?, Object?> info) {
  final secs = readInt(info['duration_secs']);
  if (secs != null && secs > 0) return Duration(seconds: secs);
  // "01:52:10" or "112 min".
  final d = readString(info['duration']);
  if (d == null) return null;
  final hms = RegExp(r'^(\d+):(\d\d)(?::(\d\d))?$').firstMatch(d.trim());
  if (hms != null) {
    final a = int.parse(hms.group(1)!), b = int.parse(hms.group(2)!);
    final c = hms.group(3);
    return c == null
        ? Duration(hours: a, minutes: b)
        : Duration(hours: a, minutes: b, seconds: int.parse(c));
  }
  final min = RegExp(r'(\d+)\s*min').firstMatch(d);
  return min == null ? null : Duration(minutes: int.parse(min.group(1)!));
}

String? _clean(Object? v) {
  final s = readString(v)?.trim();
  return s == null || s.isEmpty || s == 'N/A' ? null : s;
}

/// `get_vod_info`.
MovieDetails parseVodInfo(Object? json) {
  final data = json is Map ? json : const {};
  final info = data['info'] is Map ? data['info'] as Map : const {};
  final movie =
      data['movie_data'] is Map ? data['movie_data'] as Map : const {};
  return MovieDetails(
    plot: _clean(info['plot'] ?? info['description']),
    cast: _clean(info['cast'] ?? info['actors']),
    director: _clean(info['director']),
    genre: _clean(info['genre']),
    releaseDate: _clean(info['releasedate'] ?? info['release_date']),
    duration: _readDuration(info),
    rating: readRating(info['rating']),
    posterUrl: readUrl(info['movie_image'] ?? info['cover_big']),
    backdropUrl: readUrl(info['backdrop_path']),
    trailer: _clean(info['youtube_trailer']),
    containerExtension: _clean(movie['container_extension']),
  );
}

/// `get_series_info`.
ShowDetails parseSeriesInfo(Object? json) {
  final data = json is Map ? json : const {};
  final info = data['info'] is Map ? data['info'] as Map : const {};
  final names = <int, String>{};
  if (data['seasons'] case final List<Object?> seasons) {
    for (final s in seasons) {
      if (s is! Map) continue;
      final n = readInt(s['season_number']);
      final name = _clean(s['name']);
      if (n != null && name != null) names[n] = name;
    }
  }
  // Episodes come as {"1": [...], "2": [...]} or as one flat list.
  final raw = data['episodes'];
  final lists = switch (raw) {
    Map<Object?, Object?> m => [
        for (final v in m.values)
          if (v is List<Object?>) v
      ],
    List<Object?> l => [l],
    _ => const <List<Object?>>[],
  };
  final episodes = <Episode>[];
  for (final list in lists) {
    for (final e in list) {
      if (e is! Map) continue;
      final id = readString(e['id']);
      if (id == null) continue;
      final epInfo = e['info'] is Map ? e['info'] as Map : const {};
      episodes.add(
        Episode(
          id: id,
          season: readInt(e['season']) ?? 1,
          number: readInt(e['episode_num']) ?? episodes.length + 1,
          title: _clean(e['title']) ?? '',
          containerExtension: _clean(e['container_extension']),
          plot: _clean(epInfo['plot']),
          duration: _readDuration(epInfo),
          imageUrl: readUrl(epInfo['movie_image']),
        ),
      );
    }
  }
  episodes.sort(
    (a, b) => a.season != b.season
        ? a.season.compareTo(b.season)
        : a.number.compareTo(b.number),
  );
  return ShowDetails(
    plot: _clean(info['plot']),
    cast: _clean(info['cast']),
    director: _clean(info['director']),
    genre: _clean(info['genre']),
    releaseDate: _clean(info['releaseDate'] ?? info['release_date']),
    rating: readRating(info['rating']),
    coverUrl: readUrl(info['cover']),
    backdropUrl: readUrl(info['backdrop_path']),
    trailer: _clean(info['youtube_trailer']),
    seasonNames: names,
    episodes: episodes,
  );
}
