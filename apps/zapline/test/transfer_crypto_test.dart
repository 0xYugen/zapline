import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/pairing/backup_server.dart';
import 'package:zapline/src/pairing/transfer_crypto.dart';

void main() {
  test('a sealed setup opens only with its key', () async {
    final key = TransferCipher.newKey();
    final sealed = await TransferCipher.seal('{"password":"s3cret"}', key);
    expect(sealed, isNot(contains('s3cret')));
    expect(TransferCipher.isSealed(sealed), isTrue);
    expect(await TransferCipher.open(sealed, key), '{"password":"s3cret"}');
    await expectLater(
      TransferCipher.open(sealed, TransferCipher.newKey()),
      throwsA(anything),
    );
  });

  test('a receiving device opens sealed setups and keeps its own', () async {
    String? got;
    final server = (await BackupServer.start(
      pin: '1234',
      bindTo: InternetAddress.loopbackIPv4,
      export: null,
      encrypted: true,
      restore: (json) async {
        got = json;
        return 'ok';
      },
    ))!;
    addTearDown(server.close);
    final key = Uri.splitQueryString(server.url.fragment)['k']!;
    final client = HttpClient();
    addTearDown(client.close);
    Future<int> call(String method, String path, {String? body}) async {
      final req = await client.open(method, '127.0.0.1', server.port, path);
      req.headers.set('x-zapline-pin', '1234');
      if (body != null) req.write(body);
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode;
    }

    expect(await call('GET', '/backup.json'), 404);
    final body = await TransferCipher.seal(
      jsonEncode({'format': 'zapline-backup', 'version': 2, 'sources': []}),
      key,
    );
    expect(await call('POST', '/restore', body: body), 200);
    expect(got, contains('zapline-backup'));
  });
}
