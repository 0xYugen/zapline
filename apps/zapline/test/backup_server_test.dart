import 'dart:convert';
import 'dart:io';

import 'package:zapline/src/pairing/backup_server.dart';
import 'package:test/test.dart';

void main() {
  late BackupServer server;
  String? restored;

  setUp(() async {
    restored = null;
    server = (await BackupServer.start(
      pin: '1234',
      bindTo: InternetAddress.loopbackIPv4,
      export: () => '{"format":"zapline-backup"}',
      restore: (json) async {
        restored = json;
        return '1 sources restored';
      },
    ))!;
  });
  tearDown(() => server.close());

  Future<(int, String, HttpHeaders)> call(
    String method,
    String path, [
    String? body,
  ]) async {
    final client = HttpClient();
    try {
      final req = await client.open(method, '127.0.0.1', server.port, path);
      if (body != null) req.write(body);
      final res = await req.close();
      return (res.statusCode, await utf8.decodeStream(res), res.headers);
    } finally {
      client.close();
    }
  }

  test('download requires the PIN and is sent as an attachment', () async {
    expect((await call('GET', '/backup.json?pin=0000')).$1, 403);
    final (code, body, headers) = await call('GET', '/backup.json?pin=1234');
    expect(code, 200);
    expect(body, contains('zapline-backup'));
    expect(headers.value('content-disposition'), contains('attachment'));
  });

  test('restore passes the file to the app and reports back', () async {
    final (code, body, _) = await call(
      'POST',
      '/restore?pin=1234',
      '{"format":"zapline-backup","version":1,"sources":[]}',
    );
    expect(code, 200);
    expect(jsonDecode(body)['message'], 'Done: 1 sources restored.');
    expect(restored, contains('zapline-backup'));
  });
}
