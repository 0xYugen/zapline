import '../models/source.dart';

/// Recognises Xtream-compatible credentials inside URLs users commonly paste:
///
/// * `http://host:port/get.php?username=U&password=P&type=m3u_plus`
/// * `http://host:port/player_api.php?username=U&password=P`
/// * `http://host:port/xmltv.php?username=U&password=P`
/// * `http://host:port/live/U/P/123.ts` (also `movie/`, `series/`)
/// * `http://host:port/U/P/123` (short live form)
///
/// Returns `null` when the URL is not recognisably Xtream.
XtreamCredentials? detectXtreamCredentials(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;

  final base = Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final last = segments.isEmpty ? '' : segments.last.toLowerCase();

  if (const {'get.php', 'player_api.php', 'xmltv.php', 'panel_api.php'}
      .contains(last)) {
    final user = uri.queryParameters['username'];
    final pass = uri.queryParameters['password'];
    if (user == null || pass == null || user.isEmpty) return null;
    return XtreamCredentials(baseUrl: base, username: user, password: pass);
  }

  if (segments.length == 4 &&
      const {'live', 'movie', 'series', 'timeshift'}
          .contains(segments[0].toLowerCase())) {
    return XtreamCredentials(
        baseUrl: base, username: segments[1], password: segments[2]);
  }

  if (segments.length == 3 && _looksLikeStreamId(segments[2])) {
    return XtreamCredentials(
        baseUrl: base, username: segments[0], password: segments[1]);
  }

  return null;
}

bool _looksLikeStreamId(String s) {
  final dot = s.indexOf('.');
  final id = dot < 0 ? s : s.substring(0, dot);
  return id.isNotEmpty && int.tryParse(id) != null;
}
