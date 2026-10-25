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
}

void main() {
  test('a phone finds the TV and drives it', () async {
    final h = _Handler();
    final r = (await CastReceiver.start(h, name: 'Soggiorno'))!;
    addTearDown(r.close);

    // Discovery: the TV answers a hello with its name and port.
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
    expect(m['port'], r.port);

    final tv = CastDevice(
      name: 'Soggiorno',
      address: InternetAddress.loopbackIPv4,
      port: r.port,
    );
    expect(await CastClient.status(tv), isNull);
    expect(
      await CastClient.play(tv, {'source': 'other', 'kind': 'live'}),
      'unknown-source',
    );
    expect(
      await CastClient.play(tv, {
        'source': 'abc',
        'kind': 'live',
        'channel': '1',
      }),
      isNull,
    );
    expect((await CastClient.status(tv))?.title, 'Rai 1');
    await CastClient.key(tv, 'down');
    expect(h.keys, ['down']);
    await CastClient.stop(tv);
    expect(h.stopped, isTrue);
  });
}
