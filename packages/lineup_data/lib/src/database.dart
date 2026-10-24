import 'dart:convert';

import 'package:lineup_core/lineup_core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'source_record.dart';

const _schemaVersion = 2;

/// Migrations from version N to N+1, applied in order.
const _migrations = <List<String>>[
  // 1 → 2: favourites.
  [
    '''
    CREATE TABLE favourites(
      channel_key TEXT PRIMARY KEY,
      added_at INTEGER NOT NULL
    ) WITHOUT ROWID''',
  ],
];

/// Version 1 schema; later versions are reached through [_migrations].
const _schema = [
  '''
  CREATE TABLE sources(
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    name TEXT NOT NULL,
    config TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    synced_at INTEGER
  )''',
  // rowid table so the FTS index can use it as external content.
  '''
  CREATE TABLE channels(
    source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    id TEXT NOT NULL,
    sort INTEGER NOT NULL,
    number INTEGER,
    name TEXT NOT NULL,
    group_title TEXT,
    logo TEXT,
    stream_url TEXT NOT NULL,
    epg_id TEXT,
    catchup_mode TEXT,
    catchup_days INTEGER,
    catchup_source TEXT,
    headers TEXT,
    UNIQUE(source_id, id)
  )''',
  'CREATE INDEX channels_by_group ON channels(source_id, group_title, sort)',
  '''
  CREATE VIRTUAL TABLE channels_fts USING fts5(
    name, content='channels', content_rowid='rowid',
    tokenize='unicode61 remove_diacritics 2', prefix='2 3'
  )''',
  '''
  CREATE TRIGGER channels_ai AFTER INSERT ON channels BEGIN
    INSERT INTO channels_fts(rowid, name) VALUES (new.rowid, new.name);
  END''',
  '''
  CREATE TRIGGER channels_ad AFTER DELETE ON channels BEGIN
    INSERT INTO channels_fts(channels_fts, rowid, name)
      VALUES ('delete', old.rowid, old.name);
  END''',
  '''
  CREATE TABLE guide_channels(
    guide_id TEXT PRIMARY KEY,
    names TEXT NOT NULL,
    icon TEXT
  ) WITHOUT ROWID''',
  // Times are unix seconds, UTC. Keyed for "one channel, a time range".
  '''
  CREATE TABLE programmes(
    guide_id TEXT NOT NULL,
    start INTEGER NOT NULL,
    stop INTEGER NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT,
    episode TEXT,
    icon TEXT,
    PRIMARY KEY(guide_id, start)
  ) WITHOUT ROWID''',
  '''
  CREATE TABLE epg_map(
    channel_key TEXT PRIMARY KEY,
    guide_id TEXT NOT NULL,
    kind TEXT NOT NULL
  ) WITHOUT ROWID''',
  '''
  CREATE TABLE epg_overrides(
    channel_key TEXT PRIMARY KEY,
    guide_id TEXT NOT NULL
  ) WITHOUT ROWID''',
];

/// Result of a guide import.
class GuideImportResult {
  const GuideImportResult({required this.channels, required this.programmes});

  final int channels;
  final int programmes;

  @override
  String toString() => '$channels guide channels, $programmes programmes';
}

/// Channel ↔ guide coverage, shown on the sources screen.
class GuideCoverage {
  const GuideCoverage({required this.channels, required this.matched});

  final int channels;
  final int matched;

  double get ratio => channels == 0 ? 0 : matched / channels;
}

/// Local store for sources, channels and the TV guide.
///
/// Synchronous by design (SQLite via FFI is fast); run heavy imports on a
/// background isolate with its own connection to the same file.
class LineupDatabase {
  LineupDatabase._(this._db) {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA synchronous = NORMAL');
    _migrate();
  }

  factory LineupDatabase.open(String path) =>
      LineupDatabase._(sqlite3.open(path));

  factory LineupDatabase.inMemory() => LineupDatabase._(sqlite3.openInMemory());

  final Database _db;

  void close() => _db.close();

  void _migrate() {
    var v = _db.userVersion;
    if (v == _schemaVersion) return;
    if (v > _schemaVersion) {
      throw StateError('Database version $v is newer than this app');
    }
    _transaction(() {
      if (v == 0) {
        for (final sql in _schema) {
          _db.execute(sql);
        }
        v = 1;
      }
      for (; v < _schemaVersion; v++) {
        for (final sql in _migrations[v - 1]) {
          _db.execute(sql);
        }
      }
      _db.userVersion = _schemaVersion;
    });
  }

  T _transaction<T>(T Function() body) {
    _db.execute('BEGIN');
    try {
      final r = body();
      _db.execute('COMMIT');
      return r;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  static int _secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;
  static DateTime _time(int s) =>
      DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

  static String channelKey(Channel c) => '${c.sourceId}/${c.id}';

  // ---------------------------------------------------------------- sources

  void saveSource(SourceRecord s) {
    _db.execute(
      '''INSERT INTO sources(id, kind, name, config, created_at, synced_at)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           kind = excluded.kind, name = excluded.name,
           config = excluded.config, synced_at = excluded.synced_at''',
      [
        s.id,
        s.kind.name,
        s.name,
        jsonEncode(s.toConfigJson()),
        _secs(DateTime.now()),
        s.syncedAt == null ? null : _secs(s.syncedAt!),
      ],
    );
  }

  List<SourceRecord> sources() => [
    for (final r in _db.select(
      'SELECT id, kind, name, config, synced_at FROM sources ORDER BY created_at',
    ))
      SourceRecord.fromRow(
        id: r['id'] as String,
        kind: r['kind'] as String,
        name: r['name'] as String,
        config: r['config'] as String,
        syncedAt: r['synced_at'] as int?,
      ),
  ];

  void deleteSource(String id) => _transaction(() {
    _db.execute("DELETE FROM epg_map WHERE channel_key LIKE ? || '/%'", [id]);
    _db.execute("DELETE FROM favourites WHERE channel_key LIKE ? || '/%'", [
      id,
    ]);
    _db.execute('DELETE FROM sources WHERE id = ?', [id]);
  });

  // --------------------------------------------------------------- channels

  /// Replaces every channel of [sourceId] in one transaction.
  void replaceChannels(String sourceId, Iterable<Channel> channels) {
    _transaction(() {
      _db.execute('DELETE FROM channels WHERE source_id = ?', [sourceId]);
      final insert = _db.prepare('''
        INSERT OR IGNORE INTO channels(source_id, id, sort, number, name,
          group_title, logo, stream_url, epg_id, catchup_mode, catchup_days,
          catchup_source, headers)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''');
      try {
        var sort = 0;
        for (final c in channels) {
          insert.execute([
            sourceId,
            c.id,
            sort++,
            c.number,
            c.name,
            c.groupTitle,
            c.logoUrl?.toString(),
            c.streamUrl.toString(),
            c.epgChannelId,
            c.catchup?.mode.name,
            c.catchup?.days,
            c.catchup?.source,
            c.httpHeaders.isEmpty ? null : jsonEncode(c.httpHeaders),
          ]);
        }
      } finally {
        insert.close();
      }
    });
  }

  static const _channelCols =
      'source_id, id, number, name, group_title, logo, stream_url, epg_id, '
      'catchup_mode, catchup_days, catchup_source, headers';

  static Channel _channel(Row r) {
    final mode = r['catchup_mode'] as String?;
    final headers = r['headers'] as String?;
    return Channel(
      sourceId: r['source_id'] as String,
      id: r['id'] as String,
      number: r['number'] as int?,
      name: r['name'] as String,
      groupTitle: r['group_title'] as String?,
      logoUrl: switch (r['logo'] as String?) {
        final l? => Uri.tryParse(l),
        null => null,
      },
      streamUrl: Uri.parse(r['stream_url'] as String),
      epgChannelId: r['epg_id'] as String?,
      catchup: mode == null
          ? null
          : CatchupInfo(
              mode: CatchupMode.values.byName(mode),
              days: r['catchup_days'] as int?,
              source: r['catchup_source'] as String?,
            ),
      httpHeaders: headers == null
          ? const {}
          : (jsonDecode(headers) as Map).cast<String, String>(),
    );
  }

  /// Channels in source order, optionally filtered by group.
  List<Channel> channels({String? sourceId, String? group}) {
    final where = <String>[];
    final args = <Object?>[];
    if (sourceId != null) {
      where.add('source_id = ?');
      args.add(sourceId);
    }
    if (group != null) {
      where.add('group_title = ?');
      args.add(group);
    }
    final sql =
        'SELECT $_channelCols FROM channels '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY (SELECT created_at FROM sources s WHERE s.id = source_id), sort';
    return [for (final r in _db.select(sql, args)) _channel(r)];
  }

  int channelCount({String? sourceId}) =>
      _db.select(
            'SELECT count(*) AS n FROM channels'
            '${sourceId == null ? '' : ' WHERE source_id = ?'}',
            [?sourceId],
          ).first['n']
          as int;

  /// Distinct groups in first-seen order.
  List<String> groups({String? sourceId}) => [
    for (final r in _db.select(
      'SELECT group_title FROM channels WHERE group_title IS NOT NULL'
      '${sourceId == null ? '' : ' AND source_id = ?'} '
      'GROUP BY group_title ORDER BY min(sort)',
      [?sourceId],
    ))
      r['group_title'] as String,
  ];

  /// Prefix search on channel names, accent-insensitive.
  List<Channel> search(String query, {int limit = 50}) {
    final terms = query
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*')
        .join(' ');
    if (terms.isEmpty) return const [];
    return [
      for (final r in _db.select(
        'SELECT ${_channelCols.split(', ').map((c) => 'c.$c').join(', ')} '
        'FROM channels_fts f JOIN channels c ON c.rowid = f.rowid '
        'WHERE channels_fts MATCH ? ORDER BY rank LIMIT ?',
        [terms, limit],
      ))
        _channel(r),
    ];
  }

  // ------------------------------------------------------------- favourites

  /// Favourite channels in the order they were added. Favourites survive a
  /// re-sync as long as the source keeps the same channel ids.
  List<Channel> favourites() => [
    for (final r in _db.select(
      'SELECT ${_channelCols.split(', ').map((c) => 'c.$c').join(', ')} '
      'FROM favourites f JOIN channels c '
      "ON f.channel_key = c.source_id || '/' || c.id ORDER BY f.added_at",
    ))
      _channel(r),
  ];

  Set<String> favouriteKeys() => {
    for (final r in _db.select('SELECT channel_key FROM favourites'))
      r['channel_key'] as String,
  };

  void setFavourite(Channel c, bool favourite) {
    if (favourite) {
      // A counter rather than a clock: consecutive adds can share a tick.
      _db.execute(
        'INSERT OR IGNORE INTO favourites(channel_key, added_at) '
        'VALUES (?, (SELECT coalesce(max(added_at), 0) + 1 FROM favourites))',
        [channelKey(c)],
      );
    } else {
      _db.execute('DELETE FROM favourites WHERE channel_key = ?', [
        channelKey(c),
      ]);
    }
  }

  // ------------------------------------------------------------------ guide

  /// Streams a parsed guide into the database in batched transactions.
  /// Programmes are upserted, so several guides can be layered.
  Future<GuideImportResult> importGuide(
    Stream<XmltvItem> items, {
    int batchSize = 5000,
  }) async {
    final upsertChannel = _db.prepare(
      'INSERT OR REPLACE INTO guide_channels(guide_id, names, icon) '
      'VALUES (?, ?, ?)',
    );
    final upsertProgramme = _db.prepare(
      'INSERT OR REPLACE INTO programmes(guide_id, start, stop, title, '
      'description, category, episode, icon) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    );
    var channels = 0, programmes = 0, inBatch = 0;
    var open = false;
    try {
      await for (final item in items) {
        if (!open) {
          _db.execute('BEGIN');
          open = true;
        }
        switch (item) {
          case XmltvChannel c:
            upsertChannel.execute([
              c.id,
              c.displayNames.join('\n'),
              c.iconUrl?.toString(),
            ]);
            channels++;
          case XmltvProgramme(:final programme):
            final p = programme;
            upsertProgramme.execute([
              p.channelId,
              _secs(p.start),
              _secs(p.stop),
              p.title,
              p.description,
              p.category,
              p.episode,
              p.iconUrl?.toString(),
            ]);
            programmes++;
        }
        if (++inBatch >= batchSize) {
          _db.execute('COMMIT');
          open = false;
          inBatch = 0;
        }
      }
      if (open) _db.execute('COMMIT');
    } catch (_) {
      if (open) _db.execute('ROLLBACK');
      rethrow;
    } finally {
      upsertChannel.close();
      upsertProgramme.close();
    }
    return GuideImportResult(channels: channels, programmes: programmes);
  }

  /// Drops programmes that ended before [before].
  int pruneProgrammes(DateTime before) {
    _db.execute('DELETE FROM programmes WHERE stop < ?', [_secs(before)]);
    return _db.updatedRows;
  }

  List<XmltvChannel> guideChannels() => [
    for (final r in _db.select(
      'SELECT guide_id, names, icon FROM guide_channels',
    ))
      XmltvChannel(
        id: r['guide_id'] as String,
        displayNames: (r['names'] as String)
            .split('\n')
            .where((n) => n.isNotEmpty)
            .toList(),
        iconUrl: switch (r['icon'] as String?) {
          final i? => Uri.tryParse(i),
          null => null,
        },
      ),
  ];

  void setGuideOverride(Channel c, String? guideId) {
    if (guideId == null) {
      _db.execute('DELETE FROM epg_overrides WHERE channel_key = ?', [
        channelKey(c),
      ]);
    } else {
      _db.execute('INSERT OR REPLACE INTO epg_overrides VALUES (?, ?)', [
        channelKey(c),
        guideId,
      ]);
    }
  }

  /// Recomputes which guide channel each source channel uses.
  GuideCoverage rebuildGuideLinks() {
    final overrides = {
      for (final r in _db.select(
        'SELECT channel_key, guide_id FROM epg_overrides',
      ))
        r['channel_key'] as String: r['guide_id'] as String,
    };
    final matcher = ChannelMatcher(guideChannels(), manualOverrides: overrides);
    final all = channels();
    var matched = 0;
    _transaction(() {
      _db.execute('DELETE FROM epg_map');
      final insert = _db.prepare('INSERT INTO epg_map VALUES (?, ?, ?)');
      try {
        for (final c in all) {
          final key = channelKey(c);
          final m = matcher.match(c, channelKey: key);
          if (m == null) continue;
          insert.execute([key, m.guideChannelId, m.kind.name]);
          matched++;
        }
      } finally {
        insert.close();
      }
    });
    return GuideCoverage(channels: all.length, matched: matched);
  }

  /// Channels with no guide link, in source order.
  List<Channel> unmatchedChannels({String? sourceId}) => [
    for (final r in _db.select(
      'SELECT ${_channelCols.split(', ').map((c) => 'c.$c').join(', ')} '
      'FROM channels c LEFT JOIN epg_map m '
      "ON m.channel_key = c.source_id || '/' || c.id "
      'WHERE m.guide_id IS NULL'
      '${sourceId == null ? '' : ' AND c.source_id = ?'} ORDER BY c.sort',
      [?sourceId],
    ))
      _channel(r),
  ];

  GuideCoverage guideCoverage({String? sourceId}) {
    final r = _db.select(
      'SELECT count(*) AS n, count(m.guide_id) AS m FROM channels c '
      "LEFT JOIN epg_map m ON m.channel_key = c.source_id || '/' || c.id"
      '${sourceId == null ? '' : ' WHERE c.source_id = ?'}',
      [?sourceId],
    ).first;
    return GuideCoverage(channels: r['n'] as int, matched: r['m'] as int);
  }

  /// Programmes overlapping [from, to) for each channel, keyed by
  /// [channelKey]. Channels without a guide are absent.
  Map<String, List<Programme>> guide(
    Iterable<Channel> channels,
    DateTime from,
    DateTime to,
  ) {
    final keys = [for (final c in channels) channelKey(c)];
    if (keys.isEmpty) return const {};
    final out = <String, List<Programme>>{};
    const chunk = 500; // stay below SQLite's bound-parameter limit
    for (var i = 0; i < keys.length; i += chunk) {
      final part = keys.sublist(
        i,
        i + chunk > keys.length ? keys.length : i + chunk,
      );
      final rows = _db.select(
        'SELECT m.channel_key, p.guide_id, p.start, p.stop, p.title, '
        'p.description, p.category, p.episode, p.icon '
        'FROM epg_map m JOIN programmes p ON p.guide_id = m.guide_id '
        'WHERE m.channel_key IN (${List.filled(part.length, '?').join(',')}) '
        'AND p.stop > ? AND p.start < ? ORDER BY m.channel_key, p.start',
        [...part, _secs(from), _secs(to)],
      );
      for (final r in rows) {
        (out[r['channel_key'] as String] ??= []).add(
          Programme(
            channelId: r['guide_id'] as String,
            start: _time(r['start'] as int),
            stop: _time(r['stop'] as int),
            title: r['title'] as String,
            description: r['description'] as String?,
            category: r['category'] as String?,
            episode: r['episode'] as String?,
            iconUrl: switch (r['icon'] as String?) {
              final i? => Uri.tryParse(i),
              null => null,
            },
          ),
        );
      }
    }
    return out;
  }

  /// The programme airing at [at] and the one after it.
  (Programme?, Programme?) nowNext(Channel c, DateTime at) {
    final list =
        guide([c], at, at.add(const Duration(hours: 12)))[channelKey(c)] ??
        const [];
    final now = list.where((p) => p.isAiringAt(at)).firstOrNull;
    final next = list
        .where((p) => !p.start.isBefore(now?.stop ?? at))
        .firstOrNull;
    return (now, next);
  }
}
