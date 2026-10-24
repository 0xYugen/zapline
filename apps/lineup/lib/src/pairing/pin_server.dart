import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Base for the small LAN servers that let a phone or a PC browser talk to
/// the TV (pairing, backup). They run only while their screen is open, bind
/// to the LAN, require the PIN shown on screen, and lock after repeated
/// wrong PINs. Nothing leaves the local network.
abstract class PinServer {
  PinServer(this._server, this.pin, this.address) {
    _server.listen(_handle, onError: (Object _) {});
  }

  static const maxFailures = 5;
  static const lockedMessage =
      'Too many wrong codes. Reopen the screen on the TV to get a new one.';

  final HttpServer _server;

  /// Four digits shown on the TV.
  final String pin;

  /// LAN address to open, e.g. `192.168.1.24`.
  final String address;
  int _failures = 0;

  int get port => _server.port;

  /// URL for the QR code; carries the PIN so scanning is enough.
  Uri get url => Uri(
    scheme: 'http',
    host: address,
    port: port,
    path: '/',
    queryParameters: {'pin': pin},
  );

  /// Address to type by hand (PIN entered on the page).
  String get shortUrl => '$address:$port';

  /// Binds a server and returns `(server, address, pin)`, or `null` when the
  /// device has no LAN address.
  static Future<(HttpServer, String, String)?> bind({
    String? pin,
    InternetAddress? bindTo,
  }) async {
    final address = bindTo?.address ?? await lanAddress();
    if (address == null) return null;
    final server = await HttpServer.bind(bindTo ?? InternetAddress.anyIPv4, 0);
    return (
      server,
      address,
      pin ?? (Random.secure().nextInt(9000) + 1000).toString(),
    );
  }

  /// Stops listening. Requests already being answered still complete.
  Future<void> close() => _server.close();

  /// Best guess at this device's LAN IPv4 address: private ranges first.
  static Future<String?> lanAddress() async {
    final List<NetworkInterface> ifaces;
    try {
      ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    } catch (_) {
      return null;
    }
    final candidates = [
      for (final i in ifaces)
        for (final a in i.addresses)
          if (!a.isLoopback && !a.isLinkLocal) a.address,
    ];
    int rank(String ip) {
      if (ip.startsWith('192.168.')) return 0;
      if (ip.startsWith('10.')) return 1;
      final m = RegExp(r'^172\.(\d+)\.').firstMatch(ip);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        if (n >= 16 && n <= 31) return 2;
      }
      return 3;
    }

    candidates.sort((a, b) => rank(a).compareTo(rank(b)));
    return candidates.firstOrNull;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    res.headers
      ..set('Cache-Control', 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer');
    try {
      await handle(req);
    } catch (_) {
      res.statusCode = HttpStatus.internalServerError;
    }
    await res.close();
  }

  /// Serves one request; the response is closed afterwards.
  Future<void> handle(HttpRequest req);

  /// Checks [candidate] against the PIN, counting failures. On failure the
  /// JSON error has been written and `false` is returned.
  bool checkPin(String? candidate, HttpResponse res) {
    if (_failures >= maxFailures) {
      writeJson(res, HttpStatus.tooManyRequests, false, lockedMessage);
      return false;
    }
    if (candidate == pin) return true;
    _failures++;
    writeJson(
      res,
      HttpStatus.forbidden,
      false,
      _failures >= maxFailures
          ? lockedMessage
          : 'Wrong code. Check the 4 digits shown on the TV.',
    );
    return false;
  }

  static void writeJson(HttpResponse res, int status, bool ok, String msg) {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode({'ok': ok, 'message': msg}));
  }

  /// Reads a request body, refusing anything larger than [maxBytes].
  static Future<String?> readBody(HttpRequest req, int maxBytes) async {
    final chunks = <int>[];
    await for (final c in req) {
      chunks.addAll(c);
      if (chunks.length > maxBytes) return null;
    }
    return utf8.decode(chunks, allowMalformed: true);
  }
}
