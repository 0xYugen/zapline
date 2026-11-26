// Time to load a big channel list (50k channels, as a large Xtream
// account): `dart run tool/bench_channels.dart`. Desktop numbers; a TV
// stick is several times slower.
// ignore_for_file: avoid_print
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

void main() {
  final db = ZaplineDatabase.inMemory()
    ..saveSource(
      const SourceRecord(
        id: 's',
        kind: SourceKind.xtream,
        name: 'Panel',
        url: 'http://panel.example.com:8080',
      ),
    );
  db.replaceChannels('s', [
    for (var i = 0; i < 50000; i++)
      Channel(
        sourceId: 's',
        id: '$i',
        name: 'IT | Channel $i HD',
        number: i + 1,
        groupTitle: 'Group ${i % 300}',
        streamUrl: Uri.parse(
          'http://panel.example.com:8080/live/{user}/{pass}/$i.ts',
        ),
        logoUrl: Uri.parse('http://logos.example.com/images/channel_$i.png'),
        epgChannelId: 'ch$i.it',
        catchup: const CatchupInfo(mode: CatchupMode.xtream, days: 3),
        httpHeaders: const {'User-Agent': 'Zapline'},
      ),
  ]);
  for (final (label, run) in [
    ('channels() all', () => db.channels().length),
    ('channels(group)', () => db.channels(group: 'Group 7').length),
  ]) {
    run();
    final w = Stopwatch()..start();
    const n = 5;
    for (var i = 0; i < n; i++) {
      run();
    }
    print(
      '$label: ${(w.elapsedMicroseconds / n / 1000).toStringAsFixed(1)} ms',
    );
  }
  // What the screens then read of each row.
  final all = db.channels();
  final w = Stopwatch()..start();
  var n = 0;
  for (final c in all.take(30)) {
    n += c.streamUrl.path.length + (c.logoUrl?.path.length ?? 0);
  }
  print('30 rows used: ${w.elapsedMicroseconds} µs ($n)');
}
