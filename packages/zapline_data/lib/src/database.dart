import 'dart:convert';
import 'dart:io' show sleep;

import 'package:zapline_core/zapline_core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'source_record.dart';

part 'vod_store.dart';

const _schemaVersion = 9;

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
  // 7 -> 8: a programme by its title and time, for telling which guide
  // channel airs what a provider says a channel is showing. The guides
  // are emptied first (the next sync brings them back): indexing a full
  // one would hold up the first start on a TV stick.
  [
    'DELETE FROM programmes',
    'CREATE INDEX IF NOT EXISTS programmes_title '
        'ON programmes(lower(trim(title)), start)',
  ],
  // 8 -> 9: the title index goes. Guides arrive channel by channel and
  // titles in no order, so every batch of an import touched pages all over
  // it: three quarters of the import time. The start index takes the
  // titles (and end times) instead, after the guide channel: programmes of
  // one hour still sit together, and what airs at a time, or a title
  // search, is read from the index alone. Rebuilding it over a full guide would hold up the
  // first start on a TV stick, so the guides are emptied and the sources
  // marked as due, which brings them back at once.
  // Download validators per guide address, so an unchanged guide is not
  // downloaded and imported again. Channels by group across sources.
  [
    'DROP INDEX IF EXISTS programmes_title',
    'DROP INDEX IF EXISTS programmes_start',
    'DELETE FROM programmes',
    'UPDATE sources SET synced_at = NULL',
    'CREATE INDEX IF NOT EXISTS programmes_at '
        'ON programmes(start, guide_id, title, stop)',
    '''
    CREATE TABLE IF NOT EXISTS guide_feeds(
      url TEXT PRIMARY KEY,
      etag TEXT,
      modified TEXT,
      params TEXT NOT NULL,
      ids TEXT NOT NULL,
      channels INTEGER NOT NULL,
      programmes INTEGER NOT NULL,
      fetched_at INTEGER NOT NULL
    ) WITHOUT ROWID''',
    'CREATE INDEX IF NOT EXISTS channels_by_title ON channels(group_title)',
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

enum _GuideWriteKind { channel, programme }

/// One write of a guide import, held until its batch is written.
class _GuideWrite {
  const _GuideWrite(this.kind, this.args);

  final _GuideWriteKind kind;
  final List<Object?> args;
}

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

/// A guide address as last imported: the server's validators for asking
/// whether it changed, and what the import brought.
class GuideFeed {
  const GuideFeed({
    required this.url,
    required this.params,
    required this.ids,
    required this.channels,
    required this.programmes,
    required this.fetchedAt,
    this.etag,
    this.lastModified,
  });

  final String url;

  /// The server's `ETag` and `Last-Modified` headers.
  final String? etag;
  final String? lastModified;

  /// What the import depended on besides the file (window, time shift):
  /// a change means downloading again.
  final String params;

  /// Guide channels the import took.
  final Set<String> ids;
  final int channels;
  final int programmes;
  final DateTime fetchedAt;
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
  ZaplineDatabase._(this._db, {int busyTimeoutMs = 3000}) {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA synchronous = NORMAL');
    // The sync isolate writes while the app reads and saves small things:
    // wait for it a little instead of failing at once.
    _db.execute('PRAGMA busy_timeout = $busyTimeoutMs');
    // 16 MB of page cache (the default is 2 MB): guide imports and channel
    // lists touch many pages. Sorts stay in memory, and the write-ahead log
    // is cut back after big imports instead of keeping its largest size.
    _db.execute('PRAGMA cache_size = -16384');
    _db.execute('PRAGMA temp_store = MEMORY');
    _db.execute('PRAGMA journal_size_limit = 8388608');
    // Statistics for the query planner, bounded so it stays quick.
    _db.execute('PRAGMA analysis_limit = 400');
    _migrate();
  }

  /// [busyTimeoutMs] is how long a write waits for the other connection
  /// (the sync's, or the app's) before failing with SQLITE_BUSY. The app's
  /// connection, on the UI thread, can wait less and save what fails with
  /// [tryWrite] later; a sync slice holds the lock about 200 ms (see
  /// [writeSlice]).
  factory ZaplineDatabase.open(String path, {int busyTimeoutMs = 3000}) =>
      ZaplineDatabase._(sqlite3.open(path), busyTimeoutMs: busyTimeoutMs);

  factory ZaplineDatabase.inMemory() =>
      ZaplineDatabase._(sqlite3.openInMemory());

  final Database _db;

  void close() => _db.close();

  /// Whether [e] is the database being busy (the other connection held
  /// the lock longer than the busy timeout): worth trying again later.
  static bool isBusy(Object e) =>
      e is SqliteException && (e.resultCode == 5 || e.resultCode == 6);

  /// Runs a small [write]; `false` when the database stayed busy: nothing
  /// was stored, try again later. Other errors are thrown as usual.
  bool tryWrite(void Function() write) {
    try {
      write();
      return true;
    } on SqliteException catch (e) {
      if (isBusy(e)) return false;
      rethrow;
    }
  }

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

  /// Runs [body] in a write transaction.
  ///
  /// IMMEDIATE takes the write lock at once, waiting for the other
  /// isolate's connection if it holds it. A plain BEGIN that reads before
  /// it writes fails outright (SQLITE_BUSY_SNAPSHOT) when the other
  /// connection commits in between, and the busy timeout doesn't help.
  ///
  /// A [sliced] transaction lets go of the lock at [_yieldLock] once it has
  /// held it for [writeSlice] (see there).
  T _transaction<T>(T Function() body, {bool sliced = false}) {
    // Already inside one: it commits or rolls back for both.
    if (!_db.autocommit) return body();
    _db.execute('BEGIN IMMEDIATE');
    _sliced = sliced;
    _held.reset();
    _held.start();
    try {
      final r = body();
      _db.execute('COMMIT');
      return r;
    } catch (_) {
      // A slice that could not start again has nothing to roll back.
      if (!_db.autocommit) _db.execute('ROLLBACK');
      rethrow;
    } finally {
      _sliced = false;
      _held.stop();
    }
  }

  /// How long a big write (a sync's channels, films, guide) holds the
  /// database before letting the app's connection in.
  ///
  /// The app's small writes (a favourite, a position) wait for the lock
  /// on the UI thread, so a sync's 50k-row write in one transaction is a
  /// frozen screen for seconds on a TV stick. Big writes are cut into
  /// transactions of about this long, with a short pause between them.
  /// The price: until the last slice, another connection can see the list
  /// half written (some rows new, some old, none missing in between that
  /// weren't removed from the source). The app reloads its lists once a
  /// sync is done, so at worst a screen opened during the sync shows the
  /// mix until then; nothing is lost if the sync fails midway, the next
  /// one finishes the job.
  Duration writeSlice = const Duration(milliseconds: 200);

  /// The pause between two slices. SQLite's busy handler polls every
  /// 25-50 ms in the first 200 ms of waiting, so a waiting connection
  /// gets in during it.
  Duration writeGap = const Duration(milliseconds: 50);

  bool _sliced = false;
  final _held = Stopwatch();

  /// Inside a sliced transaction (see [writeSlice]): commits what was
  /// written so far and starts again after a pause, once the lock has
  /// been held long enough. Call it between rows that can be seen apart.
  void _yieldLock() {
    if (!_sliced || _held.elapsed < writeSlice) return;
    _db.execute('COMMIT');
    if (writeGap > Duration.zero) sleep(writeGap);
    _db.execute('BEGIN IMMEDIATE');
    _held.reset();
  }

  /// Reads with [read] outside any transaction, then runs [write] with what
  /// it read in a write transaction. Big comparisons (a sync's 50k channels
  /// against the stored ones) so don't hold the write lock while reading.
  /// When another connection committed in between (the app saving a
  /// setting, most likely), [write] still goes ahead if [stamp], a cheap
  /// summary of the rows [read] reads, is unchanged; otherwise [read] runs
  /// again, outside the lock while it can. Reading 150k rows under the
  /// lock keeps the app waiting for most of a second. [write] never works
  /// from an outdated picture.
  void _readThenWrite<R>(
    R Function() read,
    void Function(R) write, {
    bool sliced = false,
    String Function()? stamp,
  }) {
    if (!_db.autocommit) return write(read());
    for (var tries = 0; ; tries++) {
      final before = _dataVersion();
      final stamped = stamp?.call();
      final data = read();
      final wrote = _transaction(() {
        if (_dataVersion() == before || (stamp != null && stamp() == stamped)) {
          write(data);
          return true;
        }
        if (tries < 3) return false;
        write(read());
        return true;
      }, sliced: sliced);
      if (wrote) return;
    }
  }

  /// A summary of [sourceId]'s rows of [table] that changes when one is
  /// added, removed or moved, for [_readThenWrite].
  String _rowsStamp(String table, String sourceId) => _db
      .select('SELECT count(*), total(sort) FROM $table WHERE source_id = ?', [
        sourceId,
      ])
      .first
      .values
      .join('/');

  /// Changes whenever another connection commits.
  int _dataVersion() =>
      _db.select('PRAGMA data_version').first.columnAt(0) as int;

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
  ///
  /// Only what changed is written: a re-sync of an unchanged list of 50k
  /// channels reads them and writes nothing, instead of deleting and
  /// inserting every row (and its search entry) while the app waits to
  /// write. When a source lists an id twice, the first one counts.
  void replaceChannels(String sourceId, Iterable<Channel> channels) =>
      _readThenWrite(
        () => _storedRows('channels', sourceId, _dataCols),
        (old) => _writeChannels(sourceId, channels, old),
        sliced: true,
        stamp: () => _rowsStamp('channels', sourceId),
      );

  /// [table]'s rows of [sourceId]: id → (sort, the values of [cols]).
  Map<String, (int, List<Object?>)> _storedRows(
    String table,
    String sourceId,
    String cols,
  ) => {
    for (final r in _db.select(
      'SELECT id, sort, $cols FROM $table WHERE source_id = ?',
      [sourceId],
    ))
      r.columnAt(0) as String: (
        r.columnAt(1) as int,
        [for (var i = 2; i < r.length; i++) r.columnAt(i)],
      ),
  };

  void _writeChannels(
    String sourceId,
    Iterable<Channel> channels,
    // Taken apart as rows are matched: what's left is gone from the source.
    Map<String, (int, List<Object?>)> old,
  ) {
    final insert = _db.prepare(
      'INSERT OR IGNORE INTO channels(source_id, id, sort, $_dataCols) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    );
    // Deleted and inserted again rather than updated: the search index
    // follows inserts and deletes.
    final delete = _db.prepare(
      'DELETE FROM channels WHERE source_id = ? AND id = ?',
    );
    final move = _db.prepare(
      'UPDATE channels SET sort = ? WHERE source_id = ? AND id = ?',
    );
    try {
      var sort = 0;
      final seen = <String>{};
      for (final c in channels) {
        final at = sort++;
        if (!seen.add(c.id)) continue;
        _yieldLock();
        final values = _channelValues(c);
        final before = old.remove(c.id);
        if (before == null) {
          insert.execute([sourceId, c.id, at, ...values]);
        } else if (!_sameValues(before.$2, values)) {
          delete.execute([sourceId, c.id]);
          insert.execute([sourceId, c.id, at, ...values]);
        } else if (before.$1 != at) {
          move.execute([at, sourceId, c.id]);
        }
      }
      for (final id in old.keys) {
        _yieldLock();
        delete.execute([sourceId, id]);
      }
    } finally {
      insert.close();
      delete.close();
      move.close();
    }
  }

  /// Channel columns besides the source, id and order, in
  /// [_channelValues]' order.
  static const _dataCols =
      'number, name, group_title, logo, stream_url, epg_id, catchup_mode, '
      'catchup_days, catchup_source, headers';

  static List<Object?> _channelValues(Channel c) => [
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
  ];

  static bool _sameValues(List<Object?> a, List<Object?> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static const _channelCols =
      'source_id, id, number, name, group_title, logo, stream_url, epg_id, '
      'catchup_mode, catchup_days, catchup_source, headers';

  static Channel _channel(Row r) {
    final mode = r['catchup_mode'] as String?;
    final headers = r['headers'] as String?;
    // Addresses are parsed when first read: most rows of a long list are
    // never shown or played.
    return StoredChannel(
      sourceId: r['source_id'] as String,
      id: r['id'] as String,
      number: r['number'] as int?,
      name: r['name'] as String,
      groupTitle: r['group_title'] as String?,
      logoUrl: r['logo'] as String?,
      streamUrl: r['stream_url'] as String,
      epgChannelId: r['epg_id'] as String?,
      catchup: mode == null
          ? null
          : CatchupInfo(
              mode: CatchupMode.values.byName(mode),
              days: r['catchup_days'] as int?,
              source: r['catchup_source'] as String?,
            ),
      httpHeaders: headers == null ? const {} : _headers(headers),
    );
  }

  /// Decoded headers by their JSON. A source's channels nearly all carry
  /// the same few (a user agent), so a list of 50k channels decodes them a
  /// handful of times instead of once per row.
  static final _headerCache = <String, Map<String, String>>{};

  static Map<String, String> _headers(String json) {
    final hit = _headerCache[json];
    if (hit != null) return hit;
    if (_headerCache.length >= 64) _headerCache.clear();
    return _headerCache[json] = Map.unmodifiable(
      (jsonDecode(json) as Map).cast<String, String>(),
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

  /// Every channel's guide channel, by [channelKey]: channels of several
  /// sources linked to the same guide channel may be one channel.
  Map<String, String> guideLinks() => {
    for (final r in _db.select('SELECT channel_key, guide_id FROM epg_map'))
      r['channel_key'] as String: r['guide_id'] as String,
  };

  /// One channel by its [channelKey] ("source/id"), or `null` when it is
  /// gone or [visibility] leaves it out. For reopening the last channel
  /// without loading the whole list.
  Channel? channelByKey(
    String key, {
    ChannelVisibility visibility = ChannelVisibility.all,
  }) {
    final r = _db.select(
      "SELECT $_cols FROM channels c WHERE c.source_id || '/' || c.id = ? "
      'AND ${_visibleSql(visibility)}',
      [key],
    );
    return r.isEmpty ? null : _channel(r.first);
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
  }) {
    // Counted per source and group from the group index alone; the group
    // preferences are then looked at once per group instead of once per
    // channel. Channels hidden one by one (few) are taken off afterwards: a
    // group whose channels are all hidden goes, and one whose first
    // channel is hidden is placed by its first visible one.
    const notHidden =
        "c2.source_id || '/' || c2.id NOT IN "
        '(SELECT channel_key FROM hidden_channels)';
    final conditions = [
      if (!visibility.hidden) ...[
        'x.n > coalesce(y.h, 0)',
        'NOT EXISTS (SELECT 1 FROM group_prefs g WHERE '
            'g.source_id = x.source_id AND g.group_title = x.group_title '
            'AND g.effective_hidden = 1)',
      ],
      if (!visibility.locked)
        'NOT EXISTS (SELECT 1 FROM group_prefs g WHERE '
            'g.source_id = x.source_id AND g.group_title = x.group_title '
            'AND g.locked = 1)',
      '1',
    ];
    final first = visibility.hidden
        ? 'x.s'
        : 'CASE WHEN y.h IS NULL THEN x.s ELSE (SELECT min(c2.sort) '
              'FROM channels c2 WHERE c2.source_id = x.source_id '
              'AND c2.group_title = x.group_title AND $notHidden) END';
    return [
      for (final r in _db.select(
        'SELECT x.group_title FROM ('
        'SELECT source_id, group_title, min(sort) AS s, count(*) AS n '
        'FROM channels WHERE group_title IS NOT NULL'
        '${sourceId == null ? '' : ' AND source_id = ?'} '
        'GROUP BY source_id, group_title) x '
        'LEFT JOIN (SELECT c.source_id, c.group_title, count(*) AS h '
        'FROM hidden_channels hc JOIN channels c '
        "ON +hc.channel_key = c.source_id || '/' || c.id "
        'GROUP BY c.source_id, c.group_title) y '
        'ON y.source_id = x.source_id AND y.group_title = x.group_title '
        'WHERE ${conditions.join(' AND ')} '
        'GROUP BY x.group_title ORDER BY min($first)',
        [?sourceId],
      ))
        r['group_title'] as String,
    ];
  }

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

  // Joins from a key table to channels write `+x.channel_key`: without the
  // unary plus the key column's text affinity keeps SQLite from using the
  // channels_key index, and every join read all channels.

  List<Channel> hiddenChannels({String? sourceId}) => [
    for (final r in _db.select(
      'SELECT $_cols FROM hidden_channels h JOIN channels c '
      "ON +h.channel_key = c.source_id || '/' || c.id"
      '${sourceId == null ? '' : ' WHERE c.source_id = ?'} ORDER BY c.sort',
      [?sourceId],
    ))
      _channel(r),
  ];

  // ---------------------------------------------------------------- recents

  void markWatched(Channel c, {DateTime? at}) => _transaction(() {
    _db.execute('INSERT OR REPLACE INTO recents VALUES (?, ?)', [
      channelKey(c),
      (at ?? DateTime.now()).microsecondsSinceEpoch,
    ]);
    // Keep the list short.
    _db.execute(
      'DELETE FROM recents WHERE channel_key NOT IN '
      '(SELECT channel_key FROM recents ORDER BY watched_at DESC LIMIT 50)',
    );
  });

  /// Most recently watched first.
  List<Channel> recents({
    int limit = 30,
    ChannelVisibility visibility = ChannelVisibility.visible,
  }) => [
    for (final r in _db.select(
      'SELECT $_cols FROM recents r JOIN channels c '
      "ON +r.channel_key = c.source_id || '/' || c.id "
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
      "ON +f.channel_key = c.source_id || '/' || c.id "
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

  /// Imports a guide. Programmes are upserted, so several guides can be
  /// layered. A guide channel's programmes still to come are replaced:
  /// once the guide is read, those the import didn't bring again go, so a
  /// guide republished with other times (a daylight saving change, a fix,
  /// a time shift) doesn't leave the old programmes overlapping the new
  /// ones. Past programmes stay for replay.
  ///
  /// A programme brought again unchanged is not written again: most of a
  /// guide is the same from one day to the next, and re-importing an
  /// unchanged guide of 1M programmes takes 3.8 s instead of 8.5 s.
  ///
  /// [claimed], shared by the guides of one sync, gives each guide channel
  /// to the first guide that has it: later guides' programmes for it are
  /// skipped, so two guides with different times never mix on a channel.
  ///
  /// Parsed items are held in memory and written [batchSize] at a time, each
  /// batch in one short transaction: the database stays free for the app's
  /// own writes while the guide downloads and parses, and a big batch
  /// writes each page of the indexes once instead of many times.
  Future<GuideImportResult> importGuide(
    Stream<XmltvItem> items, {
    int batchSize = 10000,
    Set<String>? claimed,
    DateTime? now,
  }) async {
    final taken = claimed ?? <String>{};
    final mine = <String, int>{};
    // What this import brought for each of its channels, for the sweep.
    final brought = <String, List<int>>{};
    final from = _secs((now ?? DateTime.now()).toUtc());
    // Writes in arrival order: a channel's clearing comes before its
    // programmes.
    final pending = <_GuideWrite>[];
    var channels = 0, programmes = 0;

    void flush() {
      if (pending.isEmpty) return;
      final upsertChannel = _db.prepare(
        'INSERT OR REPLACE INTO guide_channels(guide_id, names, icon) '
        'VALUES (?, ?, ?)',
      );
      // Rewritten only when something changed: an unchanged row isn't
      // touched, nor its entry in the title index.
      final upsertProgramme = _db.prepare(
        'INSERT INTO programmes(guide_id, start, stop, title, '
        'description, category, episode, icon) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(guide_id, start) DO UPDATE SET stop = excluded.stop, '
        'title = excluded.title, description = excluded.description, '
        'category = excluded.category, episode = excluded.episode, '
        'icon = excluded.icon '
        'WHERE stop IS NOT excluded.stop OR title IS NOT excluded.title '
        'OR description IS NOT excluded.description '
        'OR category IS NOT excluded.category '
        'OR episode IS NOT excluded.episode OR icon IS NOT excluded.icon',
      );
      try {
        _transaction(sliced: true, () {
          for (final w in pending) {
            _yieldLock();
            switch (w.kind) {
              case _GuideWriteKind.channel:
                upsertChannel.execute(w.args);
              case _GuideWriteKind.programme:
                upsertProgramme.execute(w.args);
            }
          }
        });
      } finally {
        upsertChannel.close();
        upsertProgramme.close();
      }
      pending.clear();
    }

    await for (final item in items) {
      switch (item) {
        case XmltvChannel c:
          pending.add(
            _GuideWrite(_GuideWriteKind.channel, [
              c.id.toLowerCase(),
              c.displayNames.join('\n'),
              c.iconUrl?.toString(),
            ]),
          );
          channels++;
        case XmltvProgramme(:final programme):
          final p = programme;
          // Ids compare without case: "Rai1.it" and "rai1.it" are one.
          final id = p.channelId.toLowerCase();
          final start = _secs(p.start);
          final first = mine[id];
          if (first == null) {
            // Another guide of this sync already has this channel.
            if (taken.contains(id)) continue;
            mine[id] = start;
            taken.add(id);
          } else if (start < first) {
            mine[id] = start;
          }
          (brought[id] ??= []).add(start);
          pending.add(
            _GuideWrite(_GuideWriteKind.programme, [
              id,
              start,
              _secs(p.stop),
              p.title,
              p.description,
              p.category,
              p.episode,
              p.iconUrl?.toString(),
            ]),
          );
          programmes++;
      }
      if (pending.length >= batchSize) {
        flush();
        // Let the app's isolate in between two batches.
        await Future<void>.delayed(Duration.zero);
      }
    }
    flush();
    _sweepGuide(brought, mine, from);
    return GuideImportResult(
      channels: channels,
      programmes: programmes,
      starts: mine,
    );
  }

  /// After an import: what each guide channel had from its first imported
  /// programme on (or from [from], when that came later), and the import
  /// didn't bring again, goes. Programmes already airing at that point
  /// count too: a programme moved earlier would overlap them. Older
  /// programmes stay for replay.
  void _sweepGuide(
    Map<String, List<int>> brought,
    Map<String, int> first,
    int from,
  ) {
    if (brought.isEmpty) return;
    final stored = _db.prepare(
      'SELECT start FROM programmes WHERE guide_id = ? '
      'AND start >= ? AND stop > ?',
    );
    final delete = _db.prepare(
      'DELETE FROM programmes WHERE guide_id = ? AND start = ?',
    );
    try {
      _transaction(sliced: true, () {
        for (final MapEntry(key: id, value: starts) in brought.entries) {
          _yieldLock();
          final f = first[id]!;
          final since = f < from ? f : from;
          final keep = starts.toSet();
          for (final r in stored.select([
            id,
            since - longestProgramme.inSeconds,
            since,
          ])) {
            final start = r.columnAt(0) as int;
            if (!keep.contains(start)) delete.execute([id, start]);
          }
        }
      });
    } finally {
      stored.close();
      delete.close();
    }
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
  int alignGuide(Map<String, int> ids, Set<String> reference, {DateTime? now}) {
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
      final top = channels.entries.reduce((a, b) => a.value >= b.value ? a : b);
      if (top.value >= 2 && top.value * 10 >= twinned * 6) usual = top.key;
    }
    // Whole half hours only: a few minutes are listings rounding.
    final moves = <String, int>{
      for (final id in ids.keys)
        if (own[id] ?? usual case final d when d != 0 && d % 1800 == 0) id: d,
    };
    if (moves.isEmpty) return 0;
    // One channel at a time, so the lock can be let go in between.
    _transaction(sliced: true, () {
      _db.execute(
        'CREATE TEMP TABLE IF NOT EXISTS moving AS '
        'SELECT * FROM programmes WHERE 0',
      );
      for (final MapEntry(key: id, value: move) in moves.entries) {
        _yieldLock();
        final since = ids[id];
        _db.execute('DELETE FROM moving');
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
        _db.execute('INSERT OR REPLACE INTO programmes SELECT * FROM moving');
      }
      _db.execute('DELETE FROM moving');
    });
    return moves.length;
  }

  /// Stores programmes fetched for one channel from its source (Xtream's
  /// short EPG) and links the channel to them. Used when the source's
  /// XMLTV guide is missing or has nothing for the channel.
  ///
  /// `false` when the database stayed busy (a sync writing): nothing was
  /// stored, ask again later.
  bool storeChannelGuide(Channel c, List<Programme> programmes) =>
      programmes.isEmpty || tryWrite(() => _storeChannelGuide(c, programmes));

  void _storeChannelGuide(Channel c, List<Programme> programmes) {
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
    // The database compares the titles: with big guides thousands of
    // programmes start in any ten minutes, too many to read one by one on
    // a TV stick for every channel asked about. The start index finds the
    // ten minutes.
    final airing = _db.prepare(
      'SELECT DISTINCT guide_id FROM programmes WHERE start BETWEEN ? AND ? '
      'AND lower(trim(title)) = ? '
      "AND guide_id NOT LIKE '$channelGuidePrefix%'",
    );
    try {
      for (final p in programmes.take(8)) {
        if (_titleKey(p.title).length < 3) continue;
        final at = _secs(p.start);
        for (final r in airing.select([
          at - 300,
          at + 300,
          p.title.trim().toLowerCase(),
        ])) {
          final id = r['guide_id'] as String;
          votes[id] = (votes[id] ?? 0) + 1;
        }
      }
    } finally {
      airing.close();
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
    // A programme ending before [before] started before it too: the start
    // bound lets the start index find them instead of reading every row.
    // A few thousand at a time: a day of a big guide is 100k rows.
    final t = _secs(before);
    var count = 0;
    final delete = _db.prepare(
      'DELETE FROM programmes WHERE (guide_id, start) IN ('
      'SELECT guide_id, start FROM programmes WHERE start < ? AND stop < ? '
      'LIMIT $_pruneChunk)',
    );
    try {
      _transaction(sliced: true, () {
        while (true) {
          _yieldLock();
          delete.execute([t, t]);
          final n = _db.updatedRows;
          count += n;
          if (n < _pruneChunk) break;
        }
      });
    } finally {
      delete.close();
    }
    return count;
  }

  static const _pruneChunk = 5000;

  /// Housekeeping after a sync: trims the film and series details cache
  /// (see [pruneVodDetails]), refreshes the query planner's statistics
  /// and folds the write-ahead log back into the database, so it doesn't
  /// keep the size of the biggest import. Cheap when nothing changed.
  void maintain() {
    pruneVodDetails();
    _db.execute('PRAGMA optimize');
    // PASSIVE copies what it can without waiting for, or blocking, the
    // app's connection (TRUNCATE waits for every reader and writer);
    // journal_size_limit cuts the log file back at its next reset.
    _db.select('PRAGMA wal_checkpoint(PASSIVE)');
  }

  /// What was last imported from the guide at [url], for asking its server
  /// whether it changed.
  GuideFeed? guideFeed(String url) {
    final r = _db.select('SELECT * FROM guide_feeds WHERE url = ?', [url]);
    if (r.isEmpty) return null;
    final row = r.first;
    return GuideFeed(
      url: url,
      etag: row['etag'] as String?,
      lastModified: row['modified'] as String?,
      params: row['params'] as String,
      ids: {
        for (final id in (row['ids'] as String).split('\n'))
          if (id.isNotEmpty) id,
      },
      channels: row['channels'] as int,
      programmes: row['programmes'] as int,
      fetchedAt: _time(row['fetched_at'] as int),
    );
  }

  void saveGuideFeed(GuideFeed f) => _db.execute(
    'INSERT OR REPLACE INTO guide_feeds(url, etag, modified, params, ids, '
    'channels, programmes, fetched_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [
      f.url,
      f.etag,
      f.lastModified,
      f.params,
      f.ids.join('\n'),
      f.channels,
      f.programmes,
      _secs(f.fetchedAt),
    ],
  );

  void forgetGuideFeed(String url) =>
      _db.execute('DELETE FROM guide_feeds WHERE url = ?', [url]);

  /// Whether the guide channels [ids] still have programmes ending after
  /// [at] (a few are looked at, not all).
  bool guideHasProgrammes(Iterable<String> ids, DateTime at) {
    final some = ids.take(20).toList();
    if (some.isEmpty) return false;
    final stmt = _db.prepare(
      'SELECT 1 FROM programmes WHERE guide_id = ? AND stop > ? LIMIT 1',
    );
    try {
      return some.any((id) => stmt.select([id, _secs(at)]).isNotEmpty);
    } finally {
      stmt.close();
    }
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

  /// The guide channels any channel of any source could use (see
  /// [GuideWants]): a guide import keeps only their programmes, plus what
  /// airs around now on the others.
  GuideWants guideWants() => GuideWants(
    [
      for (final r in _db.select('SELECT epg_id, name FROM channels'))
        (r['epg_id'] as String?, r['name'] as String),
    ],
    guideIds: [
      for (final r in _db.select(
        'SELECT guide_id FROM epg_overrides UNION '
        'SELECT guide_id FROM epg_map',
      ))
        if (r['guide_id'] as String case final id
            when !id.startsWith(channelGuidePrefix))
          id,
    ],
  );

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
    var coverage = const GuideCoverage(channels: 0, matched: 0);
    // Worked out before writing, and only the links that changed are
    // written: the database isn't held while thousands of names are
    // compared, and a re-sync that changed nothing writes nothing.
    _readThenWrite(_guideLinks, (plan) {
      final (:channels, :links, :current) = plan;
      coverage = GuideCoverage(channels: channels, matched: links.length);
      final stale = [
        for (final key in current.keys)
          if (!links.containsKey(key)) key,
      ];
      final changed = {
        for (final MapEntry(:key, :value) in links.entries)
          if (current[key] != value) key: value,
      };
      final delete = _db.prepare('DELETE FROM epg_map WHERE channel_key = ?');
      final upsert = _db.prepare(
        'INSERT OR REPLACE INTO epg_map VALUES (?, ?, ?)',
      );
      try {
        for (final key in stale) {
          delete.execute([key]);
        }
        for (final MapEntry(key: key, value: (id, kind)) in changed.entries) {
          upsert.execute([key, id, kind]);
        }
      } finally {
        delete.close();
        upsert.close();
      }
    });
    return coverage;
  }

  /// The guide link every channel should have, and the links stored now
  /// (channel key → (guide id, kind)).
  ({
    int channels,
    Map<String, (String, String)> links,
    Map<String, (String, String)> current,
  })
  _guideLinks() {
    final overrides = {
      for (final r in _db.select(
        'SELECT channel_key, guide_id FROM epg_overrides',
      ))
        r['channel_key'] as String: r['guide_id'] as String,
    };
    final matcher = ChannelMatcher(guideChannels(), manualOverrides: overrides);
    final current = {
      for (final r in _db.select(
        'SELECT channel_key, guide_id, kind FROM epg_map',
      ))
        r['channel_key'] as String: (
          r['guide_id'] as String,
          r['kind'] as String,
        ),
    };
    final links = <String, (String, String)>{};
    var count = 0;
    for (final r in _db.select(
      'SELECT source_id, id, name, epg_id FROM channels',
    )) {
      count++;
      final key = '${r['source_id']}/${r['id']}';
      final m = matcher.match(
        Channel(
          sourceId: r['source_id'] as String,
          id: r['id'] as String,
          name: r['name'] as String,
          epgChannelId: r['epg_id'] as String?,
          streamUrl: _noUrl,
        ),
        channelKey: key,
      );
      if (m != null) {
        links[key] = (_guideKey(m.guideChannelId), m.kind.name);
      } else if (current[key] case (final id, 'source')) {
        // Per-channel guides from the source stay linked when no XMLTV
        // guide matches the channel.
        links[key] = (id, 'source');
      }
    }
    return (channels: count, links: links, current: current);
  }

  /// Matching needs a channel's names, not where it streams from.
  static final _noUrl = Uri();

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
  ///
  /// A guide grid doesn't show descriptions: [withDescriptions] false
  /// leaves them out (a week of a big guide's descriptions is tens of
  /// megabytes read for nothing); [programmeDescription] fetches the one
  /// a detail panel shows.
  ///
  /// Programmes are found from [longestProgramme] before [from]: without
  /// a lower bound on the start, every past programme kept for replay
  /// would be read to find the few still airing.
  Map<String, List<Programme>> guide(
    Iterable<Channel> channels,
    DateTime from,
    DateTime to, {
    bool withDescriptions = true,
  }) {
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
        '${withDescriptions ? 'p.description' : 'NULL AS description'}, '
        'p.category, p.episode, p.icon '
        'FROM epg_map m JOIN programmes p ON p.guide_id = m.guide_id '
        'WHERE m.channel_key IN (${List.filled(part.length, '?').join(',')}) '
        'AND p.start >= ? AND p.stop > ? AND p.start < ? '
        'ORDER BY m.channel_key, p.start',
        [
          ...part,
          _secs(from.subtract(longestProgramme)),
          _secs(from),
          _secs(to),
        ],
      );
      for (final r in rows) {
        (out[r['channel_key'] as String] ??= []).add(_programme(r));
      }
    }
    return out;
  }

  /// How long a programme can be and still be found by [guide] from
  /// after its start. Guides fill nights with programmes of a few hours;
  /// a channel's "programme" that lasts days is a placeholder.
  static const longestProgramme = Duration(hours: 24);

  /// The description of the programme of guide channel [guideId]
  /// (a [Programme.channelId]) starting at [start], for programmes read
  /// without one (see [guide]).
  String? programmeDescription(String guideId, DateTime start) {
    final r = _db.select(
      'SELECT description FROM programmes WHERE guide_id = ? AND start = ?',
      [guideId, _secs(start)],
    );
    return r.isEmpty ? null : r.first.columnAt(0) as String?;
  }

  /// A programme from a row with the programmes table's column names.
  static Programme _programme(Row r) => Programme(
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
  );

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
    final at = _secs(from);
    // Titles are matched in the start index alone, which holds them and the
    // end times, a page of matches at a time in start order; only the
    // matches' rows are read, and the search stops once it has [limit]
    // results, so a common word answers at once. (Programmes longer than
    // two days are not looked for.)
    const page = 400;
    final hits = _db.prepare(
      'SELECT guide_id, start FROM programmes INDEXED BY programmes_at '
      "WHERE (start, guide_id) > (?, ?) AND stop > ? AND title LIKE ? "
      "ESCAPE '!' ORDER BY start, guide_id LIMIT $page",
    );
    final out = <(Channel, Programme)>[];
    try {
      var cursor = (at - 2 * 86400, '');
      while (out.length < limit) {
        final found = hits.select([cursor.$1, cursor.$2, at, '%$escaped%']);
        if (found.isEmpty) break;
        final last = found.last;
        cursor = (last['start'] as int, last['guide_id'] as String);
        final pairs = List.filled(found.length, '(?, ?)').join(', ');
        for (final r in _db.select(
          'SELECT $_cols, p.guide_id AS pg, p.start AS ps, p.stop AS pe, '
          'p.title AS pt, p.description AS pd, p.category AS pc, '
          'p.episode AS pep, p.icon AS pi '
          'FROM programmes p JOIN epg_map m ON m.guide_id = p.guide_id '
          "JOIN channels c ON +m.channel_key = c.source_id || '/' || c.id "
          'WHERE (p.guide_id, p.start) IN (VALUES $pairs) '
          'AND ${_visibleSql(visibility)} ORDER BY p.start, p.guide_id',
          [
            for (final h in found) ...[h['guide_id'], h['start']],
          ],
        )) {
          out.add((
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
          ));
          if (out.length == limit) break;
        }
        if (found.length < page) break;
      }
    } finally {
      hits.close();
    }
    return out;
  }

  /// What guide channel [guideId] airs at [at], to tell guides apart.
  Programme? airingOn(String guideId, DateTime at) {
    final r = _db.select(
      'SELECT start, stop, title FROM programmes '
      'WHERE guide_id = ? AND start BETWEEN ? AND ? AND stop > ? LIMIT 1',
      [guideId, _secs(at.subtract(longestProgramme)), _secs(at), _secs(at)],
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
    // The first few programmes not over by [at], in the next 12 hours:
    // enough for now and next even with a few overlapping entries.
    final list = [
      for (final r in _db.select(
        'SELECT p.guide_id, p.start, p.stop, p.title, p.description, '
        'p.category, p.episode, p.icon '
        'FROM epg_map m JOIN programmes p ON p.guide_id = m.guide_id '
        'WHERE m.channel_key = ? AND p.start >= ? AND p.stop > ? '
        'AND p.start < ? ORDER BY p.start LIMIT 4',
        [
          channelKey(c),
          _secs(at.subtract(longestProgramme)),
          _secs(at),
          _secs(at) + 12 * 3600,
        ],
      ))
        _programme(r),
    ];
    final now = list.where((p) => p.isAiringAt(at)).firstOrNull;
    final next = list
        .where((p) => !p.start.isBefore(now?.stop ?? at))
        .firstOrNull;
    return (now, next);
  }
}
