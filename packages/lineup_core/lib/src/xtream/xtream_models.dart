/// Panels disagree on JSON types (ids as strings or ints, dates as strings,
/// numbers or null), so every field goes through these tolerant readers.
int? readInt(Object? v) => switch (v) {
      int i => i,
      double d => d.toInt(),
      String s => int.tryParse(s.trim()),
      _ => null,
    };

String? readString(Object? v) => switch (v) {
      null => null,
      String s => s.isEmpty ? null : s,
      _ => v.toString(),
    };

bool readBool(Object? v) => switch (v) {
      bool b => b,
      int i => i != 0,
      String s => s == '1' || s.toLowerCase() == 'true',
      _ => false,
    };

DateTime? readUnixSeconds(Object? v) {
  final secs = readInt(v);
  if (secs == null || secs <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true);
}

class XtreamAccount {
  const XtreamAccount({
    required this.authenticated,
    required this.status,
    this.expiresAt,
    this.maxConnections,
    this.activeConnections,
    this.allowedOutputFormats = const [],
    this.serverTimezone,
    this.serverUrl,
    this.httpsPort,
  });

  factory XtreamAccount.fromJson(Map<String, Object?> json) {
    final user = (json['user_info'] as Map?)?.cast<String, Object?>() ?? {};
    final server = (json['server_info'] as Map?)?.cast<String, Object?>() ?? {};
    final formats = user['allowed_output_formats'];
    return XtreamAccount(
      authenticated: readBool(user['auth']),
      status: readString(user['status']) ?? 'Unknown',
      expiresAt: readUnixSeconds(user['exp_date']),
      maxConnections: readInt(user['max_connections']),
      activeConnections: readInt(user['active_cons']),
      allowedOutputFormats:
          formats is List ? [for (final f in formats) f.toString()] : const [],
      serverTimezone: readString(server['timezone']),
      serverUrl: readString(server['url']),
      httpsPort: readInt(server['https_port']),
    );
  }

  final bool authenticated;
  final String status;

  /// `null` means unlimited or unknown.
  final DateTime? expiresAt;
  final int? maxConnections;
  final int? activeConnections;
  final List<String> allowedOutputFormats;
  final String? serverTimezone;
  final String? serverUrl;
  final int? httpsPort;

  bool get isActive => authenticated && status.toLowerCase() == 'active';

  /// Prefers MPEG-TS for live (lowest latency), falling back to HLS.
  String get preferredLiveExtension {
    if (allowedOutputFormats.isEmpty || allowedOutputFormats.contains('ts')) {
      return 'ts';
    }
    if (allowedOutputFormats.contains('m3u8')) return 'm3u8';
    return allowedOutputFormats.first;
  }
}

class XtreamCategory {
  const XtreamCategory({required this.id, required this.name, this.parentId});

  factory XtreamCategory.fromJson(Map<String, Object?> json) => XtreamCategory(
        id: readString(json['category_id']) ?? '',
        name: readString(json['category_name']) ?? '',
        parentId: readString(json['parent_id']),
      );

  final String id;
  final String name;
  final String? parentId;
}

class XtreamLiveStream {
  const XtreamLiveStream({
    required this.streamId,
    required this.name,
    this.number,
    this.iconUrl,
    this.epgChannelId,
    this.categoryId,
    this.hasArchive = false,
    this.archiveDays,
  });

  factory XtreamLiveStream.fromJson(Map<String, Object?> json) =>
      XtreamLiveStream(
        streamId: readInt(json['stream_id']) ?? -1,
        name: readString(json['name'])?.trim() ?? '',
        number: readInt(json['num']),
        iconUrl: readString(json['stream_icon']),
        epgChannelId: readString(json['epg_channel_id']),
        categoryId: readString(json['category_id']),
        hasArchive: readBool(json['tv_archive']),
        archiveDays: readInt(json['tv_archive_duration']),
      );

  final int streamId;
  final String name;
  final int? number;
  final String? iconUrl;
  final String? epgChannelId;
  final String? categoryId;
  final bool hasArchive;
  final int? archiveDays;
}

class XtreamVodStream {
  const XtreamVodStream({
    required this.streamId,
    required this.name,
    this.containerExtension,
    this.iconUrl,
    this.categoryId,
    this.rating,
    this.addedAt,
  });

  factory XtreamVodStream.fromJson(Map<String, Object?> json) =>
      XtreamVodStream(
        streamId: readInt(json['stream_id']) ?? -1,
        name: readString(json['name'])?.trim() ?? '',
        containerExtension: readString(json['container_extension']),
        iconUrl: readString(json['stream_icon']),
        categoryId: readString(json['category_id']),
        rating: readString(json['rating']),
        addedAt: readUnixSeconds(json['added']),
      );

  final int streamId;
  final String name;
  final String? containerExtension;
  final String? iconUrl;
  final String? categoryId;
  final String? rating;
  final DateTime? addedAt;
}

class XtreamSeries {
  const XtreamSeries({
    required this.seriesId,
    required this.name,
    this.coverUrl,
    this.categoryId,
    this.plot,
  });

  factory XtreamSeries.fromJson(Map<String, Object?> json) => XtreamSeries(
        seriesId: readInt(json['series_id']) ?? -1,
        name: readString(json['name'])?.trim() ?? '',
        coverUrl: readString(json['cover']),
        categoryId: readString(json['category_id']),
        plot: readString(json['plot']),
      );

  final int seriesId;
  final String name;
  final String? coverUrl;
  final String? categoryId;
  final String? plot;
}

class XtreamShortEpgEntry {
  const XtreamShortEpgEntry({
    required this.title,
    required this.start,
    required this.stop,
    this.description,
  });

  final String title;
  final DateTime start;
  final DateTime stop;
  final String? description;
}
