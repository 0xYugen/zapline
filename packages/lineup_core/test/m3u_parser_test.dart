import 'dart:convert';

import 'package:lineup_core/lineup_core.dart';
import 'package:test/test.dart';

const _playlist =
    '﻿#EXTM3U url-tvg="http://epg.example/a.xml.gz,http://epg.example/b.xml" tvg-shift="1"\r\n'
    '#EXTINF:-1 tvg-id="news.example" tvg-name="News 24" tvg-logo="http://logo/n.png" group-title="News, World" catchup="xc" catchup-days="7",News 24 HD\r\n'
    '#EXTVLCOPT:http-user-agent=CustomAgent/1.0\r\n'
    '#EXTVLCOPT:http-referrer=http://ref.example/\r\n'
    'http://stream.example/live/u/p/1.ts\r\n'
    '\r\n'
    '#EXTGRP:Sports\r\n'
    '#EXTINF:-1 tvg-id="" tvg-chno="7",Sport One\r\n'
    '#KODIPROP:inputstream.adaptive.manifest_type=hls\r\n'
    'http://stream.example/sport.m3u8\r\n'
    '#EXTINF:-1,Sport Two\r\n'
    'http://stream.example/sport2.m3u8\r\n'
    'http://bare.example/no-extinf.ts\r\n';

void main() {
  group('M3uParser', () {
    test('parses header, attributes, options and groups', () {
      final parser = M3uParser();
      final entries = parser.parse(_playlist);

      expect(parser.header.epgUrls.map((u) => u.toString()),
          ['http://epg.example/a.xml.gz', 'http://epg.example/b.xml']);
      expect(entries, hasLength(4));

      final news = entries[0];
      expect(news.title, 'News 24 HD');
      expect(news.tvgId, 'news.example');
      expect(news.group, 'News, World', reason: 'comma inside quotes');
      expect(news.catchup, 'xc');
      expect(news.catchupDays, 7);
      expect(news.httpHeaders, {
        'User-Agent': 'CustomAgent/1.0',
        'Referer': 'http://ref.example/',
      });

      final sport = entries[1];
      expect(sport.tvgId, isNull, reason: 'empty attribute treated as absent');
      expect(sport.tvgChno, 7);
      expect(sport.group, 'Sports');
      expect(sport.kodiProps['inputstream.adaptive.manifest_type'], 'hls');
      expect(sport.httpHeaders, isEmpty);

      expect(entries[2].group, 'Sports', reason: '#EXTGRP carries over');

      expect(entries[3].title, 'http://bare.example/no-extinf.ts');
      expect(entries[3].duration, -1);
    });

    test('streaming parse matches in-memory parse', () async {
      final bytes = Stream.fromIterable([
        utf8.encode(_playlist.substring(0, 50)),
        utf8.encode(_playlist.substring(50))
      ]);
      final streamed = await M3uParser().parseBytes(bytes).toList();
      expect(streamed.map((e) => e.url),
          M3uParser().parse(_playlist).map((e) => e.url));
    });
  });
}
