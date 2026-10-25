import 'dart:convert';

import 'package:zapline_core/zapline_core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'source_record.dart';

part 'vod_store.dart';

const _schemaVersion = 7;

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
  // 2 -> 3: group and channel preferences, recents, settings.
  [
    // hidden: NULL follows the source's filter, 0/1 is the user's choice.
    // effective_hidden is the resolved value, kept for fast queries.
    '''
    CREATE TABLE group_prefs(
      source_id TEXT NOT NULL,
      group_title TEXT NOT NULL,
      hidden INTEGER,
      locked INTEGER NOT NULL DEFAULT 0,
      effective_hidden INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(source_id, group_title)
    ) WITHOUT ROWID''',
    'CREATE TABLE hidden_channels(channel_key TEXT PRIMARY KEY) WITHOUT ROWID',
    '''
    CREATE TABLE recents(
      channel_key TEXT PRIMARY KEY,
      watched_at INTEGER NOT NULL
    ) WITHOUT ROWID''',
    '''
    CREATE TABLE settings(
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    ) WITHOUT ROWID''',
  ],
  // 3 -> 4: films and series (vod_store.dart).
  _vodMigration,
  // 4 -> 5: finding the guide that airs a programme at a given time.
  ['CREATE INDEX IF NOT EXISTS programmes_start ON programmes(start)'],
  // 5 -> 6: lookups by channel key ("source/id"), guide links by guide,
  // films and series in a source's order.
  [
    "CREATE INDEX IF NOT EXISTS channels_key ON channels(source_id || '/' || id)",
    'CREATE INDEX IF NOT EXISTS epg_map_guide ON epg_map(guide_id)',
    'CREATE INDEX IF NOT EXISTS movies_by_source ON movies(source_id, sort)',
    'CREATE INDEX IF NOT EXISTS shows_by_source ON shows(source_id, sort)',
  ],
  // 6 -> 7: guide channel ids are stored in lower case, so the same
  // channel in two guides ("Rai1.it", "rai1.it") is one channel. Guides
  // are downloaded again on the next sync.
  [
    "UPDATE epg_overrides SET guide_id = lower(guide_id) "
        "WHERE guide_id NOT LIKE 'xc/%'",
    "DELETE FROM programmes WHERE guide_id NOT LIKE 'xc/%'",
    "DELETE FROM guide_channels WHERE guide_id NOT LIKE 'xc/%'",
    "DELETE FROM epg_map WHERE kind != 'source'",
  ],
];

/// A group of one source with the user's preferences, for the manage
/// screen.
class GroupInfo {
  const GroupInfo({
    required this.title,
    required this.channels,
    required this.hidden,
    required this.explicit,
    required this.locked,
  });

  final String title;
  final int channels;

  /// Whether the group is currently hidden (by the user or the filter).
  final bool hidden;

  /// The user's own choice, `null` when the filter decides.
  final bool? explicit;
  final bool locked;
}

/// Which channels a query returns.
class ChannelVisibility {
  const ChannelVisibility({this.hidden = false, this.locked = false});

  /// Include channels in hidden groups and hidden channels.
  final bool hidden;

  /// Include channels in locked groups (after the parental PIN).
  final bool locked;

  static const visible = ChannelVisibility();
  static const unlocked = ChannelVisibility(locked: true);
  static const all = ChannelVisibility(hidden: true, locked: true);
}

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
  const GuideImportResult({
    required this.channels,
    required this.programmes,
    this.starts = const {},
  });

  /// Earliest programme start (unix seconds) of each guide channel taken.
  final Map<String, int> starts;

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
class ZaplineDatabase {
  ZaplineDatabase._(this._db) {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA synchronous = NORMAL');
    // The sync isolate writes while the app reads and saves small things:
    // wait for it a little instead of failing at once.
    _db.execute('PRAGMA busy_timeout = 3000');
    _migrate();
  }

  factory ZaplineDatabase.open(String path) =>
      ZaplineDatabase._(sqlite3.open(path));

  factory ZaplineDatabase.inMemory() =>
      ZaplineDatabase._(sqlite3.openInMemory());

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

  /// Records a finished sync without rewriting the rest of the source (in
  /// particular without ever writing a password that lives elsewhere).
  void markSynced(String id, DateTime at, {Duration? serverOffset}) {
    final row = _db.select('SELECT config FROM sources WHERE id = ?', [id]);
    if (row.isEmpty) return;
    final config =
        jsonDecode(row.first['config'] as String) as Map<String, Object?>;
    if (serverOffset != null) config['offsetMinutes'] = serverOffset.inMinutes;
    _db.execute('UPDATE sources SET synced_at = ?, config = ? WHERE id = ?', [
      _secs(at),
      jsonEncode(config),
      id,
    ]);
  }

  void deleteSource(String id) => _transaction(() {
    _db.execute("DELETE FROM epg_map WHERE channel_key LIKE ? || '/%'", [id]);
    _db.execute("DELETE FROM epg_overrides WHERE channel_key LIKE ? || '/%'", [
      id,
    ]);
    _db.execute("DELETE FROM favourites WHERE channel_key LIKE ? || '/%'", [
      id,
    ]);
    for (final table in ['hidden_channels', 'recents']) {
      _db.execute("DELETE FROM $table WHERE channel_key LIKE ? || '/%'", [id]);
    }
    _db.execute('DELETE FROM group_prefs WHERE source_id = ?', [id]);
    _deleteVod(id);
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

  /// SQL condition keeping only channels allowed by [v]; `c` is the
  /// channels alias.
  static String _visibleSql(ChannelVisibility v) => [
    if (!v.hidden) ...[
      'NOT EXISTS (SELECT 1 FROM group_prefs g WHERE g.source_id = c.source_id '
          "AND g.group_title = coalesce(c.group_title, '') "
          'AND g.effective_hidden = 1)',
      "c.source_id || '/' || c.id NOT IN (SELECT channel_key FROM hidden_channels)",
    ],
    if (!v.locked)
      'NOT EXISTS (SELECT 1 FROM group_prefs g WHERE g.source_id = c.source_id '
          "AND g.group_title = coalesce(c.group_title, '') AND g.locked = 1)",
    '1',
  ].join(' AND ');

  static final _cols = _channelCols.split(', ').map((c) => 'c.$c').join(', ');

  /// Channels in source order, optionally filtered by source and group.
  List<Channel> channels({
    String? sourceId,
    String? group,
    ChannelVisibility visibility = ChannelVisibility.visible,
  }) {
    final where = <String>[_visibleSql(visibility)];
    final args = <Object?>[];
    if (sourceId != null) {
      where.add('c.source_id = ?');
      args.add(sourceId);
    }
    if (group != null) {
      where.add('c.group_title = ?');
      args.add(group);
    }
    final sql =
        'SELECT $_cols FROM channels c WHERE ${where.join(' AND ')} '
        'ORDER BY (SELECT created_at FROM sources s WHERE s.id = c.source_id), '
        'c.sort';
    return [for (final r in _db.select(sql, args)) _channel(r)];
  }

  int channelCount({
    String? sourceId,
    ChannelVisibility visibility = ChannelVisibility.all,
  }) =>
      _db.select(
            'SELECT count(*) AS n FROM channels c '
            'WHERE ${_visibleSql(visibility)}'
            '${sourceId == null ? '' : ' AND c.source_id = ?'}',
            [?sourceId],
          ).first['n']
          as int;

  /// Groups in first-seen order. By default hidden groups are left out and
  /// locked ones are listed (the app shows them with a lock).
  List<String> groups({
    String? sourceId,
    ChannelVisibility visibility = ChannelVisibility.unlocked,
  }) => [
    for (final r in _db.select(
      'SELECT c.group_title FROM channels c WHERE c.group_title IS NOT NULL '
      'AND ${_visibleSql(visibility)}'
      '${sourceId == null ? '' : ' AND c.source_id = ?'} '
      'GROUP BY c.group_title ORDER BY min(c.sort)',
      [?sourceId],
    ))
      r['group_title'] as String,
  ];

  /// Every group of [sourceId] with counts and preferences.
  List<GroupInfo> groupInfo(String sourceId) => [
    for (final r in _db.select(
      "SELECT coalesce(c.group_title, '') AS t, count(*) AS n, "
      'g.hidden AS h, coalesce(g.locked, 0) AS l, '
      'coalesce(g.effective_hidden, 0) AS e '
      'FROM channels c LEFT JOIN group_prefs g ON g.source_id = c.source_id '
      "AND g.group_title = coalesce(c.group_title, '') "
      'WHERE c.source_id = ? GROUP BY t ORDER BY min(c.sort)',
      [sourceId],
    ))
      GroupInfo(
        title: r['t'] as String,
        channels: r['n'] as int,
        hidden: (r['e'] as int) == 1,
        explicit: switch (r['h'] as int?) {
          null => null,
          final h => h == 1,
        },
        locked: (r['l'] as int) == 1,
      ),
  ];

  /// Recomputes which groups of [sourceId] are hidden: the user's explicit
  /// choice when there is one, otherwise [filter]. Call after a sync (new
  /// groups) and whenever the filter changes.
  void applyGroupVisibility(String sourceId, GroupFilter filter) {
    _transaction(() {
      final titles = [
        for (final r in _db.select(
          "SELECT DISTINCT coalesce(group_title, '') AS t FROM channels "
          'WHERE source_id = ?',
          [sourceId],
        ))
          r['t'] as String,
      ];
      final upsert = _db.prepare(
        'INSERT INTO group_prefs(source_id, group_title, effective_hidden) '
        'VALUES (?, ?, ?) ON CONFLICT(source_id, group_title) DO UPDATE SET '
        'effective_hidden = coalesce(group_prefs.hidden, '
        'excluded.effective_hidden)',
      );
      try {
        for (final t in titles) {
          final hide = filter.hides(t.isEmpty ? null : t);
          upsert.execute([sourceId, t, hide ? 1 : 0]);
        }
      } finally {
        upsert.close();
      }
    });
  }

  /// The user's choice for one group: `true` hide, `false` show, `null`
  /// follow the filter. Call [applyGroupVisibility] afterwards.
  void setGroupHidden(String sourceId, String group, bool? hidden) =>
      _db.execute(
        'INSERT INTO group_prefs(source_id, group_title, hidden) '
        'VALUES (?, ?, ?) ON CONFLICT(source_id, group_title) '
        'DO UPDATE SET hidden = excluded.hidden',
        [sourceId, group, hidden == null ? null : (hidden ? 1 : 0)],
      );

  void setGroupLocked(String sourceId, String group, bool locked) =>
      _db.execute(
        'INSERT INTO group_prefs(source_id, group_title, locked) '
        'VALUES (?, ?, ?) ON CONFLICT(source_id, group_title) '
        'DO UPDATE SET locked = excluded.locked',
        [sourceId, group, locked ? 1 : 0],
      );

  /// Locked group titles across sources.
  Set<String> lockedGroups() => {
    for (final r in _db.select(
      'SELECT DISTINCT group_title FROM group_prefs WHERE locked = 1',
    ))
      r['group_title'] as String,
  };

  // ------------------------------------------------------- hidden channels

  /// Hides a channel by key, e.g. while restoring a backup.
  void hideChannelKey(String channelKey) => _db.execute(
    'INSERT OR IGNORE INTO hidden_channels VALUES (?)',
    [channelKey],
  );

  void setChannelHidden(Channel c, bool hidden) => hidden
      ? _db.execute('INSERT OR IGNORE INTO hidden_channels VALUES (?)', [
          channelKey(c),
        ])
      : _db.execute('DELETE FROM hidden_channels WHERE channel_key = ?', [
          channelKey(c),
        ]);

  List<Channel> hiddenChannels({String? sourceId}) => [
    for (final r in _db.select(
      'SELECT $_cols FROM hidden_channels h JOIN channels c '
      "ON h.channel_key = c.source_id || '/' || c.id"
      '${sourceId == null ? '' : ' WHERE c.source_id = ?'} ORDER BY c.sort',
      [?sourceId],
    ))
      _channel(r),
  ];

  // ---------------------------------------------------------------- recents

  void markWatched(Channel c, {DateTime? at}) {
    _db.execute('INSERT OR REPLACE INTO recents VALUES (?, ?)', [
      channelKey(c),
      (at ?? DateTime.now()).microsecondsSinceEpoch,
    ]);
    // Keep the list short.
    _db.execute(
      'DELETE FROM recents WHERE channel_key NOT IN '
      '(SELECT channel_key FROM recents ORDER BY watched_at DESC LIMIT 50)',
    );
  }

  /// Most recently watched first.
  List<Channel> recents({
    int limit = 30,
    ChannelVisibility visibility = ChannelVisibility.visible,
  }) => [
    for (final r in _db.select(
      'SELECT $_cols FROM recents r JOIN channels c '
      "ON r.channel_key = c.source_id || '/' || c.id "
      'WHERE ${_visibleSql(visibility)} ORDER BY r.watched_at DESC LIMIT ?',
      [limit],
    ))
      _channel(r),
  ];

  // --------------------------------------------------------------- settings

  String? setting(String key) {
    final r = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  void setSetting(String key, String? value) => value == null
      ? _db.execute('DELETE FROM settings WHERE key = ?', [key])
      : _db.execute('INSERT OR REPLACE INTO settings VALUES (?, ?)', [
          key,
          value,
        ]);

  /// Prefix search on channel names, accent-insensitive.
  List<Channel> search(
    String query, {
    int limit = 50,
    ChannelVisibility visibility = ChannelVisibility.visible,
  }) {
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
        'WHERE channels_fts MATCH ? AND ${_visibleSql(visibility)} '
        'ORDER BY rank LIMIT ?',
        [terms, limit],
      ))
        _channel(r),
    ];
  }

  // ------------------------------------------------------------- favourites

  /// Favourite channels in the order they were added. Favourites survive a
  /// re-sync as long as the source keeps the same channel ids.
  /// Favourites stay visible even in hidden groups (the user chose them),
  /// but respect parental locks.
  List<Channel> favourites({
    ChannelVisibility visibility = const ChannelVisibility(hidden: true),
  }) => [
    for (final r in _db.select(
      'SELECT $_cols FROM favourites f JOIN channels c '
      "ON f.channel_key = c.source_id || '/' || c.id "
      'WHERE ${_visibleSql(visibility)} ORDER BY f.added_at',
    ))
      _channel(r),
  ];

  Set<String> favouriteKeys() => {
    for (final r in _db.select('SELECT channel_key FROM favourites'))
      r['channel_key'] as String,
  };

  /// Adds a favourite by key, e.g. while restoring a backup before the
  /// source's channels have been downloaded.
  void addFavouriteKey(String channelKey) => _db.execute(
    'INSERT OR IGNORE INTO favourites(channel_key, added_at) '
    'VALUES (?, (SELECT coalesce(max(added_at), 0) + 1 FROM favourites))',
    [channelKey],
  );

  /// Favourite keys in the order they were added.
  List<String> favouriteKeysInOrder() => [
    for (final r in _db.select(
      'SELECT channel_key FROM favourites ORDER BY added_at',
    ))
      r['channel_key'] as String,
  ];

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
  /// Imports a guide. A guide channel's programmes still to come are
  /// replaced the first time the channel shows up, so a guide republished
  /// with other times (a daylight saving change, a fix, a time shift)
  /// doesn't leave the old programmes overlapping the new ones. Past
  /// programmes stay for replay.
  ///
  /// [claimed], shared by the guides of one sync, gives each guide channel
  /// to the first guide that has it: later guides' programmes for it are
  /// skipped, so two guides with different times never mix on a channel.
  Future<GuideImportResult> importGuide(
    Stream<XmltvItem> items, {
    int batchSize = 5000,
    Set<String>? claimed,
    DateTime? now,
  }) async {
    final taken = claimed ?? <String>{};
    final mine = <String, int>{};
    final from = _secs((now ?? DateTime.now()).toUtc());
    final clear = _db.prepare(
      'DELETE FROM programmes WHERE guide_id = ? AND stop > ?',
    );
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
              c.id.toLowerCase(),
              c.displayNames.join('\n'),
              c.iconUrl?.toString(),
            ]);
            channels++;
          case XmltvProgramme(:final programme):
            final p = programme;
            // Ids compare without case: "Rai1.it" and "rai1.it" are one.
            final id = p.channelId.toLowerCase();
            final start = _secs(p.start);
            if (!mine.containsKey(id)) {
              // Another guide of this sync already has this channel.
              if (taken.contains(id)) continue;
              mine[id] = start;
              taken.add(id);
              // What this guide covers replaces what was there; older
              // programmes stay for replay.
              clear.execute([id, start < from ? start : from]);
            } else if (start < mine[id]!) {
              mine[id] = start;
            }
            upsertProgramme.execute([
              id,
              start,
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
      clear.close();
    }
    return GuideImportResult(
      channels: channels,
      programmes: programmes,
      starts: mine,
    );
  }

  /// Lines up the guide channels [ids], just imported, with the guide
  /// channels [reference] imported before them in the same sync.
  ///
  /// Free guides are sometimes an hour or more off (a time zone written
  /// wrong, summer time left on). The same titles airing on a reference
  /// guide channel at a fixed distance tell how far. A channel with a
  /// clear twin moves by its own distance (one guide can be right on some
  /// channels and off on others); the rest move by the distance most
  /// twinned channels agree on, if any. Only programmes imported this time
  /// (from each channel's earliest start in [ids]) move. Returns how many
  /// channels moved.
  int alignGuide(
    Map<String, int> ids,
    Set<String> reference, {
    DateTime? now,
  }) {
    if (ids.isEmpty || reference.isEmpty) return 0;
    final at = _secs((now ?? DateTime.now()).toUtc());
    const window = 12 * 3600, reach = 3 * 3600;
    // Titles airing on the reference channels around now.
    final known = <String, List<(String, int)>>{};
    final rows = <({String id, int start, String title})>[];
    for (final r in _db.select(
      'SELECT guide_id, start, title FROM programmes '
      'WHERE start BETWEEN ? AND ?',
      [at - window, at + window],
    )) {
      final id = r['guide_id'] as String;
      final title = _titleKey(r['title'] as String);
      if (title.length < 4) continue;
      final start = r['start'] as int;
      if (reference.contains(id)) {
        (known[title] ??= []).add((id, start));
      } else if (ids.containsKey(id)) {
        rows.add((id: id, start: start, title: title));
      }
    }
    // Per channel: the reference twin and distance most titles agree on.
    final votes = <String, Map<(String, int), int>>{};
    for (final r in rows) {
      for (final (twin, start) in known[r.title] ?? const <(String, int)>[]) {
        final delta = start - r.start;
        if (delta.abs() > reach) continue;
        // Rounded to a quarter of an hour: listings differ by a few minutes.
        final q = (delta / 900).round() * 900;
        final v = votes[r.id] ??= {};
        v[(twin, q)] = (v[(twin, q)] ?? 0) + 1;
      }
    }
    final own = <String, int>{};
    final channels = <int, int>{};
    for (final MapEntry(key: id, value: v) in votes.entries) {
      final ranked = v.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final best = ranked.first;
      if (best.value < 3) continue;
      // Two distances as likely: no clear answer for this channel.
      if (ranked.length > 1 &&
          ranked[1].value == best.value &&
          ranked[1].key.$2 != best.key.$2) {
        continue;
      }
      final delta = best.key.$2;
      own[id] = delta;
      channels[delta] = (channels[delta] ?? 0) + 1;
    }
    final twinned = own.length;
    // The guide's usual distance, for its channels without a twin.
    var usual = 0;
    if (channels.isNotEmpty) {
      final top = channels.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      if (top.value >= 2 && top.value * 10 >= twinned * 6) usual = top.key;
    }
    // Whole half hours only: a few minutes are listings rounding.
    final moves = <String, int>{
      for (final id in ids.keys)
        if (own[id] ?? usual case final d when d != 0 && d % 1800 == 0) id: d,
    };
    if (moves.isEmpty) return 0;
    _transaction(() {
      _db.execute(
        'CREATE TEMP TABLE IF NOT EXISTS moving AS '
        'SELECT * FROM programmes WHERE 0',
      );
      _db.execute('DELETE FROM moving');
      for (final MapEntry(key: id, value: move) in moves.entries) {
        final since = ids[id];
        _db.execute(
          'INSERT INTO moving SELECT guide_id, start + ?, stop + ?, title, '
          'description, category, episode, icon FROM programmes '
          'WHERE guide_id = ? AND start >= ?',
          [move, move, id, since],
        );
        _db.execute(
          'DELETE FROM programmes WHERE guide_id = ? AND start >= ?',
          [id, since],
        );
      }
      _db.execute('INSERT OR REPLACE INTO programmes SELECT * FROM moving');
      _db.execute('DELETE FROM moving');
    });
    return moves.length;
  }

  /// Stores programmes fetched for one channel from its source (Xtream's
  /// short EPG) and links the channel to them. Used when the source's
  /// XMLTV guide is missing or has nothing for the channel.
  void storeChannelGuide(Channel c, List<Programme> programmes) {
    if (programmes.isEmpty) return;
    final key = channelKey(c);
    final id = '$channelGuidePrefix$key';
    _transaction(() {
      // The source's latest answer replaces what it said before.
      _db.execute('DELETE FROM programmes WHERE guide_id = ? AND stop > ?', [
        id,
        _secs(DateTime.now().toUtc()),
      ]);
      _db.execute(
        'INSERT OR REPLACE INTO guide_channels(guide_id, names, icon) '
        'VALUES (?, ?, NULL)',
        [id, c.name],
      );
      final upsert = _db.prepare(
        'INSERT OR REPLACE INTO programmes(guide_id, start, stop, title, '
        'description) VALUES (?, ?, ?, ?, ?)',
      );
      try {
        for (final p in programmes) {
          upsert.execute([
            id,
            _secs(p.start),
            _secs(p.stop),
            p.title,
            p.description,
          ]);
        }
      } finally {
        upsert.close();
      }
      // The same programmes at the same times in a full guide: that guide
      // is the channel's, with days ahead instead of a few hours.
      final twin = _guideAiring(programmes);
      if (twin != null) {
        _db.execute('INSERT OR REPLACE INTO epg_overrides VALUES (?, ?)', [
          key,
          twin,
        ]);
        _db.execute("INSERT OR REPLACE INTO epg_map VALUES (?, ?, 'manual')", [
          key,
          twin,
        ]);
      } else {
        _db.execute("INSERT OR REPLACE INTO epg_map VALUES (?, ?, 'source')", [
          key,
          id,
        ]);
      }
    });
  }

  static final _titleNoise = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static String _titleKey(String t) =>
      t.toLowerCase().replaceAll(_titleNoise, '');

  /// The XMLTV guide channel airing the same titles at the same times as
  /// [programmes] (within five minutes), when at least two agree and no
  /// other guide channel does as well.
  String? _guideAiring(List<Programme> programmes) {
    final votes = <String, int>{};
    for (final p in programmes.take(8)) {
      final title = _titleKey(p.title);
      if (title.length < 3) continue;
      final at = _secs(p.start);
      final seen = <String>{};
      for (final r in _db.select(
        'SELECT guide_id, title FROM programmes WHERE start BETWEEN ? AND ? '
        "AND guide_id NOT LIKE '$channelGuidePrefix%'",
        [at - 300, at + 300],
      )) {
        final id = r['guide_id'] as String;
        if (_titleKey(r['title'] as String) == title && seen.add(id)) {
          votes[id] = (votes[id] ?? 0) + 1;
        }
      }
    }
    if (votes.isEmpty) return null;
    final ranked = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    if (best.value < 2) return null;
    if (ranked.length > 1 && ranked[1].value == best.value) return null;
    return best.key;
  }

  /// Rewrites stream addresses saved before Zapline stopped storing
  /// credentials: [user] and [pass] become placeholders (see
  /// hideCredentials). The next sync rewrites them anyway.
  void hideStoredCredentials(String sourceId, String user, String pass) {
    if (user.isEmpty || pass.isEmpty) return;
    String seg(String v) => Uri(pathSegments: [v]).toString();
    final from = '/${seg(user)}/${seg(pass)}/';
    final to = '/${seg(credentialUser)}/${seg(credentialPass)}/';
    _transaction(() {
      for (final table in ['channels', 'movies', 'playlist_episodes']) {
        _db.execute(
          'UPDATE $table SET stream_url = replace(stream_url, ?, ?) '
          'WHERE source_id = ? AND instr(stream_url, ?) > 0',
          [from, to, sourceId, from],
        );
      }
    });
  }

  /// Drops programmes that ended before [before].
  int pruneProgrammes(DateTime before) {
    _db.execute('DELETE FROM programmes WHERE stop < ?', [_secs(before)]);
    return _db.updatedRows;
  }

  /// Prefix of guide ids holding a single channel's programmes fetched
  /// from the source itself (see [storeChannelGuide]).
  static const channelGuidePrefix = 'xc/';

  List<XmltvChannel> guideChannels() => [
    for (final r in _db.select(
      'SELECT guide_id, names, icon FROM guide_channels '
      "WHERE guide_id NOT LIKE '$channelGuidePrefix%'",
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
        _guideKey(guideId),
      ]);
    }
  }

  Map<String, String> guideOverrides() => {
    for (final r in _db.select(
      'SELECT channel_key, guide_id FROM epg_overrides',
    ))
      r['channel_key'] as String: r['guide_id'] as String,
  };

  void setGuideOverrideKey(String channelKey, String guideId) => _db.execute(
    'INSERT OR REPLACE INTO epg_overrides VALUES (?, ?)',
    [channelKey, _guideKey(guideId)],
  );

  /// Links one channel to [guideId] by hand, at once and for good (a full
  /// [rebuildGuideLinks] would load every channel).
  void linkGuide(String channelKey, String guideId) {
    final id = _guideKey(guideId);
    _transaction(() {
      _db.execute('INSERT OR REPLACE INTO epg_overrides VALUES (?, ?)', [
        channelKey,
        id,
      ]);
      _db.execute("INSERT OR REPLACE INTO epg_map VALUES (?, ?, 'manual')", [
        channelKey,
        id,
      ]);
    });
  }

  /// Guide channel ids as stored: lower case, except the source's own
  /// per-channel guides.
  static String _guideKey(String id) =>
      id.startsWith(channelGuidePrefix) ? id : id.toLowerCase();

  /// Recomputes which guide channel each source channel uses.
  GuideCoverage rebuildGuideLinks() {
    final overrides = {
      for (final r in _db.select(
        'SELECT channel_key, guide_id FROM epg_overrides',
      ))
        r['channel_key'] as String: r['guide_id'] as String,
    };
    final matcher = ChannelMatcher(guideChannels(), manualOverrides: overrides);
    final all = channels(visibility: ChannelVisibility.all);
    // Per-channel guides from the source stay linked when no XMLTV guide
    // matches the channel.
    final fallback = {
      for (final r in _db.select(
        "SELECT channel_key, guide_id FROM epg_map WHERE kind = 'source'",
      ))
        r['channel_key'] as String: r['guide_id'] as String,
    };
    var matched = 0;
    _transaction(() {
      _db.execute('DELETE FROM epg_map');
      final insert = _db.prepare('INSERT INTO epg_map VALUES (?, ?, ?)');
      try {
        for (final c in all) {
          final key = channelKey(c);
          final m = matcher.match(c, channelKey: key);
          if (m != null) {
            insert.execute([key, _guideKey(m.guideChannelId), m.kind.name]);
          } else if (fallback[key] case final id?) {
            insert.execute([key, id, 'source']);
          } else {
            continue;
          }
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

  /// Programmes whose title contains [query] (case-insensitive) that have
  /// not ended before [from], soonest first, with the channel showing them.
  List<(Channel, Programme)> searchProgrammes(
    String query, {
    required DateTime from,
    int limit = 60,
    ChannelVisibility visibility = ChannelVisibility.visible,
  }) {
    final q = query.trim();
    if (q.length < 2) return const [];
    // LIKE wildcards in the query are literal; '!' is the escape character.
    final escaped = q
        .replaceAll('!', '!!')
        .replaceAll('%', '!%')
        .replaceAll('_', '!_');
    return [
      for (final r in _db.select(
        'SELECT $_cols, p.guide_id AS pg, p.start AS ps, p.stop AS pe, '
        'p.title AS pt, p.description AS pd, p.category AS pc, '
        'p.episode AS pep, p.icon AS pi '
        'FROM programmes p JOIN epg_map m ON m.guide_id = p.guide_id '
        "JOIN channels c ON m.channel_key = c.source_id || '/' || c.id "
        "WHERE p.title LIKE ? ESCAPE '!' AND p.stop > ? "
        'AND ${_visibleSql(visibility)} ORDER BY p.start LIMIT ?',
        ['%$escaped%', _secs(from), limit],
      ))
        (
          _channel(r),
          Programme(
            channelId: r['pg'] as String,
            start: _time(r['ps'] as int),
            stop: _time(r['pe'] as int),
            title: r['pt'] as String,
            description: r['pd'] as String?,
            category: r['pc'] as String?,
            episode: r['pep'] as String?,
            iconUrl: switch (r['pi'] as String?) {
              final i? => Uri.tryParse(i),
              null => null,
            },
          ),
        ),
    ];
  }

  /// What guide channel [guideId] airs at [at], to tell guides apart.
  Programme? airingOn(String guideId, DateTime at) {
    final r = _db.select(
      'SELECT start, stop, title FROM programmes '
      'WHERE guide_id = ? AND start <= ? AND stop > ? LIMIT 1',
      [guideId, _secs(at), _secs(at)],
    );
    if (r.isEmpty) return null;
    return Programme(
      channelId: guideId,
      start: _time(r.first['start'] as int),
      stop: _time(r.first['stop'] as int),
      title: r.first['title'] as String,
    );
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
