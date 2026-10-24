/// A user-provided content source. Zapline ships no sources of its own.
sealed class Source {
  const Source({required this.id, required this.name});

  final String id;
  final String name;
}

/// A server speaking the Xtream-compatible `player_api.php` protocol.
final class XtreamSource extends Source {
  const XtreamSource({
    required super.id,
    required super.name,
    required this.credentials,
  });

  final XtreamCredentials credentials;
}

/// A plain M3U/M3U8 playlist, optionally with external XMLTV guides.
final class M3uSource extends Source {
  const M3uSource({
    required super.id,
    required super.name,
    required this.url,
    this.epgUrls = const [],
  });

  final Uri url;
  final List<Uri> epgUrls;
}

/// A MAC-authenticated Stalker/Ministra portal.
final class StalkerSource extends Source {
  const StalkerSource({
    required super.id,
    required super.name,
    required this.portalUrl,
    required this.macAddress,
  });

  final Uri portalUrl;
  final String macAddress;
}

class XtreamCredentials {
  const XtreamCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  /// Scheme, host and port only, e.g. `http://example.com:8080`.
  final Uri baseUrl;
  final String username;
  final String password;

  @override
  bool operator ==(Object other) =>
      other is XtreamCredentials &&
      other.baseUrl == baseUrl &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => Object.hash(baseUrl, username, password);

  @override
  String toString() => 'XtreamCredentials($baseUrl, $username, ***)';
}
