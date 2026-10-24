import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';
import 'package:test/test.dart';

Channel _ch(String src, String id) => Channel(
  sourceId: src,
  id: id,
  name: 'C$id',
  streamUrl: Uri.parse('http://s.example/$id.ts'),
);

void main() {
  test('export → parse keeps sources, favourites and overrides', () {
    final db = ZaplineDatabase.inMemory();
    addTearDown(db.close);
    db
      ..saveSource(
        const SourceRecord(
          id: 'a',
          kind: SourceKind.m3u,
          name: 'A',
          url: 'http://a.example/l.m3u',
          extraGuideUrls: ['http://g.example/e.xml'],
        ),
      )
      ..saveSource(
        const SourceRecord(
          id: 'b',
          kind: SourceKind.xtream,
          name: 'B',
          url: 'http://b.example',
          username: 'u',
        ),
      )
      ..replaceChannels('a', [_ch('a', '1'), _ch('a', '2')])
      ..replaceChannels('b', [_ch('b', '9/x')]);
    db.setFavourite(_ch('b', '9/x'), true);
    db.setFavourite(_ch('a', '2'), true);
    db.setGuideOverride(_ch('a', '1'), 'news.example');

    final json = Backup.export(
      db,
      passwordOf: (s) => s.id == 'b' ? 'secret' : '',
    );
    final c = Backup.parse(json);

    expect(c.sources.map((s) => s.url), [
      'http://a.example/l.m3u',
      'http://b.example',
    ]);
    expect(c.sources[0].extraGuideUrls, ['http://g.example/e.xml']);
    expect(c.sources[1].password, 'secret');
    expect(c.favourites, [(1, '9/x'), (0, '2')]);
    expect(c.guideOverrides, [(0, '1', 'news.example')]);
  });

  test('rejects foreign or newer files with readable messages', () {
    expect(() => Backup.parse('nope'), throwsA(isA<BackupFormatException>()));
    expect(
      () => Backup.parse('{"format":"other"}'),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () =>
          Backup.parse('{"format":"zapline-backup","version":99,"sources":[]}'),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('newer'),
        ),
      ),
    );
  });

  test('markSynced never touches stored credentials', () {
    final db = ZaplineDatabase.inMemory();
    addTearDown(db.close);
    db.saveSource(
      const SourceRecord(
        id: 'x',
        kind: SourceKind.xtream,
        name: 'X',
        url: 'http://x',
        username: 'u',
      ),
    );
    db.markSynced(
      'x',
      DateTime.utc(2026),
      serverOffset: const Duration(hours: 2),
    );
    final s = db.sources().single;
    expect(s.password, '');
    expect(s.serverOffset, const Duration(hours: 2));
    expect(s.syncedAt, DateTime.utc(2026));
  });
}
