import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

Channel _ch(
  String src,
  String id,
  String name, {
  String? group,
  String? epg,
  Map<String, String> headers = const {'User-Agent': 'x'},
}) => Channel(
  sourceId: src,
  id: id,
  name: name,
  groupTitle: group,
  epgChannelId: epg,
  streamUrl: Uri.parse('http://s.example/$src/$id.ts'),
  httpHeaders: headers,
);

SourceRecord _src(String id) =>
    SourceRecord(id: id, kind: SourceKind.m3u, name: id, url: 'http://$id');

XmltvProgramme _p(String guide, DateTime start, int minutes, String title) =>
    XmltvProgramme(
      Programme(
        channelId: guide,
        start: start,
        stop: start.add(Duration(minutes: minutes)),
        title: title,
        description: 'about $title',
      ),
    );

void main() {
  final now = DateTime.utc(2026, 11, 25, 20);
  late ZaplineDatabase db;

  setUp(() {
    db = ZaplineDatabase.inMemory();
    db.saveSource(_src('a'));
    db.saveSource(_src('b'));
  });
  tearDown(() => db.close());

  group('replaceChannels writes only what changed', () {
    test('renames, moves, removals and duplicates', () {
      db.replaceChannels('a', [
        _ch('a', '1', 'Alpha', group: 'G'),
        _ch('a', '2', 'Bravo', group: 'G'),
        _ch('a', '3', 'Charlie', group: 'H'),
      ]);
      final fav = db.channels().first;
      db.setFavourite(fav, true);

      db.replaceChannels('a', [
        _ch('a', '3', 'Charlie', group: 'H'), // moved to the top
        _ch('a', '1', 'Alpha Renamed', group: 'G'), // renamed
        _ch('a', '4', 'Delta'), // new
        _ch('a', '4', 'Delta twin'), // duplicate id: the first counts
        // 2 is gone
      ]);
      expect(db.channels().map((c) => '${c.id} ${c.name}'), [
        '3 Charlie',
        '1 Alpha Renamed',
        '4 Delta',
      ]);
      expect(db.search('alpha').single.name, 'Alpha Renamed');
      expect(db.search('bravo'), isEmpty, reason: 'search follows removals');
      expect(db.search('twin'), isEmpty);
      expect(db.search('delta').single.id, '4');
      expect(db.favourites().single.id, '1', reason: 'kept by key');
      expect(db.groups(), ['H', 'G']);
    });

    test('every field round-trips and a change in any of them is seen', () {
      Channel full({String? logo, Map<String, String>? headers}) => Channel(
        sourceId: 'a',
        id: '1',
        name: 'Full',
        number: 7,
        groupTitle: 'G',
        logoUrl: Uri.parse(logo ?? 'http://l.example/1.png'),
        streamUrl: Uri.parse('http://s.example/1.ts'),
        epgChannelId: 'full.example',
        catchup: const CatchupInfo(
          mode: CatchupMode.shift,
          days: 2,
          source: '?utc={utc}',
        ),
        httpHeaders: headers ?? const {'User-Agent': 'x', 'Referer': 'r'},
      );
      db.replaceChannels('a', [full()]);
      var c = db.channels().single;
      expect(c.number, 7);
      expect(c.logoUrl.toString(), 'http://l.example/1.png');
      expect(c.epgChannelId, 'full.example');
      expect(c.catchup?.mode, CatchupMode.shift);
      expect(c.catchup?.source, '?utc={utc}');
      expect(c.httpHeaders, {'User-Agent': 'x', 'Referer': 'r'});

      db.replaceChannels('a', [full(logo: 'http://l.example/2.png')]);
      expect(db.channels().single.logoUrl.toString(), 'http://l.example/2.png');
      db.replaceChannels('a', [
        full(headers: const {'User-Agent': 'y'}),
      ]);
      c = db.channels().single;
      expect(c.httpHeaders, {'User-Agent': 'y'});
      expect(
        () => c.httpHeaders['x'] = 'z',
        throwsUnsupportedError,
        reason: 'shared between rows, so not to be changed',
      );
    });

    test('another source is left alone', () {
      db.replaceChannels('a', [_ch('a', '1', 'A one')]);
      db.replaceChannels('b', [_ch('b', '1', 'B one')]);
      db.replaceChannels('a', const []);
      expect(db.channels().single.sourceId, 'b');
      expect(db.search('one').single.sourceId, 'b');
    });
  });

  group('groups', () {
    // Order by first channel in the source, as SQL min(sort) did.
    List<String> reference(ChannelVisibility v) => [
      ...{
        for (final c in db.channels(sourceId: 'a', visibility: v))
          ?c.groupTitle,
      },
    ];

    setUp(() {
      db.replaceChannels('a', [
        _ch('a', '1', 'News', group: 'G1'),
        _ch('a', '2', 'Sport', group: 'G2'),
        _ch('a', '3', 'Film', group: 'G3'),
        _ch('a', '4', 'News 2', group: 'G1'),
        _ch('a', '5', 'Kids', group: 'G4'),
        _ch('a', '6', 'Kids 2', group: 'G4'),
        _ch('a', '7', 'Music', group: 'G5'),
        _ch('a', '8', 'No group'),
      ]);
    });

    test('channels hidden one by one, hidden and locked groups', () {
      final all = db.channels(sourceId: 'a');
      expect(db.groups(), ['G1', 'G2', 'G3', 'G4', 'G5']);
      // The group's first channel hidden: placed by its next one.
      db.setChannelHidden(all[0], true);
      // Every channel of a group hidden: the group goes.
      db.setChannelHidden(all[4], true);
      db.setChannelHidden(all[5], true);
      db.setGroupHidden('a', 'G2', true);
      db.setGroupLocked('a', 'G3', true);
      db.applyGroupVisibility('a', GroupFilter.none);

      expect(db.groups(), ['G3', 'G1', 'G5']);
      for (final v in [
        ChannelVisibility.visible,
        ChannelVisibility.unlocked,
        ChannelVisibility.all,
        const ChannelVisibility(hidden: true),
      ]) {
        expect(db.groups(visibility: v), reference(v), reason: '$v');
        expect(db.groups(sourceId: 'a', visibility: v), reference(v));
      }
      expect(db.groups(sourceId: 'b'), isEmpty);
    });

    test('across sources by first position', () {
      db.replaceChannels('b', [
        _ch('b', '1', 'x', group: 'Bx'),
        _ch('b', '2', 'y', group: 'By'),
        _ch('b', '3', 'z', group: 'Bz'),
      ]);
      // a: G1 0, G2 1, G3 2, G4 4, G5 6 / b: Bx 0, By 1, Bz 2.
      final g = db.groups();
      expect(g.toSet(), {'G1', 'G2', 'G3', 'G4', 'G5', 'Bx', 'By', 'Bz'});
      expect(g.indexOf('G4'), greaterThan(g.indexOf('Bz')));
      expect(db.groups(sourceId: 'b'), ['Bx', 'By', 'Bz']);
    });
  });

  test('channelByKey', () {
    db.replaceChannels('a', [
      _ch('a', '1', 'One', group: 'Locked'),
      _ch('a', '2', 'Two'),
    ]);
    expect(db.channelByKey('a/2')?.name, 'Two');
    expect(db.channelByKey('a/9'), isNull);
    expect(db.channelByKey('b/2'), isNull);
    db.setGroupLocked('a', 'Locked', true);
    expect(db.channelByKey('a/1')?.name, 'One');
    expect(
      db.channelByKey('a/1', visibility: ChannelVisibility.visible),
      isNull,
    );
  });

  group('guide', () {
    setUp(() async {
      db.replaceChannels('a', [
        _ch('a', '1', 'News', epg: 'news'),
        _ch('a', '2', 'Sport', epg: 'sport', group: 'Hidden'),
        _ch('a', '3', 'Film', epg: 'film'),
      ]);
      Stream<XmltvItem> guide() async* {
        for (final id in ['news', 'sport', 'film']) {
          yield XmltvChannel(id: id, displayNames: [id]);
        }
        // 600 half hours of news: more matches than one page of search.
        for (var i = -10; i < 590; i++) {
          yield _p('news', now.add(Duration(minutes: 30 * i)), 30, 'Match $i');
        }
        yield _p('sport', now.subtract(const Duration(hours: 1)), 180, 'Match');
        // Started three hours ago and still on.
        yield _p('film', now.subtract(const Duration(hours: 3)), 240, 'Long');
        yield _p('film', now.add(const Duration(hours: 1)), 60, '50% off!');
      }

      await db.importGuide(guide(), now: now, batchSize: 50);
      db.rebuildGuideLinks();
      db.setGroupHidden('a', 'Hidden', true);
      db.applyGroupVisibility('a', GroupFilter.none);
    });

    test('nowNext', () {
      final news = db.channels().first;
      var (cur, next) = db.nowNext(news, now.add(const Duration(minutes: 5)));
      expect((cur?.title, next?.title), ('Match 0', 'Match 1'));
      expect(cur?.description, 'about Match 0');
      final film = db.channels().last;
      (cur, next) = db.nowNext(film, now);
      expect((cur?.title, next?.title), ('Long', '50% off!'));
      (cur, next) = db.nowNext(film, now.add(const Duration(hours: 3)));
      expect((cur, next), (null, null));
      (cur, next) = db.nowNext(film, now.subtract(const Duration(hours: 4)));
      expect((cur?.title, next?.title), (null, 'Long'));
    });

    test('searchProgrammes pages through many matches', () {
      final all = db.searchProgrammes('match', from: now, limit: 1000);
      // Match -1 ended at now; Match 0 is on; the hidden group's sport is
      // left out.
      expect(all.length, 590);
      expect(all.first.$2.title, 'Match 0');
      expect(all.last.$2.title, 'Match 589');
      final starts = [for (final (_, p) in all) p.start];
      expect(starts, orderedEquals([...starts]..sort()));
      expect(all.every((r) => r.$1.id == '1'), isTrue);
      expect(db.searchProgrammes('match', from: now).map((r) => r.$2.title), [
        for (var i = 0; i < 60; i++) 'Match $i',
      ]);
      expect(
        db
            .searchProgrammes(
              'match',
              from: now,
              visibility: ChannelVisibility.all,
              limit: 2,
            )
            .map((r) => r.$2.title),
        ['Match', 'Match 0'],
        reason: 'the hidden sport, on since an hour ago, comes first',
      );
    });

    test('searchProgrammes keeps programmes on now and LIKE characters', () {
      expect(db.searchProgrammes('LONG', from: now).single.$2.title, 'Long');
      expect(db.searchProgrammes('50%', from: now).single.$2.title, '50% off!');
      expect(db.searchProgrammes('0_', from: now), isEmpty);
      expect(db.searchProgrammes('off!', from: now).single.$1.id, '3');
      expect(db.searchProgrammes('m', from: now), isEmpty);
    });

    test('pruneProgrammes drops what ended before', () {
      // News -10 to -2; -1 ends right at now and stays.
      expect(db.pruneProgrammes(now), 9);
      expect(db.pruneProgrammes(now), 0);
      expect(
        db
            .nowNext(
              db.channels().first,
              now.subtract(const Duration(minutes: 1)),
            )
            .$1
            ?.title,
        'Match -1',
      );
    });

    test('a channel guide finds its twin through the start index', () {
      final film = db.channels().last;
      db.storeChannelGuide(film, [
        Programme(
          channelId: 'x',
          start: now.subtract(const Duration(hours: 3)),
          stop: now.add(const Duration(hours: 1)),
          title: ' LONG ',
        ),
        Programme(
          channelId: 'x',
          start: now.add(const Duration(hours: 1)),
          stop: now.add(const Duration(hours: 2)),
          title: '50% Off!',
        ),
      ]);
      expect(db.guideOverrides()['a/3'], 'film');
    });
  });

  test('importGuide batches give the same guide as one batch', () async {
    Stream<XmltvItem> guide(int shift) async* {
      for (var c = 0; c < 30; c++) {
        yield XmltvChannel(id: 'G$c', displayNames: ['g $c']);
        for (var i = 0; i < 40; i++) {
          yield _p(
            'G$c',
            now.add(Duration(minutes: 30 * i + shift)),
            30,
            '$c/$i/$shift',
          );
        }
      }
    }

    Future<List<String>> run(int batch) async {
      final d = ZaplineDatabase.inMemory();
      addTearDown(d.close);
      d.saveSource(_src('a'));
      d.replaceChannels('a', [
        for (var c = 0; c < 30; c++) _ch('a', '$c', 'g $c', epg: 'g$c'),
      ]);
      await d.importGuide(guide(0), now: now, batchSize: batch);
      // Published again 15 minutes later: replaces what's to come.
      final r = await d.importGuide(guide(15), now: now, batchSize: batch);
      expect(r.programmes, 1200);
      expect(r.starts.length, 30);
      d.rebuildGuideLinks();
      return [
        for (final MapEntry(:key, :value)
            in d
                .guide(
                  d.channels(),
                  now.subtract(const Duration(days: 1)),
                  now.add(const Duration(days: 2)),
                )
                .entries)
          for (final p in value) '$key ${p.start} ${p.title}',
      ];
    }

    final one = await run(1 << 20);
    expect(one, isNotEmpty);
    for (final b in [1, 7, 41, 1000]) {
      expect(await run(b), one, reason: 'batch $b');
    }
  });

  test('replaceMovies and replaceShows write only what changed', () {
    Movie m(String id, String name, {double? rating}) => Movie(
      sourceId: 'a',
      id: id,
      name: name,
      category: 'C',
      rating: rating,
      addedAt: DateTime.utc(2026, 1, int.parse(id)),
    );
    db.replaceMovies('a', [m('1', 'One'), m('2', 'Two'), m('3', 'Three')]);
    db.replaceMovies('b', [Movie(sourceId: 'b', id: '1', name: 'Other')]);
    db.replaceMovies('a', [
      m('3', 'Three'),
      m('1', 'One', rating: 7.5),
      m('4', 'Four'),
      m('4', 'Four twin'),
    ]);
    expect(
      db.movies(category: 'C').map((x) => '${x.id} ${x.name} ${x.rating}'),
      ['3 Three null', '1 One 7.5', '4 Four null'],
    );
    expect(db.movieCount(), 4);
    expect(db.searchMovies('two'), isEmpty);

    Show s(String id, String name) =>
        Show(sourceId: 'a', id: id, name: name, plot: 'p$id');
    db.replaceShows('a', [s('1', 'S1'), s('2', 'S2')]);
    db.replaceShows('a', [s('2', 'S2 new'), s('3', 'S3')]);
    expect(db.shows().map((x) => '${x.id} ${x.name} ${x.plot}'), [
      '2 S2 new p2',
      '3 S3 p3',
    ]);
  });

  test('a version 8 database: guides emptied, sources due, new indexes', () {
    final dir = Directory.systemTemp.createTempSync('zapline_v8');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/z.db';
    ZaplineDatabase.open(path)
      ..saveSource(
        SourceRecord(
          id: 'k',
          kind: SourceKind.m3u,
          name: 'K',
          url: 'http://k',
          syncedAt: now,
        ),
      )
      ..close();
    // Back to version 8, with a guide.
    final raw = sqlite3.open(path)
      ..execute('DROP INDEX programmes_at')
      ..execute('DROP INDEX channels_by_title')
      ..execute('DROP TABLE guide_feeds')
      ..execute('CREATE INDEX programmes_start ON programmes(start)')
      ..execute(
        'CREATE INDEX programmes_title ON programmes(lower(trim(title)), start)',
      )
      ..execute(
        "INSERT INTO programmes(guide_id, start, stop, title) "
        "VALUES ('g', 1, 2, 't')",
      )
      ..userVersion = 8;
    raw.close();

    ZaplineDatabase.open(path).close();
    final check = sqlite3.open(path);
    addTearDown(check.close);
    expect(check.userVersion, 9);
    expect(check.select('SELECT count(*) AS n FROM programmes').first['n'], 0);
    expect(
      check.select('SELECT synced_at FROM sources').single['synced_at'],
      isNull,
    );
    final indexes = {
      for (final r in check.select(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND tbl_name IN ('programmes', 'channels') AND sql IS NOT NULL",
      ))
        r['name'] as String,
    };
    expect(indexes, containsAll(['programmes_at', 'channels_by_title']));
    expect(indexes, isNot(contains('programmes_title')));
    expect(indexes, isNot(contains('programmes_start')));
  });

  test('hot queries use their indexes', () {
    final dir = Directory.systemTemp.createTempSync('zapline_plans');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/p.db';
    ZaplineDatabase.open(path).close();
    final raw = sqlite3.open(path);
    addTearDown(raw.close);
    String plan(String sql) => [
      for (final r in raw.select('EXPLAIN QUERY PLAN $sql')) r['detail'],
    ].join('\n');

    for (final table in ['recents', 'favourites', 'hidden_channels']) {
      expect(
        plan(
          'SELECT c.name FROM $table r JOIN channels c '
          "ON +r.channel_key = c.source_id || '/' || c.id",
        ),
        contains('USING INDEX channels_key'),
        reason: table,
      );
    }
    expect(
      plan(
        'SELECT guide_id, start FROM programmes INDEXED BY programmes_at '
        "WHERE (start, guide_id) > (0, '') AND stop > 0 AND title LIKE '%x%' "
        'ORDER BY start, guide_id LIMIT 400',
      ),
      allOf(contains('COVERING INDEX programmes_at'), isNot(contains('TEMP'))),
    );
    expect(
      plan(
        'SELECT DISTINCT guide_id FROM programmes WHERE start BETWEEN 0 AND 1 '
        "AND lower(trim(title)) = 'x'",
      ),
      contains('COVERING INDEX programmes_at'),
    );
    expect(
      plan('DELETE FROM programmes WHERE start < 5 AND stop < 5'),
      contains('INDEX programmes_at'),
    );
    expect(
      plan("SELECT name FROM channels WHERE group_title = 'g'"),
      contains('INDEX channels_by_title'),
    );
  });

  test('rebuildGuideLinks rewrites only what changed', () async {
    db.replaceChannels('a', [
      _ch('a', '1', 'News', epg: 'news'),
      _ch('a', '2', 'Own guide'),
      _ch('a', '3', 'Gone soon', epg: 'news'),
    ]);
    await db.importGuide(
      Stream.fromIterable([
        const XmltvChannel(id: 'news', displayNames: ['News']),
        const XmltvChannel(id: 'film', displayNames: ['Film']),
        _p('news', now, 60, 'N'),
      ]),
      now: now,
    );
    expect(db.rebuildGuideLinks().matched, 2);
    // The source's own guide for channel 2.
    db.storeChannelGuide(db.channels()[1], [
      Programme(
        channelId: 'x',
        start: now,
        stop: now.add(const Duration(hours: 1)),
        title: 'Own',
      ),
    ]);
    db.replaceChannels('a', [
      _ch('a', '1', 'News', epg: 'news'),
      _ch('a', '2', 'Own guide'),
    ]);
    db.setGuideOverride(db.channels().first, 'film');
    final cov = db.rebuildGuideLinks();
    expect((cov.channels, cov.matched), (2, 2));
    expect(db.unmatchedChannels(), isEmpty);
    final g = db.guide(db.channels(), now, now.add(const Duration(hours: 1)));
    expect(g['a/1'], isNull, reason: 'film has no programmes');
    expect(g['a/2']!.single.title, 'Own');
    expect(db.guideCoverage().matched, 2, reason: 'a/3 link removed');
  });

  test('maintain works on a busy database', () async {
    db.replaceChannels('a', [_ch('a', '1', 'One')]);
    db.maintain();
    expect(db.channels().single.name, 'One');
  });
}
