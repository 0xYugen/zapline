import 'dart:io';

import 'pairing_page.dart';
import 'pin_server.dart';
import 'setup_receiver.dart';
import 'transfer_crypto.dart';

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

/// Lets a phone fill in a source for this TV over the LAN, so nobody types
/// long URLs with a remote. Runs while the add-source screen is open.
///
/// The same code serves both ways of using a phone: its camera opens the
/// page to type a source in, and Zapline on it ([onSetup]) sends its whole
/// setup, sealed with the key in the code's fragment.
class PairingServer extends PinServer {
  PairingServer._(
    super.server,
    super.pin,
    super.address,
    this._onSubmit,
    this._onSetup,
    this._key,
  );

  final Future<PairingReply> Function(PairingSubmission) _onSubmit;
  final Future<String> Function(String json)? _onSetup;
  final String? _key;

  @override
  String? get fragmentKey => _key;

  static Future<PairingServer?> start({
    required Future<PairingReply> Function(PairingSubmission) onSubmit,
    Future<String> Function(String json)? onSetup,
    String? pin,
    InternetAddress? bindTo,
  }) async {
    final b = await PinServer.bind(pin: pin, bindTo: bindTo);
    if (b == null) return null;
    final (server, address, p, others) = b;
    return PairingServer._(
      server,
      p,
      address,
      onSubmit,
      onSetup,
      onSetup == null ? null : TransferCipher.newKey(),
    )..alternates = others;
  }

  @override
  Future<void> handle(HttpRequest req) async {
    if (await serveSetup(
      this,
      req,
      name: Platform.localHostname,
      key: _key,
      restore: _onSetup,
    )) {
      return;
    }
    final res = req.response;
    if (req.method == 'GET' && req.uri.path == '/') {
      res.headers.contentType = ContentType.html;
      res.write(pairingPage(pin: req.uri.queryParameters['pin'] ?? ''));
    } else if (req.method == 'POST' && req.uri.path == '/add') {
      await _add(req);
    } else {
      res.statusCode = HttpStatus.notFound;
    }
  }

  Future<void> _add(HttpRequest req) async {
    final res = req.response;
    final body = await PinServer.readBody(req, 16 * 1024);
    if (body == null) {
      res.statusCode = HttpStatus.requestEntityTooLarge;
      return;
    }
    final form = Uri.splitQueryString(body);
    if (!checkPin(req, res, candidate: form['pin'])) return;
    final url = (form['url'] ?? '').trim();
    if (url.isEmpty) {
      PinServer.writeJson(
        res,
        HttpStatus.badRequest,
        false,
        'Enter an address.',
      );
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
    PinServer.writeJson(
      res,
      reply.ok ? HttpStatus.ok : HttpStatus.unprocessableEntity,
      reply.ok,
      reply.message,
    );
  }
}
