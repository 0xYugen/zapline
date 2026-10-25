/// Stream addresses from IPTV providers carry the account's user name and
/// password (`/live/USER/PASS/123.ts`, `?username=…&password=…`). Zapline
/// stores them with placeholders instead, and puts the credentials back
/// only when a stream is opened, so the database never holds them.
library;

const credentialUser = '{user}';
const credentialPass = '{pass}';

/// [u] with [user] and [pass] replaced by placeholders, where they appear as
/// consecutive path segments or as `username` / `password` query values.
Uri hideCredentials(Uri u, String user, String pass) {
  if (user.isEmpty || pass.isEmpty) return u;
  var out = u;
  final segs = u.pathSegments;
  for (var i = 0; i + 1 < segs.length; i++) {
    if (segs[i] == user && segs[i + 1] == pass) {
      out = out.replace(
        pathSegments: [
          ...segs.take(i),
          credentialUser,
          credentialPass,
          ...segs.skip(i + 2),
        ],
      );
      break;
    }
  }
  final q = u.queryParameters;
  if (q['username'] == user || q['password'] == pass) {
    out = out.replace(
      queryParameters: {
        for (final MapEntry(:key, :value) in q.entries)
          key: switch (key) {
            'username' when value == user => credentialUser,
            'password' when value == pass => credentialPass,
            _ => value,
          },
      },
    );
  }
  return out;
}

bool hasCredentialPlaceholders(Uri u) =>
    u.pathSegments.contains(credentialUser) ||
    u.queryParameters.containsValue(credentialUser);

/// [u] with the placeholders [hideCredentials] put back to [user], [pass].
Uri revealCredentials(Uri u, String user, String pass) {
  if (!hasCredentialPlaceholders(u) &&
      !u.queryParameters.containsValue(credentialPass)) {
    return u;
  }
  String swap(String v) => switch (v) {
        credentialUser => user,
        credentialPass => pass,
        _ => v,
      };
  var out = u.replace(pathSegments: [for (final s in u.pathSegments) swap(s)]);
  if (u.hasQuery) {
    out = out.replace(
      queryParameters: {
        for (final MapEntry(:key, :value) in u.queryParameters.entries)
          key: swap(value),
      },
    );
  }
  return out;
}

/// The user name and password in a playlist link such as
/// `http://host/get.php?username=U&password=P&type=m3u_plus`, if any.
(String, String)? credentialsInLink(String link) {
  final u = Uri.tryParse(link);
  final user = u?.queryParameters['username'];
  final pass = u?.queryParameters['password'];
  if (user == null || pass == null || user.isEmpty || pass.isEmpty) {
    return null;
  }
  return (user, pass);
}

final _secretQuery = RegExp(
  r'((?:username|password|pass|token|key)=)[^&\s,)"]+',
  caseSensitive: false,
);
final _secretPath = RegExp(
  r'/(live|movie|series|timeshift)/[^/\s]+/[^/\s]+/',
);

/// [text] (an error, a log line) without account credentials: query values
/// such as `password=` and the user/password segments of stream paths.
String redactSecrets(String text) => text
    .replaceAllMapped(_secretQuery, (m) => '${m[1]}***')
    .replaceAllMapped(_secretPath, (m) => '/${m[1]}/***/***/');
