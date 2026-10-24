import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

void main() {
  late ZaplineDatabase db;
  setUp(() => db = ZaplineDatabase.inMemory());
  tearDown(() => db.close());

  Movie movie(String id, String name, String? cat, {int? added}) => Movie(
    sourceId: 's',
    id: id,
    name: name,
    category: cat,
    rating: 7,
    addedAt: added == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(added * 1000, isUtc: true),
  );

  test('films by category, newest first, filtered and searched', () {
    db.replaceMovies('s', [
      movie('1', 'Alpha', 'IT | Azione', added: 100),
      movie('2', 'Beta', 'IT | Commedia', added: 300),
      movie('3', 'Gamma', 'EN | Action', added: 200),
      movie('4', 'Delta', null),
    ]);
    expect(db.movieCount(), 4);
    expect(db.movieCategories().map((c) => c.title), [
      'IT | Azione',
      'IT | Commedia',
      'EN | Action',
      '',
    ]);
    expect(db.movies(category: 'IT | Azione').single.name, 'Alpha');
    expect(db.movies(newest: true, limit: 2).map((m) => m.name), [
      'Beta',
      'Gamma',
    ]);
    expect(
      db
          .movies(hiddenCategories: {('s', 'EN | Action'), ('s', '')})
          .map((m) => m.name),
      ['Alpha', 'Beta'],
    );
    // Hiding is per source: another source's category of that name stays.
    expect(
      db.movies(hiddenCategories: {('other', 'EN | Action')}).length,
      db.movieCount(),
    );
    expect(db.movieCategories(sourceId: 'nope'), isEmpty);
    expect(db.searchMovies('amm').single.name, 'Gamma');
    expect(db.movie('s', '2')!.rating, 7);
  });

  test('playlist series keep their episodes', () {
    db.replaceShows(
      's',
      [const Show(sourceId: 's', id: 'la casa', name: 'La casa')],
      playlistEpisodes: [
        (
          'la casa',
          Episode(
            id: '1x2',
            season: 1,
            number: 2,
            title: 'La casa S01E02',
            streamUrl: Uri.parse('http://p/series/2.mp4'),
          ),
        ),
        (
          'la casa',
          Episode(
            id: '1x1',
            season: 1,
            number: 1,
            title: 'La casa S01E01',
            streamUrl: Uri.parse('http://p/series/1.mp4'),
          ),
        ),
      ],
    );
    expect(db.showCount(), 1);
    expect(db.playlistEpisodes('s', 'la casa').map((e) => e.number), [1, 2]);
  });

  test('positions, continue watching and my list; cleaned with the source', () {
    db.saveSource(
      const SourceRecord(id: 's', kind: SourceKind.m3u, name: 'S', url: 'u'),
    );
    db.replaceMovies('s', [movie('1', 'Alpha', null)]);
    db.savePosition(
      'movie:s/1',
      const Duration(minutes: 30),
      const Duration(minutes: 100),
    );
    final p = db.position('movie:s/1')!;
    expect(p.progress, closeTo(0.3, 0.001));
    expect(p.resumable, isTrue);
    expect(db.positions(prefix: 'movie:').single.key, 'movie:s/1');

    db.setInMyList('movie:s/1', true);
    expect(db.inMyList('movie:s/1'), isTrue);
    expect(db.myList(), ['movie:s/1']);

    db.saveVodDetails('movie:s/1', '{"info": {}}');
    expect(db.vodDetails('movie:s/1')!.json, '{"info": {}}');

    db.deleteSource('s');
    expect(db.movieCount(), 0);
    expect(db.position('movie:s/1'), isNull);
    expect(db.myList(), isEmpty);
    expect(db.vodDetails('movie:s/1'), isNull);
  });
}
