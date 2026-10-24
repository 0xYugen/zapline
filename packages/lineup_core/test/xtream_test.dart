import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lineup_core/lineup_core.dart';
import 'package:test/test.dart';

void main() {
  group('detectXtreamCredentials', () {
    test('get.php link', () {
      final c = detectXtreamCredentials(
          'http://panel.example:8080/get.php?username=alice&password=s3cret&type=m3u_plus&output=ts');
      expect(c, isNotNull);
      expect(c!.baseUrl.toString(), 'http://panel.example:8080');
      expect(c.username, 'alice');
      expect(c.password, 's3cret');
    });

    test('stream path forms', () {
      expect(
          detectXtreamCredentials('http://p.example/live/bob/pw/123.ts')
              ?.username,
          'bob');
      expect(
          detectXtreamCredentials('https://p.example:443/movie/bob/pw/9.mkv')
              ?.password,
          'pw');
      expect(detectXtreamCredentials('http://p.example/bob/pw/123')?.username,
          'bob');
    });

    test('rejects other URLs', () {
      expect(
          detectXtreamCredentials('http://example.com/playlist.m3u'), isNull);
      expect(detectXtreamCredentials('not a url'), isNull);
      expect(
          detectXtreamCredentials(
              'ftp://p.example/get.php?username=a&password=b'),
          isNull);
    });
  });

  group('XtreamClient', () {
    final creds = XtreamCredentials(
        baseUrl: Uri.parse('http://panel.example:8080'),
        username: 'alice',
        password: 'p/w');

    XtreamClient clientFor(Map<String?, Object?> byAction) =>
        XtreamClient(creds, httpClient: MockClient((req) async {
          expect(req.headers['User-Agent'], isNotEmpty);
          final action = req.url.queryParameters['action'];
          if (!byAction.containsKey(action)) return http.Response('', 404);
          return http.Response(jsonEncode(byAction[action]), 200);
        }));

    test('authenticate tolerates string types', () async {
      final client = clientFor({
        null: {
          'user_info': {
            'auth': 1,
            'status': 'Active',
            'exp_date': '1893456000',
            'max_connections': '2',
            'active_cons': 0,
            'allowed_output_formats': ['m3u8', 'ts'],
          },
          'server_info': {
            'timezone': 'Europe/Rome',
            'https_port': '443',
            'time_now': '2026-10-24 22:00:07',
            'timestamp_now': 1792872000, // 2026-10-24 20:00 UTC
          },
        },
      });
      final account = await client.authenticate();
      expect(account.isActive, isTrue);
      expect(account.expiresAt, DateTime.utc(2030, 1, 1));
      expect(account.maxConnections, 2);
      expect(account.preferredLiveExtension, 'ts');
      expect(account.serverTimezone, 'Europe/Rome');
      expect(account.serverUtcOffset, const Duration(hours: 2));
    });

    test('authenticate rejects bad login', () async {
      final client = clientFor({
        null: {
          'user_info': {'auth': 0}
        }
      });
      expect(client.authenticate(), throwsA(isA<XtreamException>()));
    });

    test('lists live streams, empty object means empty list', () async {
      final client = clientFor({
        'get_live_streams': [
          {
            'num': 1,
            'name': ' News 24 ',
            'stream_id': '101',
            'epg_channel_id': 'news.example',
            'category_id': 3,
            'tv_archive': '1',
            'tv_archive_duration': '5',
          }
        ],
        'get_vod_streams': <String, Object?>{},
      });
      final live = await client.liveStreams();
      expect(live.single.streamId, 101);
      expect(live.single.name, 'News 24');
      expect(live.single.categoryId, '3');
      expect(live.single.hasArchive, isTrue);
      expect(live.single.archiveDays, 5);
      expect(await client.vodStreams(), isEmpty);
    });

    test('short EPG decodes base64 only when encoded', () async {
      final client = clientFor({
        'get_short_epg': {
          'epg_listings': [
            {
              'title': base64.encode(utf8.encode('Evening news')),
              'description': 'Plain text',
              'start_timestamp': '1767312000',
              'stop_timestamp': 1767313800,
            }
          ]
        }
      });
      final epg = await client.shortEpg(101);
      expect(epg.single.title, 'Evening news');
      expect(epg.single.description, 'Plain text');
      expect(epg.single.stop.difference(epg.single.start).inMinutes, 30);
    });

    test('builds stream and catch-up URLs', () {
      final client = XtreamClient(creds);
      expect(client.liveUrl(101).toString(),
          'http://panel.example:8080/live/alice/p%2Fw/101.ts');
      expect(
        client
            .timeshiftUrl(101,
                start: DateTime.utc(2026, 10, 24, 18, 30),
                duration: const Duration(minutes: 90),
                serverOffset: const Duration(hours: 2))
            .path,
        '/timeshift/alice/p%2Fw/90/2026-10-24:20-30/101.ts',
      );
      expect(client.xmltvUrl.queryParameters['username'], 'alice');
    });
  });
}
