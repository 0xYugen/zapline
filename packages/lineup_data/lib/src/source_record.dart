import 'dart:convert';

enum SourceKind { xtream, m3u, stalker }

/// A user-added source as persisted. Lineup never ships sources.
///
/// Credentials are stored in the local database. Moving them to the platform
/// keystore is tracked in docs/ROADMAP.md.
class SourceRecord {
  const SourceRecord({
    required this.id,
    required this.kind,
    required this.name,
    required this.url,
    this.username = '',
    this.password = '',
    this.extraGuideUrls = const [],
    this.syncedAt,
    this.serverOffset = Duration.zero,
  });

  final String id;
  final SourceKind kind;
  final String name;

  /// Server base URL (Xtream), playlist URL (M3U) or portal URL (Stalker).
  final String url;
  final String username;
  final String password;

  /// XMLTV guides added by the user on top of the source's own guide.
  final List<String> extraGuideUrls;
  final DateTime? syncedAt;

  /// Xtream panels read catch-up start times in their own local time.
  final Duration serverOffset;

  SourceRecord copyWith({
    String? name,
    DateTime? syncedAt,
    Duration? serverOffset,
  }) => SourceRecord(
    id: id,
    kind: kind,
    name: name ?? this.name,
    url: url,
    username: username,
    password: password,
    extraGuideUrls: extraGuideUrls,
    syncedAt: syncedAt ?? this.syncedAt,
    serverOffset: serverOffset ?? this.serverOffset,
  );

  Map<String, Object?> toConfigJson() => {
    'url': url,
    'username': username,
    'password': password,
    'guides': extraGuideUrls,
    'offsetMinutes': serverOffset.inMinutes,
  };

  static SourceRecord fromRow({
    required String id,
    required String kind,
    required String name,
    required String config,
    int? syncedAt,
  }) {
    final c = jsonDecode(config) as Map<String, Object?>;
    return SourceRecord(
      id: id,
      kind: SourceKind.values.byName(kind),
      name: name,
      url: c['url'] as String? ?? '',
      username: c['username'] as String? ?? '',
      password: c['password'] as String? ?? '',
      extraGuideUrls: [for (final g in (c['guides'] as List?) ?? []) '$g'],
      syncedAt: syncedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(syncedAt * 1000, isUtc: true),
      serverOffset: Duration(minutes: (c['offsetMinutes'] as int?) ?? 0),
    );
  }
}
