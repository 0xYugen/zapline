/// A film in a source's catalogue, as listed (details come separately).
class Movie {
  const Movie({
    required this.sourceId,
    required this.id,
    required this.name,
    this.category,
    this.posterUrl,
    this.rating,
    this.addedAt,
    this.containerExtension,
    this.streamUrl,
  });

  final String sourceId;

  /// Xtream stream id, or the position in an M3U playlist.
  final String id;
  final String name;
  final String? category;
  final Uri? posterUrl;

  /// 0–10 when the provider gives one.
  final double? rating;
  final DateTime? addedAt;
  final String? containerExtension;

  /// Set for playlist (M3U) films; Xtream builds it from the id.
  final Uri? streamUrl;

  /// The year in names like "Title (2019)" or "Title - 2019".
  int? get year {
    final m = RegExp(r'[\(\[\s-](19\d\d|20\d\d)[\)\]]?\s*$').firstMatch(name);
    return m == null ? null : int.parse(m.group(1)!);
  }
}

/// A series in a source's catalogue, as listed.
class Show {
  const Show({
    required this.sourceId,
    required this.id,
    required this.name,
    this.category,
    this.coverUrl,
    this.backdropUrl,
    this.rating,
    this.plot,
    this.genre,
    this.releaseDate,
    this.updatedAt,
  });

  final String sourceId;
  final String id;
  final String name;
  final String? category;
  final Uri? coverUrl;
  final Uri? backdropUrl;
  final double? rating;
  final String? plot;
  final String? genre;
  final String? releaseDate;
  final DateTime? updatedAt;
}

/// Everything known about a film once opened.
class MovieDetails {
  const MovieDetails({
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.duration,
    this.rating,
    this.posterUrl,
    this.backdropUrl,
    this.trailer,
    this.containerExtension,
  });

  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final Duration? duration;
  final double? rating;
  final Uri? posterUrl;
  final Uri? backdropUrl;

  /// A YouTube video id or URL.
  final String? trailer;
  final String? containerExtension;
}

/// One episode of a series.
class Episode {
  const Episode({
    required this.id,
    required this.season,
    required this.number,
    required this.title,
    this.containerExtension,
    this.plot,
    this.duration,
    this.imageUrl,
    this.streamUrl,
  });

  /// Xtream episode id (used in its stream URL).
  final String id;
  final int season;
  final int number;
  final String title;
  final String? containerExtension;
  final String? plot;
  final Duration? duration;
  final Uri? imageUrl;

  /// Set for playlist (M3U) episodes.
  final Uri? streamUrl;
}

/// A series once opened: its information, seasons and episodes.
class ShowDetails {
  const ShowDetails({
    required this.episodes,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.coverUrl,
    this.backdropUrl,
    this.trailer,
    this.seasonNames = const {},
  });

  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final double? rating;
  final Uri? coverUrl;
  final Uri? backdropUrl;
  final String? trailer;

  /// Season number → its name when the provider gives one.
  final Map<int, String> seasonNames;

  /// Every episode, ordered by season then number.
  final List<Episode> episodes;

  List<int> get seasons =>
      {for (final e in episodes) e.season}.toList()..sort();

  List<Episode> inSeason(int season) => [
        for (final e in episodes)
          if (e.season == season) e
      ];
}
