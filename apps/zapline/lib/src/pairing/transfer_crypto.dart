import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Encrypts a setup sent from one Zapline to another over the home Wi-Fi
/// (it carries every password). The key travels only in the QR code's
/// fragment, which browsers and servers never see, so someone listening on
/// the network can't read the transfer even with the 4-digit code.
abstract final class TransferCipher {
  static final _aes = AesGcm.with256bits();

  /// A fresh random key, URL-safe.
  static String newKey() {
    final r = Random.secure();
    return base64Url
        .encode([for (var i = 0; i < 32; i++) r.nextInt(256)])
        .replaceAll('=', '');
  }

  static List<int> _bytes(String key) =>
      base64Url.decode(key.padRight((key.length + 3) ~/ 4 * 4, '='));

  static bool isSealed(String body) {
    try {
      final j = jsonDecode(body);
      return j is Map && j['zapline-enc'] == 1;
    } on FormatException {
      return false;
    }
  }

  static Future<String> seal(String text, String key) async {
    final box = await _aes.encrypt(
      utf8.encode(text),
      secretKey: SecretKey(_bytes(key)),
    );
    return jsonEncode({
      'zapline-enc': 1,
      'nonce': base64.encode(box.nonce),
      'data': base64.encode(box.cipherText),
      'mac': base64.encode(box.mac.bytes),
    });
  }

  /// The text sealed in [body]; throws when the key is wrong or the data
  /// was changed on the way.
  static Future<String> open(String body, String key) async {
    final j = jsonDecode(body) as Map;
    final clear = await _aes.decrypt(
      SecretBox(
        base64.decode(j['data'] as String),
        nonce: base64.decode(j['nonce'] as String),
        mac: Mac(base64.decode(j['mac'] as String)),
      ),
      secretKey: SecretKey(_bytes(key)),
    );
    return utf8.decode(clear);
  }
}

/// Whether [a] is on the local network (or this device): the only places
/// Zapline's small servers answer.
bool isLocalAddress(InternetAddress a) {
  if (a.isLoopback || a.isLinkLocal) return true;
  final b = a.rawAddress;
  if (a.type == InternetAddressType.IPv4) {
    return b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168) ||
        // Carrier-grade NAT, used by some home routers and hotspots.
        (b[0] == 100 && b[1] >= 64 && b[1] <= 127);
  }
  // IPv6 unique local (fc00::/7); IPv4-mapped addresses are checked above
  // by the platform as IPv4.
  return (b[0] & 0xFE) == 0xFC;
}
