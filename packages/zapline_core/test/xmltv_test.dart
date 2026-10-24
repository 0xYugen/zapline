import 'dart:convert';

import 'package:zapline_core/zapline_core.dart';
import 'package:test/test.dart';

const _guide = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<tv generator-info-name="test">
  <channel id="News24.example">
    <display-name lang="en">News 24</display-name>
    <display-name>N24 HD</display-name>
    <icon src="http://logo.example/n24.png"/>
  </channel>
  <channel id="Sport.example">
    <display-name>Sport One</display-name>
  </channel>
  <programme start="20261024180000 +0200" stop="20261024183000 +0200" channel="News24.example">
    <title lang="en">Evening &amp; Night News</title>
    <title lang="it">Second title ignored</title>
    <desc><![CDATA[Headlines <b>today</b>]]></desc>
    <category>News</category>
    <icon src="http://img.example/p.jpg"/>
  </programme>
  <programme start="20261020100000" stop="20261020110000" channel="Sport.example">
    <title>Old match</title>
  </programme>
  <programme start="20261024190000 -0030" channel="Sport.example">
    <title>No stop time</title>
  </programme>
</tv>''';

Stream<String> _chunked(String s, int size) async* {
  for (var i = 0; i < s.length; i += size) {
    yield s.substring(i, i + size > s.length ? s.length : i + size);
  }
}

void main() {
  test('parseXmltvTime handles offsets and missing parts', () {
    expect(
        parseXmltvTime('20261024180000 +0200'), DateTime.utc(2026, 10, 24, 16));
    expect(parseXmltvTime('202610241800 -0130'),
        DateTime.utc(2026, 10, 24, 19, 30));
    expect(parseXmltvTime('20261024180000'), DateTime.utc(2026, 10, 24, 18));
    expect(parseXmltvTime('garbage'), isNull);
  });

  test('streams channels and programmes across arbitrary chunk boundaries',
      () async {
    final items =
        await const XmltvParser().parse(_chunked(_guide, 17)).toList();
    final channels = items.whereType<XmltvChannel>().toList();
    final progs =
        items.whereType<XmltvProgramme>().map((p) => p.programme).toList();

    expect(channels.map((c) => c.id), ['News24.example', 'Sport.example']);
    expect(channels.first.displayNames, ['News 24', 'N24 HD']);
    expect(channels.first.iconUrl.toString(), 'http://logo.example/n24.png');

    expect(progs, hasLength(3));
    expect(progs[0].title, 'Evening & Night News');
    expect(progs[0].description, 'Headlines <b>today</b>');
    expect(progs[0].category, 'News');
    expect(progs[0].start, DateTime.utc(2026, 10, 24, 16));
    expect(progs[0].iconUrl.toString(), 'http://img.example/p.jpg');
    expect(progs[2].stop.difference(progs[2].start), const Duration(hours: 1));
  });

  test('drops programmes outside the retention window', () async {
    final parser = XmltvParser(from: DateTime.utc(2026, 10, 23));
    final progs = await parser
        .parseBytes(Stream.value(utf8.encode(_guide)))
        .where((i) => i is XmltvProgramme)
        .toList();
    expect(progs, hasLength(2));
  });

  group('ChannelMatcher', () {
    final guide = [
      const XmltvChannel(id: 'News24.example', displayNames: ['News 24']),
      const XmltvChannel(id: 'Canale5.it', displayNames: []),
      const XmltvChannel(id: 'Canale5Plus1.it', displayNames: ['Canale 5 +1']),
    ];
    Channel ch(String name, {String? epgId}) => Channel(
        sourceId: 's',
        id: name,
        name: name,
        streamUrl: Uri.parse('http://x/1.ts'),
        epgChannelId: epgId);

    test('prefers epg id, then normalised name, then manual', () {
      final m =
          ChannelMatcher(guide, manualOverrides: {'s/Weird': 'News24.example'});
      expect(m.match(ch('Anything', epgId: 'news24.EXAMPLE'))?.kind,
          MatchKind.epgId);
      expect(m.match(ch('IT: News 24 FHD'))?.guideChannelId, 'News24.example');
      expect(m.match(ch('[IT] Canale 5 HD'))?.guideChannelId, 'Canale5.it');
      expect(
          m.match(ch('Canale 5 +1 HEVC'))?.guideChannelId, 'Canale5Plus1.it');
      expect(m.match(ch('Weird'))?.kind, MatchKind.manual);
      expect(m.match(ch('Unknown channel')), isNull);
    });

    test('normalizeChannelName', () {
      expect(normalizeChannelName('UK | BBC One HD'), 'bbcone');
      expect(normalizeChannelName('Télé Ciné 4K'), 'telecine');
    });
  });

  test('rankGuideCandidates orders plausible guide channels', () {
    const guide = [
      XmltvChannel(id: 'cinema1.test', displayNames: ['Cinema 1']),
      XmltvChannel(id: 'news24.test', displayNames: ['News 24']),
      XmltvChannel(id: 'cinemaclassic.test', displayNames: ['Cinema Classic']),
      XmltvChannel(id: 'sport.test', displayNames: ['Sport One']),
    ];
    final r = rankGuideCandidates('IT: Cinema One HD', guide);
    expect(r.first.$1.id, startsWith('cinema'));
    expect(r.map((e) => e.$1.id), isNot(contains('news24.test')));

    expect(
        rankGuideCandidates('News 24 FHD', guide).first.$1.id, 'news24.test');
    expect(rankGuideCandidates('News 24 FHD', guide).first.$2, 1.0);
    expect(rankGuideCandidates('Something else', guide), isEmpty);
  });
}
