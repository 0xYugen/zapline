import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

Channel _ch(String id, String group) => Channel(
  sourceId: 's',
  id: id,
  name: 'Ch $id',
  groupTitle: group,
  streamUrl: Uri.parse('http://x.example/$id.ts'),
);

void main() {
  late ZaplineDatabase db;
  setUp(() {
    db = ZaplineDatabase.inMemory()
      ..saveSource(
        const SourceRecord(
          id: 's',
          kind: SourceKind.m3u,
          name: 'S',
          url: 'http://x',
        ),
      )
      ..replaceChannels('s', [
        _ch('1', 'IT | Sport'),
        _ch('2', 'IT | News'),
        _ch('3', 'UK | Sport'),
        _ch('4', 'XXX Adult'),
        _ch('5', 'IT | Kids'),
      ]);
  });
  tearDown(() => db.close());

  List<String> ids([ChannelVisibility v = ChannelVisibility.visible]) => [
    for (final c in db.channels(visibility: v)) c.id,
  ];

  test('group filter hides groups; explicit choices win over it', () {
    db.applyGroupVisibility('s', const GroupFilter(include: ['it']));
    expect(ids(), ['1', '2', '5']);
    expect(db.groups(), ['IT | Sport', 'IT | News', 'IT | Kids']);
    expect(db.channelCount(), 5, reason: 'total ignores visibility');

    db.setGroupHidden('s', 'UK | Sport', false); // show despite the filter
    db.setGroupHidden('s', 'IT | News', true); // hide despite the filter
    db.applyGroupVisibility('s', const GroupFilter(include: ['it']));
    expect(ids(), ['1', '3', '5']);

    final info = {for (final g in db.groupInfo('s')) g.title: g};
    expect(info['UK | Sport']!.explicit, isFalse);
    expect(info['XXX Adult']!.hidden, isTrue);
    expect(info['XXX Adult']!.explicit, isNull);
    expect(info['IT | Sport']!.channels, 1);

    // Back to "follow the filter".
    db.setGroupHidden('s', 'UK | Sport', null);
    db.applyGroupVisibility('s', GroupFilter.none);
    expect(ids(), ['1', '3', '4', '5']);
  });

  test('a re-sync keeps preferences for groups that still exist', () {
    db.setGroupHidden('s', 'XXX Adult', true);
    db.applyGroupVisibility('s', GroupFilter.none);
    db.replaceChannels('s', [_ch('1', 'IT | Sport'), _ch('9', 'XXX Adult')]);
    db.applyGroupVisibility('s', GroupFilter.none);
    expect(ids(), ['1']);
  });

  test('hidden channels and locked groups', () {
    db.setChannelHidden(_ch('2', 'IT | News'), true);
    db.setGroupLocked('s', 'XXX Adult', true);
    expect(ids(), ['1', '3', '5']);
    expect(ids(ChannelVisibility.unlocked), ['1', '3', '4', '5']);
    expect(ids(ChannelVisibility.all), ['1', '2', '3', '4', '5']);
    expect(db.hiddenChannels().single.id, '2');
    expect(db.lockedGroups(), {'XXX Adult'});
    expect(db.groups(), contains('XXX Adult'), reason: 'listed with a lock');
    expect(db.search('ch'), hasLength(3));

    db.setChannelHidden(_ch('2', 'IT | News'), false);
    expect(ids(), ['1', '2', '3', '5']);
  });

  test('recents are most recent first and skip hidden channels', () {
    final t = DateTime.utc(2026);
    db.markWatched(_ch('1', ''), at: t);
    db.markWatched(_ch('3', ''), at: t.add(const Duration(minutes: 1)));
    db.markWatched(_ch('1', ''), at: t.add(const Duration(minutes: 2)));
    expect([for (final c in db.recents()) c.id], ['1', '3']);
    db.setChannelHidden(_ch('3', ''), true);
    expect([for (final c in db.recents()) c.id], ['1']);
  });

  test('settings', () {
    expect(db.setting('numbering'), isNull);
    db.setSetting('numbering', 'sequential');
    expect(db.setting('numbering'), 'sequential');
    db.setSetting('numbering', null);
    expect(db.setting('numbering'), isNull);
  });

  test('sync applies the filter and shifts the guide', () async {
    final now = DateTime.now().toUtc();
    String ts(DateTime t) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}00 +0000';
    }

    final start = DateTime.utc(now.year, now.month, now.day, now.hour);
    final client = MockClient((req) async {
      if (req.url.path == '/l.m3u') {
        return http.Response(
          '#EXTM3U url-tvg="http://x/g.xml"\n'
          '#EXTINF:-1 tvg-id="a" group-title="IT | A",A\nhttp://x/a.ts\n'
          '#EXTINF:-1 tvg-id="b" group-title="DE | B",B\nhttp://x/b.ts\n',
          200,
        );
      }
      return http.Response.bytes(
        utf8.encode(
          '<tv><channel id="a"><display-name>A</display-name></channel>'
          '<programme start="${ts(start)}" '
          'stop="${ts(start.add(const Duration(hours: 1)))}" channel="a">'
          '<title>Show</title></programme></tv>',
        ),
        200,
      );
    });
    final src = SourceRecord(
      id: 'm',
      kind: SourceKind.m3u,
      name: 'M',
      url: 'http://x/l.m3u',
      guideOffset: const Duration(hours: 1),
      groupFilter: const GroupFilter(include: ['it']),
    );
    db.saveSource(src);
    await SourceSync(db, httpClient: client).sync(src);

    expect([for (final c in db.channels(sourceId: 'm')) c.name], ['A']);
    final p = db
        .guide(
          db.channels(sourceId: 'm'),
          start,
          start.add(const Duration(hours: 3)),
        )
        .values
        .single
        .single;
    expect(p.start, start.add(const Duration(hours: 1)));
    final saved = db.sources().firstWhere((s) => s.id == 'm');
    expect(saved.groupFilter, const GroupFilter(include: ['it']));
    expect(saved.guideOffset, const Duration(hours: 1));
  });
}
