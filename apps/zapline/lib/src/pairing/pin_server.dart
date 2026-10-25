import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'transfer_crypto.dart';

/// Base for the small LAN servers that let a phone or a PC browser talk to
/// the TV (pairing, backup). They run only while their screen is open, bind
/// to the LAN, answer only devices on it, require the PIN shown on screen,
/// and stop answering a device after repeated wrong PINs. Nothing leaves
/// the local network.
abstract class PinServer {
  PinServer(this._server, this.pin, this.address) {
    _server
      ..idleTimeout = const Duration(seconds: 20)
      ..listen(_handle, onError: (Object _) {});
  }

  static const maxFailures = 5;
  static const lockedMessage =
      'Too many wrong codes. Reopen the screen on the TV to get a new one.';

  final HttpServer _server;

  /// Four digits shown on the TV.
  final String pin;

  /// LAN address to open, e.g. `192.168.1.24`.
  final String address;

  /// This device's other LAN addresses, best first: the QR code carries
  /// them too, for when [address] isn't the one the phone can reach (a TV
  /// with Ethernet and Wi-Fi, Wi-Fi Direct, a VPN).
  List<String> alternates = const [];

  /// Wrong codes by the device that sent them: one device guessing can't
  /// lock everyone else out.
  final _failures = <String, int>{};

  /// Extra secret carried in the QR code's fragment (never sent over the
  /// network by browsers); `null` when the server doesn't need one.
  String? get fragmentKey => null;

  int get port => _server.port;

  /// URL for the QR code; carries the PIN so scanning is enough.
  Uri get url => Uri(
    scheme: 'http',
    host: address,
    port: port,
    path: '/',
    queryParameters: {
      'pin': pin,
      if (alternates.isNotEmpty) 'alt': alternates.join(','),
    },
    fragment: fragmentKey == null ? null : 'k=$fragmentKey',
  );

  /// Address to type by hand (PIN entered on the page).
  String get shortUrl => '$address:$port';

  /// Binds a server and returns `(server, address, pin, other addresses)`,
  /// or `null` when the device has no LAN address.
  static Future<(HttpServer, String, String, List<String>)?> bind({
    String? pin,
    InternetAddress? bindTo,
  }) async {
    final all = bindTo != null ? [bindTo.address] : await lanAddresses();
    if (all.isEmpty) return null;
    final server = await HttpServer.bind(bindTo ?? InternetAddress.anyIPv4, 0);
    return (
      server,
      all.first,
      pin ?? (Random.secure().nextInt(9000) + 1000).toString(),
      all.sublist(1, all.length.clamp(1, 4)),
    );
  }

  /// Stops listening. Requests already being answered still complete.
  Future<void> close() => _server.close();

  /// Best guess at this device's LAN IPv4 address.
  static Future<String?> lanAddress() async =>
      (await lanAddresses()).firstOrNull;

  /// This device's IPv4 addresses, the home network's first: Wi-Fi and
  /// Ethernet before Wi-Fi Direct, hotspots, VPNs and virtual machines,
  /// which a phone on the same Wi-Fi can't reach.
  static Future<List<String>> lanAddresses() async {
    final List<NetworkInterface> ifaces;
    try {
      ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    } catch (_) {
      return const [];
    }
    final ranked = <(int, int, String)>[
      for (final i in ifaces)
        for (final a in i.addresses)
          if (!a.isLoopback && !a.isLinkLocal)
            (addressRank(i.name, a), 0, a.address),
    ];
    // Equal ranks keep the system's order.
    final ordered = [for (final (i, (r, _, ip)) in ranked.indexed) (r, i, ip)]
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2 - b.$2);
    return [for (final (_, _, ip) in ordered) ip];
  }

  static final _virtual = RegExp(
    r'^(p2p|ap\d|swlan|softap|tun|tap|ppp|wg|ipsec|rmnet|ccmni|docker|veth|'
    r'br-|virbr|dummy|vboxnet|vmnet|utun|zt)|vethernet|virtualbox|vmware|'
    r'hyper-v|tailscale|wireguard|vpn',
  );

  /// Lower is likelier to be the home network.
  static int addressRank(String interface, InternetAddress a) {
    var rank = 0;
    if (!isLocalAddress(a)) rank += 20;
    if (_virtual.hasMatch(interface.toLowerCase())) rank += 10;
    // Android's Wi-Fi Direct and hotspot networks.
    final ip = a.address;
    if (ip.startsWith('192.168.49.') || ip.startsWith('192.168.43.')) {
      rank += 5;
    }
    return rank;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    final from = req.connectionInfo?.remoteAddress;
    if (from == null || !isLocalAddress(from)) {
      res.statusCode = HttpStatus.forbidden;
      await res.close();
      return;
    }
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

  /// The PIN a request carries: the `x-zapline-pin` header (apps) or the
  /// `pin` query parameter (the browser page).
  static String? pinOf(HttpRequest req) =>
      req.headers.value('x-zapline-pin') ?? req.uri.queryParameters['pin'];

  /// Checks the request's PIN, counting failures per device. On failure the
  /// JSON error has been written and `false` is returned.
  bool checkPin(HttpRequest req, HttpResponse res, {String? candidate}) {
    final who = req.connectionInfo?.remoteAddress.address ?? '';
    final failures = _failures[who] ?? 0;
    if (failures >= maxFailures) {
      writeJson(res, HttpStatus.tooManyRequests, false, lockedMessage);
      return false;
    }
    if ((candidate ?? pinOf(req)) == pin) return true;
    _failures[who] = failures + 1;
    writeJson(
      res,
      HttpStatus.forbidden,
      false,
      failures + 1 >= maxFailures
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
