import 'dart:convert';

import 'package:zapline_core/zapline_core.dart';

import 'database.dart';
import 'source_record.dart';

/// What a backup file restores. Sources come without ids; favourites and
/// guide overrides point at them by position so they can be re-attached to
/// the ids the sources get on the new device.
class BackupContents {
  const BackupContents({
    required this.sources,
    required this.favourites,
    required this.guideOverrides,
    this.groupPrefs = const [],
    this.hiddenChannels = const [],
    this.sourceIds = const [],
    this.settings = const {},
    this.myList = const [],
    this.positions = const [],
  });

  final List<SourceRecord> sources;

  /// (index into [sources], channel id).
  final List<(int, String)> favourites;

  /// (index into [sources], channel id, guide channel id).
  final List<(int, String, String)> guideOverrides;

  /// (index into [sources], group title, explicit hidden or null, locked).
  final List<(int, String, bool?, bool)> groupPrefs;

  /// (index into [sources], channel id).
  final List<(int, String)> hiddenChannels;

  /// The sources' ids on the device the backup came from, by index, so
  /// keys that hold them (`movie:ID/42`) can be moved to the new ids
  /// (see [Backup.remapKey]).
  final List<String> sourceIds;

  /// App preferences, as stored.
  final Map<String, String> settings;

  /// "La mia lista" keys, with the old source ids.
  final List<String> myList;

  /// Where films and episodes were left: (key, position ms, duration ms),
  /// with the old source ids.
  final List<(String, int, int)> positions;
}

/// What to put in a backup or a transfer; sources always go.
enum BackupPart {
  /// Filters, groups shown or hidden by hand, hidden channels.
  filters,
  favourites,

  /// Extra guides, their time shift and channels matched by hand.
  guide,

  /// My list and where films and episodes were left.
  watching,

  /// App preferences ([Backup.export]'s settings).
  settings,
}

class BackupFormatException implements Exception {
  BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// JSON backup of the user's setup: sources (with credentials), favourites
/// and manual guide links. Channel lists and guides are not included; they
/// are downloaded again from the sources.
abstract final class Backup {
  static const format = 'zapline-backup';
  static const version = 2;

  /// [passwordOf] supplies credentials kept outside the database. [parts]
  /// says what goes besides the sources; [settings] are the preferences to
  /// include when [BackupPart.settings] is among them.
  static String export(
    ZaplineDatabase db, {
    String Function(SourceRecord source)? passwordOf,
    DateTime? now,
    Set<BackupPart> parts = const {...BackupPart.values},
    Map<String, String> settings = const {},
  }) {
    final filters = parts.contains(BackupPart.filters);
    final guide = parts.contains(BackupPart.guide);
    final watching = parts.contains(BackupPart.watching);
    final sources = db.sources();
    final index = {for (final (i, s) in sources.indexed) s.id: i};

    (int, String)? split(String channelKey) {
      final slash = channelKey.indexOf('/');
      if (slash < 0) return null;
      final i = index[channelKey.substring(0, slash)];
      return i == null ? null : (i, channelKey.substring(slash + 1));
    }

    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'sourceIds': [for (final s in sources) s.id],
      'sources': [
        for (final s in sources)
          {
            'kind': s.kind.name,
            'name': s.name,
            'url': s.url,
            'username': s.username,
            'password': passwordOf?.call(s) ?? s.password,
            if (guide) 'guides': s.extraGuideUrls,
            if (guide) 'guideOffsetMinutes': s.guideOffset.inMinutes,
            if (filters) 'groupFilter': s.groupFilter.toJson(),
            if (filters) 'movieFilter': s.movieFilter.toJson(),
            if (filters) 'showFilter': s.showFilter.toJson(),
            if (filters) 'movieChoices': s.movieChoices,
            if (filters) 'showChoices': s.showChoices,
          },
      ],
      if (parts.contains(BackupPart.settings) && settings.isNotEmpty)
        'settings': settings,
      if (watching) 'myList': db.myList(),
      if (watching)
        'positions': [
          for (final p in db.positions(limit: 2000))
            {
              'key': p.key,
              'position': p.position.inMilliseconds,
              'duration': p.duration.inMilliseconds,
            },
        ],
      if (filters)
        'groupPrefs': [
          for (final (i, s) in sources.indexed)
            for (final g in db.groupInfo(s.id))
              if (g.explicit != null || g.locked)
                {
                  'source': i,
                  'group': g.title,
                  'hidden': g.explicit,
                  'locked': g.locked,
                },
        ],
      if (filters)
        'hiddenChannels': [
          for (final c in db.hiddenChannels())
            if (index[c.sourceId] case final i?) {'source': i, 'channel': c.id},
        ],
      if (parts.contains(BackupPart.favourites))
        'favourites': [
          for (final k in db.favouriteKeysInOrder())
            if (split(k) case (final i, final id)) {'source': i, 'channel': id},
        ],
      if (guide)
        'guideOverrides': [
          for (final MapEntry(:key, :value) in db.guideOverrides().entries)
            if (split(key) case (final i, final id))
              {'source': i, 'channel': id, 'guide': value},
        ],
    });
  }

  static BackupContents parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw BackupFormatException('This is not a Zapline backup file.');
    }
    if (json is! Map || json['format'] != format) {
      throw BackupFormatException('This is not a Zapline backup file.');
    }
    final v = json['version'];
    if (v is! int || v > version) {
      throw BackupFormatException(
        'This backup was made by a newer version of Zapline.',
      );
    }
    final rawSources = json['sources'];
    if (rawSources is! List) {
      throw BackupFormatException('The backup contains no sources.');
    }
    final sources = <SourceRecord>[];
    for (final s in rawSources) {
      if (s is! Map) continue;
      final kind = SourceKind.values
          .where((k) => k.name == s['kind'])
          .firstOrNull;
      final url = s['url'];
      if (kind == null || url is! String || url.isEmpty) continue;
      sources.add(
        SourceRecord(
          id: '',
          kind: kind,
          name: (s['name'] as String?) ?? url,
          url: url,
          username: (s['username'] as String?) ?? '',
          password: (s['password'] as String?) ?? '',
          extraGuideUrls: [
            for (final g in (s['guides'] as List?) ?? const []) '$g',
          ],
          guideOffset: Duration(
            minutes: (s['guideOffsetMinutes'] as int?) ?? 0,
          ),
          groupFilter: GroupFilter.fromJson(s['groupFilter']),
          movieFilter: GroupFilter.fromJson(s['movieFilter']),
          showFilter: GroupFilter.fromJson(s['showFilter']),
          movieChoices: readChoices(s['movieChoices']),
          showChoices: readChoices(s['showChoices']),
        ),
      );
    }
    bool valid(Object? i) => i is int && i >= 0 && i < sources.length;
    return BackupContents(
      sources: sources,
      favourites: [
        for (final f in (json['favourites'] as List?) ?? const [])
          if (f is Map && valid(f['source']) && f['channel'] is String)
            (f['source'] as int, f['channel'] as String),
      ],
      guideOverrides: [
        for (final o in (json['guideOverrides'] as List?) ?? const [])
          if (o is Map &&
              valid(o['source']) &&
              o['channel'] is String &&
              o['guide'] is String)
            (o['source'] as int, o['channel'] as String, o['guide'] as String),
      ],
      groupPrefs: [
        for (final g in (json['groupPrefs'] as List?) ?? const [])
          if (g is Map && valid(g['source']) && g['group'] is String)
            (
              g['source'] as int,
              g['group'] as String,
              g['hidden'] as bool?,
              g['locked'] == true,
            ),
      ],
      hiddenChannels: [
        for (final h in (json['hiddenChannels'] as List?) ?? const [])
          if (h is Map && valid(h['source']) && h['channel'] is String)
            (h['source'] as int, h['channel'] as String),
      ],
      sourceIds: [
        for (final id in (json['sourceIds'] as List?) ?? const []) '$id',
      ],
      settings: {
        for (final MapEntry(:key, :value)
            in ((json['settings'] as Map?) ?? const {}).entries)
          if (value is String) '$key': value,
      },
      myList: [
        for (final k in (json['myList'] as List?) ?? const [])
          if (k is String) k,
      ],
      positions: [
        for (final p in (json['positions'] as List?) ?? const [])
          if (p is Map &&
              p['key'] is String &&
              p['position'] is int &&
              p['duration'] is int)
            (p['key'] as String, p['position'] as int, p['duration'] as int),
      ],
    );
  }

  static final _keyWithSource = RegExp(
    r'^([a-z]+:)?([^/\u0000]+)([/\u0000].*)$',
  );

  /// [key] with the source id it holds (`movie:ID/42`, `ID/7`,
  /// `ID\u0000rai1`) moved to the new device's; `null` when that source
  /// did not come along.
  static String? remapKey(String key, Map<String, String> ids) {
    final m = _keyWithSource.firstMatch(key);
    if (m == null) return null;
    final id = ids[m.group(2)];
    if (id == null) return null;
    return '${m.group(1) ?? ''}$id${m.group(3)}';
  }
}
