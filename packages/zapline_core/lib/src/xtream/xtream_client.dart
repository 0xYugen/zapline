import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/source.dart';
import 'xtream_models.dart';

class XtreamException implements Exception {
  XtreamException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'XtreamException($statusCode): $message';
}

/// Client for Xtream-compatible panels (`player_api.php`).
///
/// There is no official specification; behaviour follows what common panels
/// return in practice and every field is parsed tolerantly.
class XtreamClient {
  XtreamClient(
    this.credentials, {
    http.Client? httpClient,
    this.userAgent = defaultUserAgent,
    this.timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client();

  /// Some panels reject requests with an empty or library-default User-Agent.
  static const defaultUserAgent = 'Zapline/0.1 (+https://zapline.invalid)';

  final XtreamCredentials credentials;
  final String userAgent;
  final Duration timeout;
  final http.Client _http;

  Uri _api([Map<String, String> extra = const {}]) =>
      credentials.baseUrl.replace(path: '/player_api.php', queryParameters: {
        'username': credentials.username,
        'password': credentials.password,
        ...extra,
      });

  Future<Object?> _getJson(Uri uri) async {
    final res = await _http.get(uri,
        headers: {'User-Agent': userAgent, 'Accept': '*/*'}).timeout(timeout);
    if (res.statusCode != 200) {
      throw XtreamException('HTTP ${res.statusCode}',
          statusCode: res.statusCode);
    }
    final body = utf8.decode(res.bodyBytes, allowMalformed: true).trim();
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      throw XtreamException('Server did not return JSON');
    }
  }

  Future<List<Map<String, Object?>>> _getList(Map<String, String> q) async {
    final data = await _getJson(_api(q));
    // Empty results come back as [], {} or null depending on the panel.
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map) item.cast<String, Object?>(),
    ];
  }

  Future<XtreamAccount> authenticate() async {
    final data = await _getJson(_api());
    if (data is! Map || data['user_info'] == null) {
      throw XtreamException('Invalid login response');
    }
    final account = XtreamAccount.fromJson(data.cast<String, Object?>());
    if (!account.authenticated) {
      throw XtreamException('Wrong username or password', statusCode: 401);
    }
    return account;
  }

  Future<List<XtreamCategory>> liveCategories() async =>
      (await _getList({'action': 'get_live_categories'}))
          .map(XtreamCategory.fromJson)
          .toList();

  Future<List<XtreamCategory>> vodCategories() async =>
      (await _getList({'action': 'get_vod_categories'}))
          .map(XtreamCategory.fromJson)
          .toList();

  Future<List<XtreamCategory>> seriesCategories() async =>
      (await _getList({'action': 'get_series_categories'}))
          .map(XtreamCategory.fromJson)
          .toList();

  Future<List<XtreamLiveStream>> liveStreams({String? categoryId}) async =>
      (await _getList({
        'action': 'get_live_streams',
        if (categoryId != null) 'category_id': categoryId,
      }))
          .map(XtreamLiveStream.fromJson)
          .toList();

  Future<List<XtreamVodStream>> vodStreams({String? categoryId}) async =>
      (await _getList({
        'action': 'get_vod_streams',
        if (categoryId != null) 'category_id': categoryId,
      }))
          .map(XtreamVodStream.fromJson)
          .toList();

  Future<List<XtreamSeries>> series({String? categoryId}) async =>
      (await _getList({
        'action': 'get_series',
        if (categoryId != null) 'category_id': categoryId,
      }))
          .map(XtreamSeries.fromJson)
          .toList();

  /// Small per-channel guide. For the full grid use [xmltvUrl] instead:
  /// one bulk download beats thousands of per-channel requests.
  Future<List<XtreamShortEpgEntry>> shortEpg(int streamId,
      {int limit = 4}) async {
    final data = await _getJson(_api({
      'action': 'get_short_epg',
      'stream_id': '$streamId',
      'limit': '$limit',
    }));
    final listings = data is Map ? data['epg_listings'] : null;
    if (listings is! List) return const [];
    final out = <XtreamShortEpgEntry>[];
    for (final raw in listings) {
      if (raw is! Map) continue;
      final start = readUnixSeconds(raw['start_timestamp']);
      final stop = readUnixSeconds(raw['stop_timestamp']);
      if (start == null || stop == null) continue;
      out.add(XtreamShortEpgEntry(
        title: maybeBase64(readString(raw['title']) ?? ''),
        description: switch (readString(raw['description'])) {
          final d? => maybeBase64(d),
          null => null,
        },
        start: start,
        stop: stop,
      ));
    }
    return out;
  }

  /// Full XMLTV guide for every channel on the account.
  Uri get xmltvUrl => credentials.baseUrl.replace(
        path: '/xmltv.php',
        queryParameters: {
          'username': credentials.username,
          'password': credentials.password,
        },
      );

  Uri liveUrl(int streamId, {String extension = 'ts'}) =>
      _streamPath('live', '$streamId.$extension');

  Uri movieUrl(int streamId, String extension) =>
      _streamPath('movie', '$streamId.$extension');

  Uri episodeUrl(int episodeId, String extension) =>
      _streamPath('series', '$episodeId.$extension');

  /// Catch-up URL: `/timeshift/U/P/{minutes}/{YYYY-MM-DD:HH-MM}/{id}.ts`.
  ///
  /// [start] is converted to the panel's local time using [serverOffset]
  /// (derive it from the account's `server_info.timezone`).
  Uri timeshiftUrl(
    int streamId, {
    required DateTime start,
    required Duration duration,
    Duration serverOffset = Duration.zero,
    String extension = 'ts',
  }) {
    final t = start.toUtc().add(serverOffset);
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${t.year}-${two(t.month)}-${two(t.day)}:${two(t.hour)}-${two(t.minute)}';
    return _streamPath(
        'timeshift', '${duration.inMinutes}/$stamp/$streamId.$extension');
  }

  Uri _streamPath(String kind, String tail) => credentials.baseUrl.replace(
        path: '/$kind/${Uri.encodeComponent(credentials.username)}/'
            '${Uri.encodeComponent(credentials.password)}/$tail',
      );

  void close() => _http.close();
}

/// Some panels Base64-encode EPG titles and descriptions, others don't.
String maybeBase64(String s) {
  if (s.length < 4 || s.length % 4 != 0) return s;
  if (!RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(s)) return s;
  try {
    final decoded = utf8.decode(base64.decode(s));
    // Reject decodes that produced control characters: it was plain text.
    if (decoded.codeUnits.any((c) => c < 0x09)) return s;
    return decoded;
  } on FormatException {
    return s;
  }
}
