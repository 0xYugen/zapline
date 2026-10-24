// End-to-end check against tools/mock_panel. Skipped unless MOCK_PANEL is set:
//
//   dart run tools/mock_panel/mock_panel.dart &
//   MOCK_PANEL=http://localhost:8099 dart test test/mock_panel_e2e_test.dart
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lineup_core/lineup_core.dart';
import 'package:test/test.dart';

void main() {
  final base = Platform.environment['MOCK_PANEL'];

  test('login, channels, guide and matching against the mock panel', () async {
    final creds = detectXtreamCredentials(
        '$base/get.php?username=demo&password=demo&type=m3u_plus')!;
    final client = XtreamClient(creds);
    addTearDown(client.close);

    final account = await client.authenticate();
    expect(account.isActive, isTrue);
    expect(account.expiresAt!.isAfter(DateTime.now()), isTrue);

    final streams = await client.liveStreams();
    expect(streams, hasLength(6));
    expect(await client.vodStreams(), isEmpty);

    final epg = await client.shortEpg(streams.first.streamId);
    expect(epg.first.title, contains('Big Buck Bunny'));

    final res = await http.Client().send(http.Request('GET', client.xmltvUrl));
    final now = DateTime.now().toUtc();
    final items =
        await XmltvParser(from: now, to: now.add(const Duration(hours: 6)))
            .parseBytes(res.stream)
            .toList();
    final guideChannels = items.whereType<XmltvChannel>().toList();
    expect(guideChannels, hasLength(6));
    expect(items.whereType<XmltvProgramme>().length, greaterThan(6 * 10));

    final matcher = ChannelMatcher(guideChannels);
    for (final s in streams) {
      final ch = Channel(
          sourceId: 'mock',
          id: '${s.streamId}',
          name: s.name,
          streamUrl: client.liveUrl(s.streamId),
          epgChannelId: s.epgChannelId);
      expect(matcher.match(ch)?.kind, MatchKind.epgId, reason: s.name);
    }

    final m3u = await http.Client().send(http.Request(
        'GET', Uri.parse('$base/get.php?username=demo&password=demo')));
    final parser = M3uParser();
    final entries = await parser.parseBytes(m3u.stream).toList();
    expect(entries, hasLength(6));
    expect(parser.header.epgUrls.single.path, '/xmltv.php');
    expect(detectXtreamCredentials(entries.first.url)?.username, 'demo');
  }, skip: base == null ? 'set MOCK_PANEL to run' : false);
}
