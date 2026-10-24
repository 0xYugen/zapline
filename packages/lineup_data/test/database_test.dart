import 'dart:io';

import 'package:lineup_core/lineup_core.dart';
import 'package:lineup_data/lineup_data.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

Channel _ch(String src, String id, String name, {String? group, String? epg}) =>
    Channel(
      sourceId: src,
      id: id,
      name: name,
      groupTitle: group,
      epgChannelId: epg,
      streamUrl: Uri.parse('http://s.example/$id.ts'),
      httpHeaders: const {'User-Agent': 'x'},
      catchup: const CatchupInfo(mode: CatchupMode.xtream, days: 3),
    );

Stream<XmltvItem> _guide(DateTime base) async* {
  yield const XmltvChannel(id: 'news.example', displayNames: ['News 24']);
  yield const XmltvChannel(id: 'sport.example', displayNames: ['Sport One']);
  for (var i = -4; i < 8; i++) {
    final start = base.add(Duration(minutes: 30 * i));
    for (final id in ['news.example', 'sport.example']) {
      yield XmltvProgramme(
        Programme(
          channelId: id,
          start: start,
          stop: start.add(const Duration(minutes: 30)),
          title: '$id $i',
        ),
      );
    }
  }
}

void main() {
  late LineupDatabase db;
  final now = DateTime.utc(2026, 10, 24, 20);

  setUp(() {
    db = LineupDatabase.inMemory();
    db.saveSource(
      const SourceRecord(
        id: 'a',
        kind: SourceKind.m3u,
        name: 'A',
        url: 'http://a.example',
      ),
    );
    db.saveSource(
      const SourceRecord(
        id: 'b',
        kind: SourceKind.xtream,
        name: 'B',
        url: 'http://b.example',
        username: 'u',
        password: 'p',
      ),
    );
  });
  tearDown(() => db.close());

  test('sources round-trip', () {
    final s = db.sources();
    expect(s.map((e) => e.id), ['a', 'b']);
    expect(s[1].kind, SourceKind.xtream);
    expect(s[1].password, 'p');
  });

  test('channels: replace, order, groups, round-trip of fields', () {
    db.replaceChannels('a', [
      _ch('a', '1', 'News 24 HD', group: 'News', epg: 'news.example'),
      _ch('a', '2', 'Sport One', group: 'Sport'),
      _ch('a', '3', 'Città TV', group: 'News'),
    ]);
    db.replaceChannels('b', [_ch('b', '9', 'Other')]);
    expect(db.channelCount(), 4);
    expect(db.groups(sourceId: 'a'), ['News', 'Sport']);
    expect(db.channels(group: 'News').map((c) => c.id), ['1', '3']);

    final c = db.channels(sourceId: 'a').first;
    expect(c.httpHeaders, {'User-Agent': 'x'});
    expect(c.catchup?.mode, CatchupMode.xtream);
    expect(c.catchup?.days, 3);

    db.replaceChannels('a', [_ch('a', '5', 'Only')]);
    expect(db.channels(sourceId: 'a').map((c) => c.id), ['5']);
    expect(db.search('news'), isEmpty, reason: 'FTS follows deletes');
  });

  test('search is prefix and accent insensitive', () {
    db.replaceChannels('a', [
      _ch('a', '1', 'News 24 HD'),
      _ch('a', '2', 'Città TV'),
      _ch('a', '3', 'Sport One'),
    ]);
    expect(db.search('citta').single.id, '2');
    expect(db.search('spo on').single.id, '3');
    expect(db.search('"weird'), isEmpty);
  });

  test('guide import, linking, range query and now/next', () async {
    db.replaceChannels('a', [
      _ch('a', '1', 'IT: News 24 FHD'), // matched by name
      _ch('a', '2', 'Anything', epg: 'sport.example'), // matched by id
      _ch('a', '3', 'No guide'),
    ]);
    final r = await db.importGuide(_guide(now), batchSize: 7);
    expect(r.channels, 2);
    expect(r.programmes, 24);

    final cov = db.rebuildGuideLinks();
    expect(cov.channels, 3);
    expect(cov.matched, 2);

    final chans = db.channels(sourceId: 'a');
    final g = db.guide(chans, now, now.add(const Duration(hours: 1)));
    expect(g.keys, containsAll(['a/1', 'a/2']));
    expect(g['a/1']!.map((p) => p.title), ['news.example 0', 'news.example 1']);

    final (cur, next) = db.nowNext(
      chans[1],
      now.add(const Duration(minutes: 10)),
    );
    expect(cur?.title, 'sport.example 0');
    expect(next?.title, 'sport.example 1');

    // Ended strictly before now: slots -4..-2 on two channels.
    expect(db.pruneProgrammes(now), 6);
    db.setGuideOverride(chans[2], 'news.example');
    expect(db.rebuildGuideLinks().matched, 3);
  });

  test('favourites keep order, survive re-sync, go with their source', () {
    final chans = [
      _ch('a', '1', 'One'),
      _ch('a', '2', 'Two'),
      _ch('a', '3', 'Three'),
    ];
    db.replaceChannels('a', chans);
    db.setFavourite(chans[2], true);
    db.setFavourite(chans[0], true);
    db.setFavourite(chans[0], true); // idempotent
    expect(db.favourites().map((c) => c.id), ['3', '1']);

    db.replaceChannels('a', chans.reversed);
    expect(db.favourites().map((c) => c.id), ['3', '1']);

    db.setFavourite(chans[2], false);
    expect(db.favouriteKeys(), {'a/1'});
    db.deleteSource('a');
    expect(db.favouriteKeys(), isEmpty);
  });

  test('a version 1 database is migrated in place', () {
    final dir = Directory.systemTemp.createTempSync('lineup_db');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/v1.db';
    LineupDatabase.open(path)
      ..saveSource(
        const SourceRecord(
          id: 'k',
          kind: SourceKind.m3u,
          name: 'K',
          url: 'http://k',
        ),
      )
      ..close();
    // Roll the file back to version 1.
    final raw = sqlite3.open(path)
      ..execute('DROP TABLE favourites')
      ..userVersion = 1;
    raw.close();

    final migrated = LineupDatabase.open(path);
    addTearDown(migrated.close);
    expect(migrated.sources().single.id, 'k');
    migrated.replaceChannels('k', [_ch('k', '1', 'One')]);
    migrated.setFavourite(_ch('k', '1', 'One'), true);
    expect(migrated.favourites().single.id, '1');
  });

  test('deleting a source removes its channels and links', () async {
    db.replaceChannels('a', [_ch('a', '1', 'News 24')]);
    await db.importGuide(_guide(now));
    db.rebuildGuideLinks();
    db.deleteSource('a');
    expect(db.channelCount(), 0);
    expect(db.guideCoverage().channels, 0);
    expect(db.search('news'), isEmpty);
  });

  test('imports a large guide quickly', () async {
    const channels = 500, days = 2;
    db.replaceChannels('a', [
      for (var i = 0; i < channels; i++) _ch('a', '$i', 'Ch $i', epg: 'g$i'),
    ]);
    Stream<XmltvItem> big() async* {
      for (var i = 0; i < channels; i++) {
        yield XmltvChannel(id: 'g$i', displayNames: ['Ch $i']);
      }
      for (var i = 0; i < channels; i++) {
        for (var s = 0; s < days * 48; s++) {
          final start = now.add(Duration(minutes: 30 * s));
          yield XmltvProgramme(
            Programme(
              channelId: 'g$i',
              start: start,
              stop: start.add(const Duration(minutes: 30)),
              title: 'P $s',
              description: 'Some description text for programme $s',
            ),
          );
        }
      }
    }

    final sw = Stopwatch()..start();
    final r = await db.importGuide(big());
    final importMs = sw.elapsedMilliseconds;
    sw.reset();
    db.rebuildGuideLinks();
    final grid = db.guide(
      db.channels(),
      now,
      now.add(const Duration(hours: 3)),
    );
    final queryMs = sw.elapsedMilliseconds;

    expect(r.programmes, channels * days * 48);
    expect(grid.length, channels);
    // ignore: avoid_print
    print(
      'imported ${r.programmes} programmes in $importMs ms; '
      'linked + 3h grid for $channels channels in $queryMs ms',
    );
    expect(importMs, lessThan(20000));
  });
}
