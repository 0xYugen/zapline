import 'dart:convert';

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
  });

  final List<SourceRecord> sources;

  /// (index into [sources], channel id).
  final List<(int, String)> favourites;

  /// (index into [sources], channel id, guide channel id).
  final List<(int, String, String)> guideOverrides;
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
  static const version = 1;

  /// [passwordOf] supplies credentials kept outside the database.
  static String export(
    ZaplineDatabase db, {
    String Function(SourceRecord source)? passwordOf,
    DateTime? now,
  }) {
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
      'sources': [
        for (final s in sources)
          {
            'kind': s.kind.name,
            'name': s.name,
            'url': s.url,
            'username': s.username,
            'password': passwordOf?.call(s) ?? s.password,
            'guides': s.extraGuideUrls,
          },
      ],
      'favourites': [
        for (final k in db.favouriteKeysInOrder())
          if (split(k) case (final i, final id)) {'source': i, 'channel': id},
      ],
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
    );
  }
}
