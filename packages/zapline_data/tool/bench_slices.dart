// How long the app waits to save a setting while a sync writes 150k
// channels twice on another isolate (saving four times a second), with
// and without write slices.
// Run with `dart run tool/bench_slices.dart`; GAP=ms sets the pause
// between slices (default 50).
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:isolate';

import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

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

Future<void> main() async {
  for (final slice in [
    const Duration(hours: 1),
    const Duration(milliseconds: 200),
  ]) {
    final dir = Directory.systemTemp.createTempSync('zapline_slices');
    final path = '${dir.path}/z.db';
    final db = ZaplineDatabase.open(path);
    db.saveSource(
      const SourceRecord(
        id: 's',
        kind: SourceKind.m3u,
        name: 'S',
        url: 'http://p.example',
      ),
    );
    final writing = Isolate.run(() {
      final other = ZaplineDatabase.open(path)
        ..writeSlice = slice
        ..writeGap = Duration(
          milliseconds: int.parse(Platform.environment["GAP"] ?? "50"),
        );
      final sw = Stopwatch()..start();
      other.replaceChannels('s', _channels(150000));
      other.replaceChannels('s', _channels(150000, tag: ' new'));
      other.close();
      return sw.elapsedMilliseconds;
    });
    var done = false;
    var longest = 0, busy = 0, saves = 0;
    writing.whenComplete(() => done = true).ignore();
    while (!done) {
      final sw = Stopwatch()..start();
      try {
        db.setSetting('tick', '${saves++}');
      } on Exception {
        busy++;
      }
      if (sw.elapsedMilliseconds > longest) longest = sw.elapsedMilliseconds;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final label = slice.inHours > 0 ? 'one transaction' : '200 ms slices';
    print(
      '${label.padRight(16)} write ${await writing} ms, '
      'longest wait to save $longest ms, $busy of $saves saves failed busy',
    );
    db.close();
    dir.deleteSync(recursive: true);
  }
}
