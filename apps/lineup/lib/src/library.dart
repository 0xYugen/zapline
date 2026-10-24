import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lineup_core/lineup_core.dart';

/// What the user typed or pasted on the "add source" screen.
class SourceInput {
  const SourceInput({
    required this.url,
    this.username = '',
    this.password = '',
  });

  final String url;
  final String username;
  final String password;
}

/// In-memory channel library for the Phase 0 prototype.
///
/// Phase 1 replaces this with the SQLite data layer and background sync.
class Library extends ChangeNotifier {
  Library({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  String? sourceName;
  List<Channel> channels = const [];
  List<String> groups = const [];
  Uri? guideUrl;

  bool get isEmpty => channels.isEmpty;

  /// Loads a source, replacing the current one. Throws on failure with a
  /// message suitable for display.
  Future<void> load(SourceInput input) async {
    final url = input.url.trim();
    final creds = input.username.isNotEmpty
        ? XtreamCredentials(
            baseUrl: _baseOf(url),
            username: input.username.trim(),
            password: input.password,
          )
        : detectXtreamCredentials(url);

    final loaded = creds != null
        ? await _loadXtream(creds)
        : await _loadM3u(url);

    channels = loaded;
    groups = {
      for (final c in loaded)
        if (c.groupTitle != null) c.groupTitle!,
    }.toList();
    notifyListeners();
  }

  Future<List<Channel>> _loadXtream(XtreamCredentials creds) async {
    final client = XtreamClient(creds, httpClient: _http);
    final account = await client.authenticate();
    if (!account.isActive) {
      throw Exception('Account status: ${account.status}');
    }
    final categories = {
      for (final c in await client.liveCategories()) c.id: c.name,
    };
    final streams = await client.liveStreams();
    final ext = account.preferredLiveExtension;
    sourceName = creds.baseUrl.host;
    guideUrl = client.xmltvUrl;
    return [
      for (final s in streams)
        if (s.streamId >= 0)
          Channel(
            sourceId: 'xtream:${creds.baseUrl.host}',
            id: '${s.streamId}',
            name: s.name,
            number: s.number,
            streamUrl: client.liveUrl(s.streamId, extension: ext),
            groupTitle: categories[s.categoryId],
            logoUrl: Uri.tryParse(s.iconUrl ?? ''),
            epgChannelId: s.epgChannelId,
            catchup: s.hasArchive
                ? CatchupInfo(mode: CatchupMode.xtream, days: s.archiveDays)
                : null,
            httpHeaders: const {'User-Agent': XtreamClient.defaultUserAgent},
          ),
    ];
  }

  Future<List<Channel>> _loadM3u(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) throw Exception('Not a valid URL');
    final res = await _http.send(
      http.Request('GET', uri)
        ..headers['User-Agent'] = XtreamClient.defaultUserAgent,
    );
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

    final parser = M3uParser();
    final out = <Channel>[];
    var i = 0;
    await for (final e in parser.parseBytes(res.stream)) {
      final stream = Uri.tryParse(e.url);
      if (stream == null) continue;
      i++;
      out.add(
        Channel(
          sourceId: 'm3u:${uri.host}',
          id: '$i',
          name: e.title,
          number: e.tvgChno ?? i,
          streamUrl: stream,
          groupTitle: e.group,
          logoUrl: Uri.tryParse(e.tvgLogo ?? ''),
          epgChannelId: e.tvgId,
          httpHeaders: e.httpHeaders,
        ),
      );
    }
    sourceName = uri.host;
    guideUrl = parser.header.epgUrls.firstOrNull;
    if (out.isEmpty) throw Exception('The playlist contains no channels');
    return out;
  }

  static Uri _baseOf(String url) {
    final u = Uri.parse(url.contains('://') ? url : 'http://$url');
    return Uri(scheme: u.scheme, host: u.host, port: u.hasPort ? u.port : null);
  }
}
