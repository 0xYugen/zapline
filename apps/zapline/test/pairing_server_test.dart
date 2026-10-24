import 'dart:convert';
import 'dart:io';

import 'package:zapline/src/pairing/pairing_server.dart';
import 'package:test/test.dart';

/// Plain `test` (no widget binding) so real sockets are used.
void main() {
  late PairingServer server;
  final received = <PairingSubmission>[];

  setUp(() async {
    received.clear();
    server = (await PairingServer.start(
      pin: '4729',
      bindTo: InternetAddress.loopbackIPv4,
      onSubmit: (s) async {
        received.add(s);
        return const PairingReply.ok('Done! 6 channels added.');
      },
    ))!;
  });
  tearDown(() => server.close());

  Future<(int, Map<String, Object?>)> post(Map<String, String> form) async {
    final client = HttpClient();
    try {
      final req = await client.post('127.0.0.1', server.port, '/add');
      req.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      req.write(Uri(queryParameters: form).query);
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      return (res.statusCode, jsonDecode(body) as Map<String, Object?>);
    } finally {
      client.close();
    }
  }

  test('serves the form with the PIN prefilled and escaped', () async {
    final client = HttpClient();
    addTearDown(client.close);
    final req = await client.get(
      '127.0.0.1',
      server.port,
      '/?pin=47%3Cscript%3E29',
    );
    final res = await req.close();
    final html = await utf8.decodeStream(res);
    expect(res.statusCode, 200);
    expect(html, contains('name="pin" value="4729"'));
    expect(html, isNot(contains('<script>29')));
    expect(server.url.queryParameters['pin'], '4729');
  });

  test('accepts a submission with the right PIN', () async {
    final (code, body) = await post({
      'pin': '4729',
      'url': ' http://p.example/get.php?username=a&password=b ',
      'guide': 'http://g.example/epg.xml',
    });
    expect(code, 200);
    expect(body['ok'], isTrue);
    expect(
      received.single.url,
      'http://p.example/get.php?username=a&password=b',
    );
    expect(received.single.guideUrl, 'http://g.example/epg.xml');
  });

  test('rejects wrong PINs and locks after five', () async {
    for (var i = 0; i < 5; i++) {
      final (code, _) = await post({'pin': '0000', 'url': 'http://x'});
      expect(code, 403);
    }
    final (code, body) = await post({'pin': '4729', 'url': 'http://x'});
    expect(code, 429, reason: 'locked even with the right PIN');
    expect(body['message'], contains('Too many'));
    expect(received, isEmpty);
  });
}
