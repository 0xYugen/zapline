import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';
import 'package:test/test.dart';

const _src = SourceRecord(
  id: 's',
  kind: SourceKind.m3u,
  name: 'S',
  url: 'http://p.example/list.m3u',
);

List<Channel> _channels(int n, {String tag = ''}) => [
  for (var i = 0; i < n; i++)
    Channel(
      sourceId: 's',
      id: '$i',
      name: 'Channel $i$tag',
      groupTitle: 'Group ${i % 40}',
      streamUrl: Uri.parse('http://s.example/$i.ts'),
    ),
];

Stream<XmltvItem> _guide(DateTime base, int channels, int each) async* {
  for (var c = 0; c < channels; c++) {
    yield XmltvChannel(id: 'g$c', displayNames: ['G $c']);
  }
  for (var c = 0; c < channels; c++) {
    for (var i = 0; i < each; i++) {
      final s = base.add(Duration(hours: i));
      yield XmltvProgramme(
        Programme(
          channelId: 'g$c',
          start: s,
          stop: s.add(const Duration(hours: 1)),
          title: 'P $c $i',
        ),
      );
    }
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 26, 12);

  test('big writes cut into slices end up the same', () async {
    final db = ZaplineDatabase.inMemory()
      // A new transaction at every chance.
      ..writeSlice = Duration.zero
      ..writeGap = Duration.zero;
    addTearDown(db.close);
    db.saveSource(_src);
    db.replaceChannels('s', _channels(300));
    db.replaceChannels('s', _channels(200, tag: ' new').reversed);
    expect(db.channelCount(sourceId: 's'), 200);
    expect(db.channels().first.name, 'Channel 199 new');

    db.replaceMovies('s', [
      for (var i = 0; i < 50; i++)
        Movie(sourceId: 's', id: '$i', name: 'Film $i'),
    ]);
    expect(db.movieCount(sourceId: 's'), 50);

    final start = now.subtract(const Duration(days: 3));
    final r = await db.importGuide(_guide(start, 30, 300), now: now);
    expect(r.programmes, 9000);
    // Everything before now goes, in chunks of a few thousand.
    final gone = db.pruneProgrammes(now);
    expect(gone, 30 * 71); // the last one ends at now
    expect(db.pruneProgrammes(now), 0);
  });

  test('the app can write while a big list is written', () async {
    final dir = Directory.systemTemp.createTempSync('zapline_slices');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/z.db';
    final db = ZaplineDatabase.open(path);
    addTearDown(db.close);
    db.saveSource(_src);

    // The sync's connection, on its own isolate as in the app.
    final writing = Isolate.run(() {
      final sync = ZaplineDatabase.open(path);
      final sw = Stopwatch()..start();
      sync.replaceChannels('s', _channels(150000));
      sync.replaceChannels('s', _channels(150000, tag: ' new'));
      sync.close();
      return sw.elapsedMilliseconds;
    });
    var done = false;
    var longest = 0, writes = 0;
    writing.whenComplete(() => done = true).ignore();
    while (!done) {
      final sw = Stopwatch()..start();
      db.setSetting('tick', '$writes');
      writes++;
      if (sw.elapsedMilliseconds > longest) longest = sw.elapsedMilliseconds;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final total = await writing;
    expect(db.channelCount(sourceId: 's'), 150000);
    // Each wait is about one slice, not the whole write.
    if (total > 1500) {
      expect(longest, lessThan(total ~/ 2), reason: 'write took $total ms');
    }
    expect(longest, lessThan(1500));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('small writes on a busy database say to try later', () {
    final dir = Directory.systemTemp.createTempSync('zapline_busy');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/z.db';
    final db = ZaplineDatabase.open(path, busyTimeoutMs: 50);
    addTearDown(db.close);
    db.saveSource(_src);
    db.replaceChannels('s', _channels(1));
    final channel = db.channels().single;
    final programmes = [
      Programme(
        channelId: 'x',
        start: now,
        stop: now.add(const Duration(hours: 1)),
        title: 'News',
      ),
    ];

    // Another connection holding the lock, as a sync does.
    final other = sqlite3.open(path)..execute('BEGIN IMMEDIATE');
    expect(db.storeChannelGuide(channel, programmes), isFalse);
    expect(db.savePosition('movie:s/1', Duration.zero, Duration.zero), isFalse);
    expect(db.tryWrite(() => db.setSetting('a', '1')), isFalse);
    expect(() => db.setSetting('a', '1'), throwsA(isA<SqliteException>()));
    other
      ..execute('COMMIT')
      ..close();

    expect(db.storeChannelGuide(channel, programmes), isTrue);
    expect(db.savePosition('movie:s/1', Duration.zero, Duration.zero), isTrue);
    expect(db.tryWrite(() => db.setSetting('a', '1')), isTrue);
    expect(db.setting('a'), '1');
  });
}
