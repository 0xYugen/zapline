import 'dart:convert';

import 'package:zapline_core/zapline_core.dart';

enum SourceKind { xtream, m3u, stalker }

/// A user-added source as persisted. Zapline never ships sources.
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
    this.guideOffset = Duration.zero,
    this.groupFilter = GroupFilter.none,
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

  /// Shift applied to this source's guides, for XMLTV files published in the
  /// wrong time zone.
  final Duration guideOffset;

  /// Which groups to show; see [GroupFilter].
  final GroupFilter groupFilter;

  SourceRecord copyWith({
    String? name,
    String? password,
    List<String>? extraGuideUrls,
    DateTime? syncedAt,
    Duration? serverOffset,
    Duration? guideOffset,
    GroupFilter? groupFilter,
  }) => SourceRecord(
    id: id,
    kind: kind,
    name: name ?? this.name,
    url: url,
    username: username,
    password: password ?? this.password,
    extraGuideUrls: extraGuideUrls ?? this.extraGuideUrls,
    syncedAt: syncedAt ?? this.syncedAt,
    serverOffset: serverOffset ?? this.serverOffset,
    guideOffset: guideOffset ?? this.guideOffset,
    groupFilter: groupFilter ?? this.groupFilter,
  );

  Map<String, Object?> toConfigJson() => {
    'url': url,
    'username': username,
    'password': password,
    'guides': extraGuideUrls,
    'offsetMinutes': serverOffset.inMinutes,
    'guideOffsetMinutes': guideOffset.inMinutes,
    'groupFilter': groupFilter.toJson(),
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
      guideOffset: Duration(minutes: (c['guideOffsetMinutes'] as int?) ?? 0),
      groupFilter: GroupFilter.fromJson(c['groupFilter']),
    );
  }
}
