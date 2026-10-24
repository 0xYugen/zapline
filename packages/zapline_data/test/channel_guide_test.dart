import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

void main() {
  final now = DateTime.now().toUtc();
  const source = SourceRecord(
    id: 'x',
    kind: SourceKind.xtream,
    name: 'X',
    url: 'http://panel.example:8080',
    username: 'u',
    password: 'p',
  );
  final channel = Channel(
    sourceId: 'x',
    id: '42',
    name: 'Rai 1 HD',
    epgChannelId: 'rai1.it',
    streamUrl: Uri.parse('http://panel.example:8080/live/u/p/42.ts'),
  );

  late ZaplineDatabase db;
  setUp(() {
    db = ZaplineDatabase.inMemory()..saveSource(source);
    db.replaceChannels('x', [channel]);
  });
  tearDown(() => db.close());

  int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  test('short EPG fills a channel the XMLTV guide does not cover', () async {
    // A panel whose xmltv.php is empty: nothing is linked after a sync.
    expect(db.rebuildGuideLinks().matched, 0);
    expect(db.nowNext(channel, now).$1, isNull);

    Uri? asked;
    final fetcher = ChannelGuideFetcher(
      db,
      httpClient: MockClient((req) async {
        asked = req.url;
        final start = now.subtract(const Duration(minutes: 20));
        return http.Response(
          jsonEncode({
            'epg_listings': [
              {
                // Panels often Base64-encode titles.
                'title': base64.encode(utf8.encode('Telegiornale')),
                'description': 'Notizie',
                'start_timestamp': '${secs(start)}',
                'stop_timestamp':
                    '${secs(start.add(const Duration(minutes: 40)))}',
              },
              {
                'title': 'Film',
                'start_timestamp':
                    '${secs(start.add(const Duration(minutes: 40)))}',
                'stop_timestamp':
                    '${secs(start.add(const Duration(minutes: 160)))}',
              },
            ],
          }),
          200,
        );
      }),
    );
    expect(await fetcher.fetch(source, channel), 2);
    expect(asked!.queryParameters['action'], 'get_short_epg');
    expect(asked!.queryParameters['stream_id'], '42');

    final (current, next) = db.nowNext(channel, now);
    expect(current!.title, 'Telegiornale');
    expect(current.description, 'Notizie');
    expect(next!.title, 'Film');

    // A later sync without an XMLTV match keeps the fetched guide linked,
    // and the per-channel guide never shows up for manual mapping.
    expect(db.rebuildGuideLinks().matched, 1);
    expect(db.nowNext(channel, now).$1!.title, 'Telegiornale');
    expect(db.guideChannels(), isEmpty);
  });

  test('M3U sources and empty answers store nothing', () async {
    final fetcher = ChannelGuideFetcher(
      db,
      httpClient: MockClient(
        (_) async => http.Response('{"epg_listings": []}', 200),
      ),
    );
    expect(await fetcher.fetch(source, channel), 0);
    expect(
      await fetcher.fetch(
        const SourceRecord(id: 'm', kind: SourceKind.m3u, name: 'M', url: 'u'),
        channel,
      ),
      0,
    );
    expect(db.nowNext(channel, now).$1, isNull);
  });
}
