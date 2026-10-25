import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:zapline_data/zapline_data.dart';

import '../pairing/transfer_crypto.dart';

/// "Send to TV" between Zapline devices on the home network: a phone finds
/// the TVs and PCs running Zapline (a UDP broadcast they answer), then tells
/// one what to play and works as its remote. The phone stops playing, so
/// the account keeps a single stream.
///
/// Safety: devices answer only the local network; a phone pairs once with a
/// code shown on the TV and then sends a token with every command; and the
/// TV plays only sources it has itself (named by a hash that includes the
/// password).

/// UDP port the receivers listen on for discovery.
const castDiscoveryPort = 47917;
const _hello = 'ZAPLINE-CAST?';
const _maxBody = 16 * 1024;

/// Identifies a source across devices without revealing its credentials.
String sourceFingerprint(SourceRecord s) => sha256
    .convert(
      utf8.encode(
        'zapline-cast:${s.kind.name}|${s.url.trim()}|${s.username}|'
        '${s.password}',
      ),
    )
    .toString()
    .substring(0, 32);

/// A Zapline device that can receive.
class CastDevice {
  const CastDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
  });

  /// Stable per installation; pairings are kept by it.
  final String id;
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
  /// Plays what [request] describes; returns an error code for the phone
  /// ("unknown-source", "locked"…), or `null` when playing.
  Future<String?> castPlay(Map<String, Object?> request);

  /// "up", "down" (channels) or "toggle" (pause).
  void castKey(String key);

  void castStop();

  CastStatus? get castStatus;

  /// Shows [code] for the user to type on the phone [from]; `null` hides
  /// it.
  void castShowCode(String? code, String from);

  /// Remembers a newly paired phone; returns its token.
  String castPaired(String from);

  bool castTrusts(String token);
}

/// A new random token or id.
String castSecret() {
  final r = Random.secure();
  return base64Url
      .encode([for (var i = 0; i < 24; i++) r.nextInt(256)])
      .replaceAll('=', '');
}

/// Answers discovery and serves commands while the app is open.
class CastReceiver {
  CastReceiver._(this._udp, this._http, this._handler, this.name, this.id);

  final RawDatagramSocket _udp;
  final HttpServer _http;
  final CastHandler _handler;
  final String name;
  final String id;

  int get port => _http.port;

  // The pairing code on screen, who asked for it and how long it lasts.
  String? _code;
  String _codeFrom = '';
  DateTime _codeUntil = DateTime(0);
  int _codeTries = 0;

  static Future<CastReceiver?> start(
    CastHandler handler, {
    required String id,
    String? name,
  }) async {
    try {
      final http = await HttpServer.bind(InternetAddress.anyIPv4, 0)
        ..idleTimeout = const Duration(seconds: 20);
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
        id,
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
    if (d == null ||
        !isLocalAddress(d.address) ||
        utf8.decode(d.data, allowMalformed: true) != _hello) {
      return;
    }
    _udp.send(
      utf8.encode(
        jsonEncode({'zapline': 2, 'id': id, 'name': name, 'port': port}),
      ),
      d.address,
      d.port,
    );
  }

  static Future<Map<String, Object?>?> _readJson(HttpRequest req) async {
    final bytes = <int>[];
    await for (final c in req) {
      bytes.addAll(c);
      if (bytes.length > _maxBody) return null;
    }
    if (bytes.isEmpty) return const {};
    return (jsonDecode(utf8.decode(bytes)) as Map).cast<String, Object?>();
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

    final from = req.connectionInfo?.remoteAddress;
    if (from == null || !isLocalAddress(from)) {
      return reply(403, {'ok': false});
    }
    try {
      final body = await _readJson(req);
      if (body == null) return await reply(413, {'ok': false});
      final path = req.uri.path;
      if (req.method == 'POST' && path == '/cast/pair') {
        _code = (Random.secure().nextInt(9000) + 1000).toString();
        _codeFrom = '${body['name'] ?? ''}'.trim();
        if (_codeFrom.length > 40) _codeFrom = _codeFrom.substring(0, 40);
        _codeUntil = DateTime.now().add(const Duration(minutes: 2));
        _codeTries = 0;
        _handler.castShowCode(_code, _codeFrom);
        return await reply(200, {'ok': true});
      }
      if (req.method == 'POST' && path == '/cast/pair/confirm') {
        final code = _code;
        if (code == null || DateTime.now().isAfter(_codeUntil)) {
          return await reply(410, {'ok': false, 'message': 'expired'});
        }
        if (body['code'] != code) {
          // Five wrong tries end this code; the phone has to ask again.
          if (++_codeTries >= 5) {
            _code = null;
            _handler.castShowCode(null, _codeFrom);
          }
          return await reply(403, {'ok': false, 'message': 'wrong-code'});
        }
        _code = null;
        _handler.castShowCode(null, _codeFrom);
        final token = _handler.castPaired(_codeFrom);
        return await reply(200, {'ok': true, 'token': token});
      }
      final token = req.headers.value('x-zapline-token');
      if (token == null || !_handler.castTrusts(token)) {
        return await reply(401, {'ok': false, 'message': 'unpaired'});
      }
      switch ((req.method, path)) {
        case ('POST', '/cast/play'):
          final error = await _handler.castPlay(body);
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

/// A request to a device failed; [code] says why ("unpaired",
/// "wrong-code", "expired", "unknown-source", "locked"…).
class CastException implements Exception {
  const CastException(this.code);

  final String code;

  @override
  String toString() => 'CastException($code)';
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
        if (d == null || !isLocalAddress(d.address)) return;
        try {
          final m = jsonDecode(utf8.decode(d.data)) as Map;
          if (m['zapline'] != 2 || m['port'] is! int || m['id'] is! String) {
            return;
          }
          found.add(
            CastDevice(
              id: m['id'] as String,
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
    String? token,
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = d._uri(path).replace(queryParameters: query);
    final req = await _http.openUrl(method, uri);
    if (token != null) req.headers.set('x-zapline-token', token);
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close().timeout(const Duration(seconds: 15));
    final text = await utf8.decoder.bind(res).join();
    final r = (jsonDecode(text) as Map).cast<String, Object?>();
    if (r['ok'] != true) throw CastException('${r['message'] ?? 'failed'}');
    return r;
  }

  /// Asks [d] to show a pairing code for this phone, called [name].
  static Future<void> pair(CastDevice d, String name) =>
      _call(d, 'POST', '/cast/pair', body: {'name': name});

  /// The token for [d] once [code] (typed by the user) matches.
  static Future<String> confirm(CastDevice d, String code) async {
    final r = await _call(
      d,
      'POST',
      '/cast/pair/confirm',
      body: {'code': code},
    );
    return '${r['token']}';
  }

  static Future<void> play(
    CastDevice d,
    String token,
    Map<String, Object?> what,
  ) => _call(d, 'POST', '/cast/play', token: token, body: what);

  static Future<void> key(CastDevice d, String token, String key) =>
      _call(d, 'POST', '/cast/key', token: token, query: {'key': key});

  static Future<void> stop(CastDevice d, String token) =>
      _call(d, 'POST', '/cast/stop', token: token);

  static Future<CastStatus?> status(CastDevice d, String token) async {
    final r = await _call(d, 'GET', '/cast/status', token: token);
    if (r['playing'] != true) return null;
    return (title: '${r['title']}', subtitle: r['subtitle'] as String?);
  }
}
