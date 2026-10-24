import 'package:lineup_core/lineup_core.dart';
import 'package:test/test.dart';

Channel _ch(String url, CatchupMode mode, {String? source, int? days}) =>
    Channel(
      sourceId: 's',
      id: '1',
      name: 'C',
      streamUrl: Uri.parse(url),
      catchup: CatchupInfo(mode: mode, source: source, days: days),
    );

void main() {
  final start = DateTime.utc(2026, 10, 24, 18, 30);
  final stop = DateTime.utc(2026, 10, 24, 20, 0);
  final now = DateTime.utc(2026, 10, 24, 21, 0);
  final s = start.millisecondsSinceEpoch ~/ 1000;

  Uri? build(Channel c, {Duration offset = Duration.zero}) => buildCatchupUrl(
        c,
        start: start,
        stop: stop,
        now: now,
        serverOffset: offset,
      );

  test('xtream: derived from the live URL, start in panel time', () {
    final c = _ch(
        'http://p.example:8080/live/al%2Fice/pw/123.ts', CatchupMode.xtream);
    expect(
      build(c, offset: const Duration(hours: 1)).toString(),
      'http://p.example:8080/timeshift/al%2Fice/pw/90/2026-10-24:19-30/123.ts',
    );
    expect(build(_ch('http://p.example/x.m3u8', CatchupMode.xtream)), isNull);
    expect(
      build(_ch('http://p.example/live/u/p/9.m3u8', CatchupMode.xtream))!.path,
      endsWith('/9.m3u8'),
    );
  });

  test('default template with all placeholder families', () {
    final c = _ch(
      'http://p.example/live/1.m3u8',
      CatchupMode.defaultMode,
      source: 'http://a.example/{Y}/{m}/{d}/{H}{M}{S}?s={utc}&e=\${end}'
          '&d={duration:60}&o={offset:60}&n={lutc}',
    );
    expect(
      build(c).toString(),
      'http://a.example/2026/10/24/183000?s=$s&e=${s + 5400}'
      '&d=90&o=150&n=${now.millisecondsSinceEpoch ~/ 1000}',
    );
  });

  test('append and shift', () {
    expect(
      build(_ch('http://p.example/c.m3u8', CatchupMode.append,
              source: '?start={utc}&dur={duration}'))
          .toString(),
      'http://p.example/c.m3u8?start=$s&dur=5400',
    );
    final shifted =
        build(_ch('http://p.example/c.ts?token=abc', CatchupMode.shift))!;
    expect(shifted.queryParameters['token'], 'abc');
    expect(shifted.queryParameters['utc'], '$s');
  });

  test('flussonic path rewriting', () {
    expect(
      build(_ch('http://f.example/ch1/mpegts?token=t', CatchupMode.flussonic))
          .toString(),
      'http://f.example/ch1/timeshift_abs-$s.ts?token=t',
    );
    expect(
      build(_ch('http://f.example/ch1/index.m3u8', CatchupMode.flussonic))
          .toString(),
      'http://f.example/ch1/index-$s-5400.m3u8',
    );
  });

  test('canReplay respects archive depth and future programmes', () {
    final c =
        _ch('http://p.example/live/u/p/1.ts', CatchupMode.xtream, days: 1);
    Programme p(DateTime st) => Programme(
        channelId: 'g',
        start: st,
        stop: st.add(const Duration(hours: 1)),
        title: 't');
    expect(canReplay(c, p(now.subtract(const Duration(hours: 3))), now: now),
        isTrue);
    expect(canReplay(c, p(now.subtract(const Duration(days: 2))), now: now),
        isFalse);
    expect(
        canReplay(c, p(now.add(const Duration(hours: 1))), now: now), isFalse);
    final noArchive = Channel(
        sourceId: 's', id: '2', name: 'n', streamUrl: Uri.parse('http://x'));
    expect(canReplay(noArchive, p(start), now: now), isFalse);
  });
}
