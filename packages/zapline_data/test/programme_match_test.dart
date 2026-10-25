import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

void main() {
  late ZaplineDatabase db;
  setUp(() => db = ZaplineDatabase.inMemory());
  tearDown(() => db.close());

  final t0 = DateTime.utc(2026, 10, 25, 20);
  Programme p(String guide, int h, String title) => Programme(
    channelId: guide,
    start: t0.add(Duration(hours: h)),
    stop: t0.add(Duration(hours: h + 1)),
    title: title,
  );
  final ch = Channel(
    sourceId: 's',
    id: '7',
    name: 'C5 Extra',
    streamUrl: Uri.parse('http://x/7.ts'),
  );

  Future<void> guide() async {
    Stream<XmltvItem> items() async* {
      yield const XmltvChannel(id: 'Canale5.it', displayNames: ['Canale 5']);
      yield const XmltvChannel(id: 'Rete4.it', displayNames: ['Rete 4']);
      yield XmltvProgramme(p('Canale5.it', 0, 'Striscia la notizia'));
      yield XmltvProgramme(p('Canale5.it', 1, 'Grande Fratello'));
      yield XmltvProgramme(p('Rete4.it', 0, 'Quarta Repubblica'));
      yield XmltvProgramme(p('Rete4.it', 1, 'Striscia la notizia'));
    }

    await db.importGuide(items());
  }

  test('a channel airing what a guide airs gets that guide', () async {
    await guide();
    db.saveSource(
      const SourceRecord(
        id: 's',
        kind: SourceKind.m3u,
        name: 'S',
        url: 'http://s.example',
      ),
    );
    db.replaceChannels('s', [ch]);
    db.storeChannelGuide(ch, [
      p('x', 0, 'STRISCIA LA NOTIZIA'),
      p('x', 1, 'Grande Fratello'),
    ]);
    expect(
      db.nowNext(ch, t0.add(const Duration(minutes: 30))).$1?.channelId,
      'canale5.it',
    );
    // It is kept as the channel's guide across refreshes.
    db.rebuildGuideLinks();
    expect(
      db.nowNext(ch, t0.add(const Duration(minutes: 90))).$1?.title,
      'Grande Fratello',
    );
  });

  test('one title in common is not enough', () async {
    await guide();
    db.storeChannelGuide(ch, [
      p('x', 0, 'Striscia la notizia'),
      p('x', 1, 'Altro'),
    ]);
    expect(
      db.nowNext(ch, t0.add(const Duration(minutes: 30))).$1?.channelId,
      startsWith('xc/'),
    );
  });
}
