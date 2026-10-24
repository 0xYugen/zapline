import 'package:http/http.dart' as http;
import 'package:zapline_core/zapline_core.dart';

import 'database.dart';
import 'source_record.dart';
import 'source_sync.dart';

/// Fetches what's on for single channels straight from the source, for
/// when its XMLTV guide is missing, disabled or has nothing for a channel.
///
/// Many Xtream panels turn off or break `xmltv.php` but still answer
/// `get_short_epg`, a few programmes per channel. Fetched programmes are
/// stored as the channel's guide, so lists, the player and the guide all
/// show them.
class ChannelGuideFetcher {
  ChannelGuideFetcher(this.db, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final ZaplineDatabase db;
  final http.Client _http;

  /// Whether [source] can be asked for single channels.
  static bool supports(SourceRecord source) => source.kind == SourceKind.xtream;

  /// Fetches and stores [channel]'s next programmes. Returns how many were
  /// stored; 0 when the source has nothing for it.
  Future<int> fetch(SourceRecord source, Channel channel) async {
    final streamId = int.tryParse(channel.id);
    if (!supports(source) || streamId == null) return 0;
    // Not closed: that would close the shared HTTP client.
    final client = XtreamClient(
      SourceSync.credentialsOf(source),
      httpClient: _http,
    );
    final entries = await client.shortEpg(streamId, limit: 12);
    final shift = source.guideOffset;
    final programmes = [
      for (final e in entries)
        Programme(
          channelId: channel.id,
          start: e.start,
          stop: e.stop,
          title: e.title,
          description: e.description,
        ).shifted(shift),
    ];
    db.storeChannelGuide(channel, programmes);
    return programmes.length;
  }

  void close() => _http.close();
}
