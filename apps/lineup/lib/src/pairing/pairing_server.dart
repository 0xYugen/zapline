import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'pairing_page.dart';

/// What a phone submitted through the pairing page.
class PairingSubmission {
  const PairingSubmission({
    required this.url,
    this.username = '',
    this.password = '',
    this.guideUrl = '',
  });

  final String url;
  final String username;
  final String password;
  final String guideUrl;
}

/// Outcome reported back to the phone.
class PairingReply {
  const PairingReply.ok(this.message) : ok = true;
  const PairingReply.error(this.message) : ok = false;

  final bool ok;
  final String message;
}

/// A tiny HTTP server on the local network that lets a phone fill in a
/// source for this TV, so nobody types long URLs with a remote.
///
/// It runs only while the add-source screen is open, binds to the LAN,
/// requires the PIN shown on the TV, and locks after repeated wrong PINs.
/// Nothing leaves the local network.
class PairingServer {
  PairingServer._(this._server, this.pin, this.address, this._onSubmit);

  static const _maxFailures = 5;

  final HttpServer _server;

  /// Four digits shown on the TV.
  final String pin;

  /// LAN address the phone should open, e.g. `192.168.1.24`.
  final String address;
  final Future<PairingReply> Function(PairingSubmission) _onSubmit;
  int _failures = 0;

  int get port => _server.port;

  /// URL encoded in the QR code; carries the PIN so scanning is enough.
  Uri get url => Uri(
    scheme: 'http',
    host: address,
    port: port,
    path: '/',
    queryParameters: {'pin': pin},
  );

  /// URL to type by hand (PIN entered on the page).
  String get shortUrl => '$address:$port';

  static Future<PairingServer?> start({
    required Future<PairingReply> Function(PairingSubmission) onSubmit,
    String? pin,
    InternetAddress? bindTo,
  }) async {
    final address = bindTo?.address ?? await lanAddress();
    if (address == null) return null;
    final server = await HttpServer.bind(bindTo ?? InternetAddress.anyIPv4, 0);
    final p = pin ?? (Random.secure().nextInt(9000) + 1000).toString();
    final ps = PairingServer._(server, p, address, onSubmit);
    server.listen(ps._handle, onError: (Object _) {});
    return ps;
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
      if (req.method == 'GET' && req.uri.path == '/') {
        res.headers.contentType = ContentType.html;
        res.write(pairingPage(pin: req.uri.queryParameters['pin'] ?? ''));
      } else if (req.method == 'POST' && req.uri.path == '/add') {
        await _add(req);
      } else {
        res.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      res.statusCode = HttpStatus.internalServerError;
    }
    await res.close();
  }

  Future<void> _add(HttpRequest req) async {
    final res = req.response;
    res.headers.contentType = ContentType.json;
    if (_failures >= _maxFailures) {
      res.statusCode = HttpStatus.tooManyRequests;
      res.write(jsonEncode({'ok': false, 'message': _locked}));
      return;
    }
    final body = await utf8.decoder.bind(req).join();
    if (body.length > 16 * 1024) {
      res.statusCode = HttpStatus.requestEntityTooLarge;
      return;
    }
    final form = Uri.splitQueryString(body);
    if (form['pin'] != pin) {
      _failures++;
      res.statusCode = HttpStatus.forbidden;
      res.write(
        jsonEncode({
          'ok': false,
          'message': _failures >= _maxFailures
              ? _locked
              : 'Wrong code. Check the 4 digits shown on the TV.',
        }),
      );
      return;
    }
    final url = (form['url'] ?? '').trim();
    if (url.isEmpty) {
      res.statusCode = HttpStatus.badRequest;
      res.write(jsonEncode({'ok': false, 'message': 'Enter an address.'}));
      return;
    }
    final reply = await _onSubmit(
      PairingSubmission(
        url: url,
        username: (form['username'] ?? '').trim(),
        password: form['password'] ?? '',
        guideUrl: (form['guide'] ?? '').trim(),
      ),
    );
    res.statusCode = reply.ok ? HttpStatus.ok : HttpStatus.unprocessableEntity;
    res.write(jsonEncode({'ok': reply.ok, 'message': reply.message}));
  }

  static const _locked =
      'Too many wrong codes. Reopen "Add a source" on the TV to get a new one.';
}
