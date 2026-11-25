import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:zapline_data/zapline_data.dart';

String _ts(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}'
      '${two(t.minute)}00 +0000';
}

String _xmltv(DateTime now, String channel) {
  final b = StringBuffer(
    '<tv><channel id="$channel"><display-name>$channel</display-name>'
    '</channel>',
  );
  for (var i = -1; i < 3; i++) {
    final s = now.add(Duration(hours: i));
    b.write(
      '<programme start="${_ts(s)}" '
      'stop="${_ts(s.add(const Duration(hours: 1)))}" channel="$channel">'
      '<title>$channel $i</title></programme>',
    );
  }
  return '$b</tv>';
}

void main() {
  final now = DateTime.now().toUtc();
  late ZaplineDatabase db;
  setUp(() => db = ZaplineDatabase.inMemory());
  tearDown(() => db.close());

  /// A playlist with one guide whose server answers 304 to its ETag;
  /// [conditional] collects what each guide request asked.
  MockClient server(List<String?> conditional, {String etag = '"v1"'}) =>
      MockClient((req) async {
        switch (req.url.path) {
          case '/list.m3u':
            return http.Response(
              '#EXTM3U url-tvg="http://epg.example/guide.xml"\n'
              '#EXTINF:-1 tvg-id="news.example",News\n'
              'http://s.example/1.ts\n',
              200,
            );
          case '/guide.xml':
            final asked = req.headers['If-None-Match'];
            conditional.add(asked);
            if (asked == etag) return http.Response('', 304);
            return http.Response(
              _xmltv(now, 'news.example'),
              200,
              headers: {'etag': etag},
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

  test('an unchanged guide is not downloaded again', () async {
    db.saveSource(src);
    final asked = <String?>[];
    final client = server(asked);
    final first = await SourceSync(db, httpClient: client).sync(src);
    expect(first.guide.programmes, 4);

    final again = await SourceSync(db, httpClient: client).sync(src);
    expect(asked, [null, '"v1"']);
    expect(again.guideErrors, isEmpty);
    expect(again.guide.programmes, 4, reason: 'what the last import brought');
    expect(again.coverage.matched, 1);
    final ch = db.channels().single;
    expect(db.nowNext(ch, now).$1?.title, 'news.example 0');
  });

  test('a changed guide, other settings or a lost guide download', () async {
    db.saveSource(src);
    final asked = <String?>[];
    await SourceSync(db, httpClient: server(asked)).sync(src);

    // The server has a new version.
    await SourceSync(db, httpClient: server(asked, etag: '"v2"')).sync(src);
    expect(asked.last, '"v1"');
    // More days kept: downloaded in full.
    await SourceSync(
      db,
      httpClient: server(asked, etag: '"v2"'),
      guideAhead: const Duration(days: 3),
    ).sync(src);
    expect(asked.last, isNull);
    // The programmes went (pruned, a database cleared): downloaded again.
    db.pruneProgrammes(now.add(const Duration(days: 30)));
    await SourceSync(
      db,
      httpClient: server(asked, etag: '"v2"'),
      guideAhead: const Duration(days: 3),
    ).sync(src);
    expect(asked.last, isNull);
    expect(db.nowNext(db.channels().single, now).$1, isNotNull);
  });

  test('a guide cut short is downloaded in full next time', () async {
    db.saveSource(src);
    final asked = <String?>[];
    final client = MockClient((req) async {
      switch (req.url.path) {
        case '/list.m3u':
          return http.Response(
            '#EXTM3U url-tvg="http://epg.example/guide.xml"\n'
            '#EXTINF:-1 tvg-id="news.example",News\n'
            'http://s.example/1.ts\n',
            200,
          );
        case '/guide.xml':
          asked.add(req.headers['If-None-Match']);
          final xml = _xmltv(now, 'news.example');
          // Broken off in the middle of the last programme.
          return http.Response(
            xml.substring(0, xml.length - 30),
            200,
            headers: {'etag': '"v1"'},
          );
      }
      return http.Response('', 404);
    });
    await SourceSync(db, httpClient: client).sync(src);
    await SourceSync(db, httpClient: client).sync(src);
    expect(asked, [null, null]);
  });
}
