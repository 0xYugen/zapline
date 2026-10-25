import 'dart:convert';
import 'dart:io' show gzip;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';
import 'package:test/test.dart';

String _ts(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}00 +0000';
}

String _xmltv(DateTime now) {
  final b = StringBuffer(
    '<tv><channel id="news.example">'
    '<display-name>News 24</display-name></channel>',
  );
  for (var i = -2; i < 4; i++) {
    final s = now.add(Duration(hours: i));
    b.write(
      '<programme start="${_ts(s)}" '
      'stop="${_ts(s.add(const Duration(hours: 1)))}" channel="news.example">'
      '<title>Hour $i</title></programme>',
    );
  }
  // Far outside the retention window: must be dropped.
  b.write(
    '<programme start="20200101000000 +0000" stop="20200101010000 +0000" '
    'channel="news.example"><title>Old</title></programme>',
  );
  b.write('</tv>');
  return b.toString();
}

void main() {
  final now = DateTime.now().toUtc();
  late ZaplineDatabase db;
  setUp(() => db = ZaplineDatabase.inMemory());
  tearDown(() => db.close());

  test('M3U source with gzipped guide from url-tvg', () async {
    final client = MockClient((req) async {
      switch (req.url.path) {
        case '/list.m3u':
          return http.Response(
            '#EXTM3U url-tvg="http://epg.example/guide.xml.gz"\n'
            '#EXTINF:-1 tvg-id="news.example" group-title="News" '
            'catchup="shift" catchup-days="2",News 24\n'
            'http://s.example/1.ts\n'
            '#EXTINF:-1,Unknown\nhttp://s.example/2.ts\n',
            200,
          );
        case '/guide.xml.gz':
          return http.Response.bytes(
            gzip.encode(utf8.encode(_xmltv(now))),
            200,
          );
      }
      return http.Response('', 404);
    });
    const src = SourceRecord(
      id: 'm',
      kind: SourceKind.m3u,
      name: 'M',
      url: 'http://p.example/list.m3u',
    );
    db.saveSource(src);

    final stages = <SyncStage>[];
    final r = await SourceSync(
      db,
      httpClient: client,
    ).sync(src, onProgress: (p) => stages.add(p.stage));

    expect(r.channels, 2);
    expect(r.guide.programmes, 6, reason: 'old programme filtered out');
    expect(r.coverage.matched, 1);
    expect(r.guideErrors, isEmpty);
    expect(stages.first, SyncStage.channels);
    expect(stages.last, SyncStage.done);
    expect(db.channels().first.catchup?.mode, CatchupMode.shift);
    expect(db.sources().single.syncedAt, isNotNull);

    final (cur, _) = db.nowNext(db.channels().first, now);
    expect(cur?.title, 'Hour 0');
  });

  test('a guide cut short or with a bad byte keeps what it had', () async {
    final xml = _xmltv(now).replaceFirst('Hour -2', 'Caffè ÿ');
    final bytes = [
      // A Latin-1 byte inside UTF-8, then the download stops mid-tag.
      ...utf8.encode(xml.substring(0, xml.indexOf('Hour 2'))).map(
        (b) => b == 0xc3 ? 0xe8 : b,
      ),
      ...utf8.encode('Hour 2</tit'),
    ];
    final client = MockClient((req) async {
      switch (req.url.path) {
        case '/list.m3u':
          return http.Response(
            '#EXTM3U url-tvg="http://epg.example/guide.xml"\n'
            '#EXTINF:-1 tvg-id="news.example",News 24\nhttp://s.example/1.ts\n',
            200,
          );
        case '/guide.xml':
          return http.Response.bytes(bytes, 200);
      }
      return http.Response('', 404);
    });
    const src = SourceRecord(
      id: 'm',
      kind: SourceKind.m3u,
      name: 'M',
      url: 'http://p.example/list.m3u',
    );
    db.saveSource(src);
    final r = await SourceSync(db, httpClient: client).sync(src);
    expect(r.guideErrors, isEmpty);
    expect(r.guide.programmes, 4);
    final (cur, _) = db.nowNext(db.channels().first, now);
    expect(cur?.title, 'Hour 0');
  });

  test(
    'Xtream source uses xmltv.php; a failing guide does not fail sync',
    () async {
      final client = MockClient((req) async {
        final action = req.url.queryParameters['action'];
        if (req.url.path == '/xmltv.php') return http.Response('nope', 500);
        final body = switch (action) {
          null => {
            'user_info': {'auth': 1, 'status': 'Active'},
            'server_info': {'timezone': 'UTC'},
          },
          'get_live_categories' => [
            {'category_id': '1', 'category_name': 'News'},
          ],
          'get_live_streams' => [
            {
              'stream_id': '7',
              'name': 'News 24',
              'category_id': '1',
              'epg_channel_id': 'news.example',
            },
          ],
          _ => <Object>[],
        };
        return http.Response(jsonEncode(body), 200);
      });
      const src = SourceRecord(
        id: 'x',
        kind: SourceKind.xtream,
        name: 'X',
        url: 'http://panel.example:8080',
        username: 'u',
        password: 'p',
      );
      db.saveSource(src);
      final r = await SourceSync(db, httpClient: client).sync(src);
      expect(r.channels, 1);
      expect(r.guideErrors.single, contains('HTTP 500'));
      final c = db.channels().single;
      expect(c.groupTitle, 'News');
      // Stored without the account's credentials; back at play time.
      expect(c.streamUrl.toString(), isNot(contains('/u/p/')));
      expect(
        revealCredentials(c.streamUrl, 'u', 'p').toString(),
        'http://panel.example:8080/live/u/p/7.ts',
      );
    },
  );

  test(
    'playlist films and episodes go to the catalogue, not channels',
    () async {
      final client = MockClient(
        (req) async => http.Response(
          '#EXTM3U\n'
          '#EXTINF:-1 group-title="TV",Rai 1\n'
          'http://p.example/live/u/p/1.ts\n'
          '#EXTINF:-1 group-title="IT Film" tvg-logo="http://img/f.jpg",'
          'Un film (2020)\n'
          'http://p.example/movie/u/p/9.mkv\n'
          '#EXTINF:-1 group-title="IT Serie",La casa S01 E02\n'
          'http://p.example/series/u/p/12.mp4\n'
          '#EXTINF:-1 group-title="IT Serie",La casa S01 E01\n'
          'http://p.example/series/u/p/11.mp4\n',
          200,
        ),
      );
      const src = SourceRecord(
        id: 'v',
        kind: SourceKind.m3u,
        name: 'V',
        url: 'http://p.example/list.m3u',
      );
      db.saveSource(src);
      final r = await SourceSync(
        db,
        httpClient: client,
      ).sync(src, includeGuide: false);
      expect(r.channels, 1);
      expect(r.movies, 1);
      expect(r.shows, 1);
      expect(db.movies().single.name, 'Un film (2020)');
      expect(db.movies().single.year, 2020);
      expect(db.shows().single.name, 'La casa');
      expect(
        db.playlistEpisodes('v', 'la casa').map((e) => e.streamUrl.toString()),
        [
          'http://p.example/series/u/p/11.mp4',
          'http://p.example/series/u/p/12.mp4',
        ],
      );
    },
  );

  test('bad login surfaces a readable error', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'user_info': {'auth': 0},
        }),
        200,
      ),
    );
    const src = SourceRecord(
      id: 'x',
      kind: SourceKind.xtream,
      name: 'X',
      url: 'http://p.example',
    );
    expect(
      SourceSync(db, httpClient: client).sync(src),
      throwsA(
        isA<SyncException>().having(
          (e) => e.message,
          'message',
          contains('password'),
        ),
      ),
    );
  });
}
