import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/cast/cast_link.dart';

class _Handler implements CastHandler {
  final played = <Map<String, Object?>>[];
  final keys = <String>[];
  bool stopped = false;

  @override
  Future<String?> castPlay(Map<String, Object?> r) async {
    if (r['source'] != 'abc') return 'unknown-source';
    played.add(r);
    return null;
  }

  @override
  void castKey(String key) => keys.add(key);

  @override
  void castStop() => stopped = true;

  @override
  CastStatus? get castStatus =>
      played.isEmpty ? null : (title: 'Rai 1', subtitle: 'Tg1');

  String? shownCode;
  final tokens = <String>{};

  @override
  void castShowCode(String? code, String from) => shownCode = code;

  @override
  String castPaired(String from) {
    final t = castSecret();
    tokens.add(t);
    return t;
  }

  @override
  bool castTrusts(String token) => tokens.contains(token);
}

void main() {
  test('a phone pairs with the TV, then drives it', () async {
    final h = _Handler();
    final r = (await CastReceiver.start(h, id: 'tv-1', name: 'Soggiorno'))!;
    addTearDown(r.close);

    // Discovery: the TV answers a hello with its id, name and port.
    final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(udp.close);
    udp.send(
      utf8.encode('ZAPLINE-CAST?'),
      InternetAddress.loopbackIPv4,
      castDiscoveryPort,
    );
    final reply = await udp
        .where((e) => e == RawSocketEvent.read)
        .map((_) => udp.receive())
        .firstWhere((d) => d != null)
        .timeout(const Duration(seconds: 3));
    final m = jsonDecode(utf8.decode(reply!.data)) as Map;
    expect(m['name'], 'Soggiorno');
    expect(m['id'], 'tv-1');
    expect(m['port'], r.port);

    final tv = CastDevice(
      id: 'tv-1',
      name: 'Soggiorno',
      address: InternetAddress.loopbackIPv4,
      port: r.port,
    );
    // Not paired: nothing works.
    await expectLater(
      CastClient.status(tv, 'guess'),
      throwsA(isA<CastException>().having((e) => e.code, 'code', 'unpaired')),
    );
    await expectLater(
      CastClient.stop(tv, 'guess'),
      throwsA(isA<CastException>()),
    );
    expect(h.stopped, isFalse);

    // Pairing: the TV shows a code, a wrong one is refused.
    await CastClient.pair(tv, 'Pixel');
    expect(h.shownCode, hasLength(4));
    await expectLater(
      CastClient.confirm(tv, '0000' == h.shownCode ? '1111' : '0000'),
      throwsA(isA<CastException>().having((e) => e.code, 'code', 'wrong-code')),
    );
    final token = await CastClient.confirm(tv, h.shownCode!);
    expect(h.shownCode, isNull);

    expect(await CastClient.status(tv, token), isNull);
    await expectLater(
      CastClient.play(tv, token, {'source': 'other', 'kind': 'live'}),
      throwsA(
        isA<CastException>().having((e) => e.code, 'code', 'unknown-source'),
      ),
    );
    await CastClient.play(tv, token, {
      'source': 'abc',
      'kind': 'live',
      'channel': '1',
    });
    expect((await CastClient.status(tv, token))?.title, 'Rai 1');
    await CastClient.key(tv, token, 'down');
    expect(h.keys, ['down']);
    await CastClient.stop(tv, token);
    expect(h.stopped, isTrue);
  });
}
