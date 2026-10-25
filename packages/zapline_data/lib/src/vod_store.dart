part of 'database.dart';

/// Schema 3 → 4: films, series and what the user does with them.
const _vodMigration = [
  '''
  CREATE TABLE movies(
    source_id TEXT NOT NULL,
    id TEXT NOT NULL,
    sort INTEGER NOT NULL,
    name TEXT NOT NULL,
    category TEXT,
    poster TEXT,
    rating REAL,
    added INTEGER,
    ext TEXT,
    stream_url TEXT,
    PRIMARY KEY(source_id, id)
  ) WITHOUT ROWID''',
  'CREATE INDEX movies_by_category ON movies(category, sort)',
  'CREATE INDEX movies_by_added ON movies(added)',
  '''
  CREATE TABLE shows(
    source_id TEXT NOT NULL,
    id TEXT NOT NULL,
    sort INTEGER NOT NULL,
    name TEXT NOT NULL,
    category TEXT,
    cover TEXT,
    backdrop TEXT,
    rating REAL,
    plot TEXT,
    genre TEXT,
    released TEXT,
    updated INTEGER,
    PRIMARY KEY(source_id, id)
  ) WITHOUT ROWID''',
  'CREATE INDEX shows_by_category ON shows(category, sort)',
  'CREATE INDEX shows_by_updated ON shows(updated)',
  // Playlists list episodes one by one; grouped into shows at sync.
  '''
  CREATE TABLE playlist_episodes(
    source_id TEXT NOT NULL,
    show_id TEXT NOT NULL,
    season INTEGER NOT NULL,
    number INTEGER NOT NULL,
    title TEXT NOT NULL,
    stream_url TEXT NOT NULL,
    PRIMARY KEY(source_id, show_id, season, number)
  ) WITHOUT ROWID''',
  // Raw details from the source, fetched when a title is opened.
  '''
  CREATE TABLE vod_details(
    key TEXT PRIMARY KEY,
    json TEXT NOT NULL,
    fetched INTEGER NOT NULL
  ) WITHOUT ROWID''',
  // Where the user stopped, per film or episode.
  '''
  CREATE TABLE positions(
    key TEXT PRIMARY KEY,
    position INTEGER NOT NULL,
    duration INTEGER NOT NULL,
    updated INTEGER NOT NULL
  ) WITHOUT ROWID''',
  'CREATE TABLE my_list(key TEXT PRIMARY KEY, added INTEGER NOT NULL) '
      'WITHOUT ROWID',
];

/// Where playback of a film or episode stopped.
class PlaybackPosition {
  const PlaybackPosition({
    required this.key,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final String key;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  /// Started but not finished: worth offering to resume.
  bool get resumable => progress > 0.02 && progress < 0.95;
}

/// A category of films or series with how many titles it has.
typedef VodCategory = ({String title, int count});

extension VodStore on ZaplineDatabase {
  // ------------------------------------------------------------- catalogue

  /// Replaces [sourceId]'s films, keeping their order.
  void replaceMovies(String sourceId, Iterable<Movie> movies) =>
      _transaction(() {
        _db.execute('DELETE FROM movies WHERE source_id = ?', [sourceId]);
        final insert = _db.prepare(
          'INSERT OR IGNORE INTO movies(source_id, id, sort, name, category, '
          'poster, rating, added, ext, stream_url) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        );
        try {
          var sort = 0;
          for (final m in movies) {
            insert.execute([
              sourceId,
              m.id,
              sort++,
              m.name,
              m.category,
              m.posterUrl?.toString(),
              m.rating,
              m.addedAt == null ? null : ZaplineDatabase._secs(m.addedAt!),
              m.containerExtension,
              m.streamUrl?.toString(),
            ]);
          }
        } finally {
          insert.close();
        }
      });

  /// Replaces [sourceId]'s series and, for playlists, their episodes.
  void replaceShows(
    String sourceId,
    Iterable<Show> shows, {
    Iterable<(String showId, Episode)> playlistEpisodes = const [],
  }) => _transaction(() {
    _db.execute('DELETE FROM shows WHERE source_id = ?', [sourceId]);
    _db.execute('DELETE FROM playlist_episodes WHERE source_id = ?', [
      sourceId,
    ]);
    final insert = _db.prepare(
      'INSERT OR IGNORE INTO shows(source_id, id, sort, name, category, '
      'cover, backdrop, rating, plot, genre, released, updated) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    );
    final episode = _db.prepare(
      'INSERT OR IGNORE INTO playlist_episodes(source_id, show_id, season, '
      'number, title, stream_url) VALUES (?, ?, ?, ?, ?, ?)',
    );
    try {
      var sort = 0;
      for (final s in shows) {
        insert.execute([
          sourceId,
          s.id,
          sort++,
          s.name,
          s.category,
          s.coverUrl?.toString(),
          s.backdropUrl?.toString(),
          s.rating,
          s.plot,
          s.genre,
          s.releaseDate,
          s.updatedAt == null ? null : ZaplineDatabase._secs(s.updatedAt!),
        ]);
      }
      for (final (showId, e) in playlistEpisodes) {
        episode.execute([
          sourceId,
          showId,
          e.season,
          e.number,
          e.title,
          e.streamUrl.toString(),
        ]);
      }
    } finally {
      insert.close();
      episode.close();
    }
  });

  int movieCount({String? sourceId}) => _count('movies', sourceId);
  int showCount({String? sourceId}) => _count('shows', sourceId);

  int _count(String table, String? sourceId) =>
      _db.select(
            'SELECT count(*) AS n FROM $table'
            '${sourceId == null ? '' : ' WHERE source_id = ?'}',
            [?sourceId],
          ).first['n']
          as int;

  /// Categories in the order the source lists them, with their sizes.
  /// Categories in the source's order, of one source or all of them.
  List<VodCategory> movieCategories({String? sourceId}) =>
      _categories('movies', sourceId);
  List<VodCategory> showCategories({String? sourceId}) =>
      _categories('shows', sourceId);

  List<VodCategory> _categories(String table, String? sourceId) => [
    for (final r in _db.select(
      'SELECT coalesce(category, \'\') AS c, count(*) AS n, min(sort) AS s '
      'FROM $table${sourceId == null ? '' : ' WHERE source_id = ?'} '
      'GROUP BY coalesce(category, \'\') ORDER BY s',
      [?sourceId],
    ))
      (title: r['c'] as String, count: r['n'] as int),
  ];

  /// Leaves out (source id, category) pairs.
  static String _notIn(Set<(String, String)> hidden) => hidden.isEmpty
      ? ''
      : ' AND source_id || char(31) || coalesce(category, \'\') NOT IN '
            '(${List.filled(hidden.length, '?').join(', ')})';

  /// A category filter the category index can serve ("" is "no
  /// category").
  static String _category(String? category) => switch (category) {
    null => '',
    '' => " AND (category IS NULL OR category = '')",
    _ => ' AND category = ?',
  };

  static List<String> _keys(Set<(String, String)> hidden) => [
    for (final (source, category) in hidden) '$source\u001f$category',
  ];

  /// Films, optionally of one [category], skipping the categories each
  /// source hides ([hiddenCategories], as (source id, category) pairs).
  /// [newest] orders by date added instead of the source's order.
  List<Movie> movies({
    String? category,
    Set<(String, String)> hiddenCategories = const {},
    bool newest = false,
    int limit = 1 << 30,
    int offset = 0,
  }) => [
    for (final r in _db.select(
      'SELECT * FROM movies WHERE 1'
      '${_category(category)}'
      '${_notIn(hiddenCategories)}'
      '${newest
          ? ' ORDER BY added DESC, sort'
          : category != null
          ? ' ORDER BY sort'
          : ' ORDER BY source_id, sort'}'
      ' LIMIT ? OFFSET ?',
      [
        if (category != null && category.isNotEmpty) category,
        ..._keys(hiddenCategories),
        limit,
        offset,
      ],
    ))
      _movie(r),
  ];

  List<Show> shows({
    String? category,
    Set<(String, String)> hiddenCategories = const {},
    bool newest = false,
    int limit = 1 << 30,
    int offset = 0,
  }) => [
    for (final r in _db.select(
      'SELECT * FROM shows WHERE 1'
      '${_category(category)}'
      '${_notIn(hiddenCategories)}'
      '${newest
          ? ' ORDER BY updated DESC, sort'
          : category != null
          ? ' ORDER BY sort'
          : ' ORDER BY source_id, sort'}'
      ' LIMIT ? OFFSET ?',
      [
        if (category != null && category.isNotEmpty) category,
        ..._keys(hiddenCategories),
        limit,
        offset,
      ],
    ))
      _show(r),
  ];

  static String _like(String q) =>
      '%${q.trim().replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_')}%';

  List<Movie> searchMovies(String query, {int limit = 60}) =>
      query.trim().length < 2
      ? const []
      : [
          for (final r in _db.select(
            "SELECT * FROM movies WHERE name LIKE ? ESCAPE '!' "
            'ORDER BY sort LIMIT ?',
            [_like(query), limit],
          ))
            _movie(r),
        ];

  List<Show> searchShows(String query, {int limit = 60}) =>
      query.trim().length < 2
      ? const []
      : [
          for (final r in _db.select(
            "SELECT * FROM shows WHERE name LIKE ? ESCAPE '!' "
            'ORDER BY sort LIMIT ?',
            [_like(query), limit],
          ))
            _show(r),
        ];

  Movie? movie(String sourceId, String id) {
    final r = _db.select(
      'SELECT * FROM movies WHERE source_id = ? AND id = ?',
      [sourceId, id],
    );
    return r.isEmpty ? null : _movie(r.first);
  }

  Show? show(String sourceId, String id) {
    final r = _db.select('SELECT * FROM shows WHERE source_id = ? AND id = ?', [
      sourceId,
      id,
    ]);
    return r.isEmpty ? null : _show(r.first);
  }

  /// Episodes of a playlist series, ordered.
  List<Episode> playlistEpisodes(String sourceId, String showId) => [
    for (final r in _db.select(
      'SELECT * FROM playlist_episodes WHERE source_id = ? AND show_id = ? '
      'ORDER BY season, number',
      [sourceId, showId],
    ))
      Episode(
        id: '${r['season']}x${r['number']}',
        season: r['season'] as int,
        number: r['number'] as int,
        title: r['title'] as String,
        streamUrl: Uri.parse(r['stream_url'] as String),
      ),
  ];

  Movie _movie(Row r) => Movie(
    sourceId: r['source_id'] as String,
    id: r['id'] as String,
    name: r['name'] as String,
    category: r['category'] as String?,
    posterUrl: _uri(r['poster']),
    rating: (r['rating'] as num?)?.toDouble(),
    addedAt: switch (r['added']) {
      final int s => ZaplineDatabase._time(s),
      _ => null,
    },
    containerExtension: r['ext'] as String?,
    streamUrl: _uri(r['stream_url']),
  );

  Show _show(Row r) => Show(
    sourceId: r['source_id'] as String,
    id: r['id'] as String,
    name: r['name'] as String,
    category: r['category'] as String?,
    coverUrl: _uri(r['cover']),
    backdropUrl: _uri(r['backdrop']),
    rating: (r['rating'] as num?)?.toDouble(),
    plot: r['plot'] as String?,
    genre: r['genre'] as String?,
    releaseDate: r['released'] as String?,
    updatedAt: switch (r['updated']) {
      final int s => ZaplineDatabase._time(s),
      _ => null,
    },
  );

  static Uri? _uri(Object? v) => v is String ? Uri.tryParse(v) : null;

  // --------------------------------------------------------------- details

  /// Raw details fetched for [key] ("movie:src/id", "show:src/id").
  ({String json, DateTime fetched})? vodDetails(String key) {
    final r = _db.select(
      'SELECT json, fetched FROM vod_details WHERE key = ?',
      [key],
    );
    if (r.isEmpty) return null;
    return (
      json: r.first['json'] as String,
      fetched: ZaplineDatabase._time(r.first['fetched'] as int),
    );
  }

  void saveVodDetails(String key, String json) => _db.execute(
    'INSERT OR REPLACE INTO vod_details(key, json, fetched) VALUES (?, ?, ?)',
    [key, json, ZaplineDatabase._secs(DateTime.now().toUtc())],
  );

  // ------------------------------------------------------ positions, list

  void savePosition(String key, Duration position, Duration duration) =>
      _db.execute(
        'INSERT OR REPLACE INTO positions(key, position, duration, updated) '
        'VALUES (?, ?, ?, ?)',
        [
          key,
          position.inMilliseconds,
          duration.inMilliseconds,
          ZaplineDatabase._secs(DateTime.now().toUtc()),
        ],
      );

  PlaybackPosition? position(String key) {
    final r = _db.select('SELECT * FROM positions WHERE key = ?', [key]);
    return r.isEmpty ? null : _position(r.first);
  }

  /// Positions under [prefix] ("episode:src/show/" for one series).
  List<PlaybackPosition> positions({String prefix = '', int limit = 500}) => [
    for (final r in _db.select(
      "SELECT * FROM positions WHERE key LIKE ? || '%' "
      'ORDER BY updated DESC LIMIT ?',
      [prefix, limit],
    ))
      _position(r),
  ];

  PlaybackPosition _position(Row r) => PlaybackPosition(
    key: r['key'] as String,
    position: Duration(milliseconds: r['position'] as int),
    duration: Duration(milliseconds: r['duration'] as int),
    updatedAt: ZaplineDatabase._time(r['updated'] as int),
  );

  bool inMyList(String key) =>
      _db.select('SELECT 1 FROM my_list WHERE key = ?', [key]).isNotEmpty;

  void setInMyList(String key, bool on) => on
      ? _db.execute('INSERT OR IGNORE INTO my_list(key, added) VALUES (?, ?)', [
          key,
          ZaplineDatabase._secs(DateTime.now().toUtc()),
        ])
      : _db.execute('DELETE FROM my_list WHERE key = ?', [key]);

  List<String> myList() => [
    for (final r in _db.select('SELECT key FROM my_list ORDER BY added DESC'))
      r['key'] as String,
  ];

  void _deleteVod(String sourceId) {
    for (final t in ['movies', 'shows', 'playlist_episodes']) {
      _db.execute('DELETE FROM $t WHERE source_id = ?', [sourceId]);
    }
    for (final t in ['vod_details', 'positions', 'my_list']) {
      _db.execute("DELETE FROM $t WHERE key LIKE '%:' || ? || '/%'", [
        sourceId,
      ]);
    }
  }
}
