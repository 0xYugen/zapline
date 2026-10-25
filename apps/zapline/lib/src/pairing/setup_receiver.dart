import 'dart:io';

import 'pin_server.dart';
import 'transfer_crypto.dart';

/// The two requests another Zapline makes to send its whole setup here
/// (Settings → Send to another device): `GET /hello` to check it found the
/// right device, `POST /restore` with the backup, sealed with the key the
/// QR code carries in its fragment. Shared by every screen showing a code
/// a phone may scan with Zapline.
///
/// Returns false for any other request.
Future<bool> serveSetup(
  PinServer server,
  HttpRequest req, {
  required String name,
  required String? key,
  required Future<String> Function(String json)? restore,
}) async {
  final res = req.response;
  switch ((req.method, req.uri.path)) {
    case ('GET', '/hello'):
      if (!server.checkPin(req, res)) return true;
      PinServer.writeJson(res, HttpStatus.ok, true, name);
      return true;
    case ('POST', '/restore') when restore != null:
      if (!server.checkPin(req, res)) return true;
      var body = await PinServer.readBody(req, maxSetupBytes);
      if (body == null) {
        PinServer.writeJson(
          res,
          HttpStatus.requestEntityTooLarge,
          false,
          'The file is too large to be a Zapline backup.',
        );
        return true;
      }
      try {
        if (TransferCipher.isSealed(body)) {
          if (key == null) throw const FormatException('Not expected here.');
          body = await TransferCipher.open(body, key);
        }
        final summary = await restore(body);
        PinServer.writeJson(res, HttpStatus.ok, true, 'Done: $summary.');
      } catch (e) {
        PinServer.writeJson(
          res,
          HttpStatus.unprocessableEntity,
          false,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
      return true;
  }
  return false;
}

const maxSetupBytes = 5 << 20;
