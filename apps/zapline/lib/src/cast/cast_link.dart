import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:zapline_data/zapline_data.dart';

/// "Send to TV" between Zapline devices on the home network: a phone finds
/// the TVs and PCs running Zapline (a UDP broadcast they answer), then tells
/// one what to play and works as its remote. The phone stops playing, so
/// the account keeps a single stream.
///
/// A device only obeys a phone that has the same source (the request names
/// it by a hash of its address and user), so someone else on the network
/// can't take over the TV.

/// UDP port the receivers listen on for discovery.
const castDiscoveryPort = 47917;
const _hello = 'ZAPLINE-CAST?';

/// Identifies a source across devices without revealing its credentials.
String sourceFingerprint(SourceRecord s) => sha256
    .convert(
      utf8.encode(
        'zapline-cast:${s.kind.name}|${s.url.trim().toLowerCase()}|${s.username}',
      ),
    )
    .toString()
    .substring(0, 24);

/// A Zapline device that can receive.
class CastDevice {
  const CastDevice({
    required this.name,
    required this.address,
    required this.port,
  });

  final String name;
  final InternetAddress address;
  final int port;

  Uri _uri(String path) =>
      Uri(scheme: 'http', host: address.address, port: port, path: path);

  @override
  bool operator ==(Object other) =>
      other is CastDevice && other.address == address && other.port == port;

  @override
  int get hashCode => Object.hash(address, port);
}

/// What the receiving device plays now.
typedef CastStatus = ({String title, String? subtitle});

/// What a receiving device does with a phone's commands.
abstract interface class CastHandler {
  /// Plays what [request] describes; returns an error message for the
  /// phone, or `null` when playing.
  Future<String?> castPlay(Map<String, Object?> request);

  /// "up", "down" (channels) or "toggle" (pause).
  void castKey(String key);

  void castStop();

  CastStatus? get castStatus;
}

/// Answers discovery and serves commands while the app is open.
class CastReceiver {
  CastReceiver._(this._udp, this._http, this._handler, this.name);

  final RawDatagramSocket _udp;
  final HttpServer _http;
  final CastHandler _handler;
  final String name;

  int get port => _http.port;

  static Future<CastReceiver?> start(
    CastHandler handler, {
    String? name,
  }) async {
    try {
      final http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      final udp = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        castDiscoveryPort,
        reuseAddress: true,
      );
      final r = CastReceiver._(
        udp,
        http,
        handler,
        name ?? Platform.localHostname,
      );
      udp.listen(r._onDatagram);
      http.listen(r._onRequest, onError: (_) {});
      return r;
    } on SocketException {
      return null; // no network, or the port is taken by another app
    }
  }

  void _onDatagram(RawSocketEvent e) {
    if (e != RawSocketEvent.read) return;
    final d = _udp.receive();
    if (d == null || utf8.decode(d.data, allowMalformed: true) != _hello) {
      return;
    }
    _udp.send(
      utf8.encode(jsonEncode({'zapline': 1, 'name': name, 'port': port})),
      d.address,
      d.port,
    );
  }

  Future<void> _onRequest(HttpRequest req) async {
    final res = req.response;
    Future<void> reply(int status, Map<String, Object?> body) async {
      res
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await res.close();
    }

    try {
      switch ((req.method, req.uri.path)) {
        case ('POST', '/cast/play'):
          final body = await utf8.decoder.bind(req).join();
          if (body.length > 16384) return await reply(413, {'ok': false});
          final error = await _handler.castPlay(
            (jsonDecode(body) as Map).cast<String, Object?>(),
          );
          return await reply(error == null ? 200 : 403, {
            'ok': error == null,
            'message': ?error,
          });
        case ('POST', '/cast/key'):
          _handler.castKey(req.uri.queryParameters['key'] ?? '');
          return await reply(200, {'ok': true});
        case ('POST', '/cast/stop'):
          _handler.castStop();
          return await reply(200, {'ok': true});
        case ('GET', '/cast/status'):
          final s = _handler.castStatus;
          return await reply(200, {
            'ok': true,
            'playing': s != null,
            if (s != null) 'title': s.title,
            if (s != null) 'subtitle': s.subtitle,
          });
        default:
          return await reply(404, {'ok': false});
      }
    } catch (_) {
      return await reply(400, {'ok': false});
    }
  }

  Future<void> close() async {
    _udp.close();
    await _http.close(force: true);
  }
}

/// The phone's side.
abstract final class CastClient {
  /// Zapline devices answering on the local network within [wait].
  static Future<List<CastDevice>> discover({
    Duration wait = const Duration(milliseconds: 1600),
    int? ownPort,
  }) async {
    final found = <CastDevice>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
        ..broadcastEnabled = true;
      final s = socket;
      s.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = s.receive();
        if (d == null) return;
        try {
          final m = jsonDecode(utf8.decode(d.data)) as Map;
          if (m['zapline'] != 1 || m['port'] is! int) return;
          found.add(
            CastDevice(
              name: '${m['name']}',
              address: d.address,
              port: m['port'] as int,
            ),
          );
        } catch (_) {}
      });
      final hello = utf8.encode(_hello);
      for (var i = 0; i < 3; i++) {
        s.send(hello, InternetAddress('255.255.255.255'), castDiscoveryPort);
        await Future<void>.delayed(wait ~/ 3);
      }
    } on SocketException {
      // No network.
    } finally {
      socket?.close();
    }
    // This device answers its own broadcast too.
    final self = await _ownAddresses();
    return [
      for (final d in found)
        if (!(d.port == ownPort && self.contains(d.address.address))) d,
    ];
  }

  static Future<Set<String>> _ownAddresses() async {
    try {
      return {
        for (final i in await NetworkInterface.list())
          for (final a in i.addresses) a.address,
      };
    } on Object {
      return const {};
    }
  }

  static final _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  static Future<Map<String, Object?>> _call(
    CastDevice d,
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = d._uri(path).replace(queryParameters: query);
    final req = await _http.openUrl(method, uri);
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close().timeout(const Duration(seconds: 15));
    final text = await utf8.decoder.bind(res).join();
    return (jsonDecode(text) as Map).cast<String, Object?>();
  }

  /// Asks [d] to play; `null` on success, else the device's reason.
  static Future<String?> play(CastDevice d, Map<String, Object?> what) async {
    final r = await _call(d, 'POST', '/cast/play', body: what);
    return r['ok'] == true ? null : '${r['message'] ?? ''}';
  }

  static Future<void> key(CastDevice d, String key) =>
      _call(d, 'POST', '/cast/key', query: {'key': key});

  static Future<void> stop(CastDevice d) => _call(d, 'POST', '/cast/stop');

  static Future<CastStatus?> status(CastDevice d) async {
    final r = await _call(d, 'GET', '/cast/status');
    if (r['playing'] != true) return null;
    return (title: '${r['title']}', subtitle: r['subtitle'] as String?);
  }
}
