import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

void main() {
  late ZaplineDatabase db;
  setUp(() => db = ZaplineDatabase.inMemory());
  tearDown(() => db.close());

  final now = DateTime.utc(2026, 10, 25, 18);
  Stream<XmltvItem> guide(int hourShift) async* {
    yield const XmltvChannel(id: 'Rai1.it', displayNames: ['Rai 1']);
    for (final (h, title) in [(-2, 'Earlier'), (0, 'Tg1'), (1, 'Film')]) {
      final start = now.add(Duration(hours: h + hourShift));
      yield XmltvProgramme(
        Programme(
          channelId: 'Rai1.it',
          start: start,
          stop: start.add(const Duration(hours: 1)),
          title: title,
        ),
      );
    }
  }

  final rai1 = Channel(
    sourceId: 's',
    id: '1',
    name: 'Rai 1',
    streamUrl: Uri.parse('http://x/1.ts'),
    epgChannelId: 'Rai1.it',
  );

  setUp(() {
    db.saveSource(
      const SourceRecord(
        id: 's',
        kind: SourceKind.m3u,
        name: 'S',
        url: 'http://s.example',
      ),
    );
    db.replaceChannels('s', [rai1]);
  });

  List<String> titles() {
    db.rebuildGuideLinks();
    return [
      for (final p
          in db.guide(
                [rai1],
                now.subtract(const Duration(days: 1)),
                now.add(const Duration(days: 1)),
              )[ZaplineDatabase.channelKey(rai1)] ??
              const <Programme>[])
        '${p.start.hour} ${p.title}',
    ];
  }

  test('a republished guide replaces its coming programmes', () async {
    await db.importGuide(guide(0), now: now);
    // The same guide an hour later (a daylight saving change, a fix).
    await db.importGuide(guide(1), now: now);
    expect(titles(), [
      '16 Earlier', // past: kept for replay
      '17 Earlier', // past part of the new import
      '19 Tg1',
      '20 Film',
    ]);
  });

  test('guides of one sync replace a channel only once', () async {
    final replaced = <String>{};
    await db.importGuide(guide(0), now: now, replaced: replaced);
    await db.importGuide(guide(0), now: now, replaced: replaced);
    expect(titles(), ['16 Earlier', '18 Tg1', '19 Film']);
  });
}
