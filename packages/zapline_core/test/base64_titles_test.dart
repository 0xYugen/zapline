import 'dart:convert';

import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';

void main() {
  test('Base64 EPG titles are decoded', () {
    for (final t in ['Telegiornale', 'Caffè sport', 'Film: parte 2']) {
      expect(maybeBase64(base64.encode(utf8.encode(t))), t);
    }
  });

  test('plain titles that happen to be valid Base64 stay as they are', () {
    for (final t in ['Film', 'News', 'Golf', 'Meteo123', 'Rai1', 'TG24']) {
      expect(maybeBase64(t), t);
    }
  });
}
