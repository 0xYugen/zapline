/// A live channel as exposed by a single source.
class Channel {
  const Channel({
    required this.sourceId,
    required this.id,
    required this.name,
    required this.streamUrl,
    this.number,
    this.groupTitle,
    this.logoUrl,
    this.epgChannelId,
    this.catchup,
    this.httpHeaders = const {},
  });

  final String sourceId;

  /// Identifier unique within [sourceId].
  final String id;
  final String name;
  final Uri streamUrl;
  final int? number;
  final String? groupTitle;
  final Uri? logoUrl;

  /// The XMLTV channel id (`tvg-id` in M3U, `epg_channel_id` in Xtream).
  final String? epgChannelId;
  final CatchupInfo? catchup;

  /// Extra request headers (User-Agent, Referer) the stream requires.
  final Map<String, String> httpHeaders;

  @override
  String toString() => 'Channel($sourceId/$id, $name)';
}

enum CatchupMode { defaultMode, append, shift, flussonic, xtream, vod }

class CatchupInfo {
  const CatchupInfo({required this.mode, this.days, this.source});

  final CatchupMode mode;

  /// How many days back the archive goes, when known.
  final int? days;

  /// URL template with placeholders such as `{utc}` or `${start}`.
  final String? source;
}

/// A guide entry, always stored in UTC.
class Programme {
  const Programme({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    this.description,
    this.category,
    this.episode,
    this.iconUrl,
  });

  final String channelId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? description;
  final String? category;
  final String? episode;
  final Uri? iconUrl;

  bool isAiringAt(DateTime t) => !t.isBefore(start) && t.isBefore(stop);

  @override
  String toString() => 'Programme($channelId, $start, $title)';
}
