// Rough timings of the data layer on a big library: 50k channels, 100k
// films and a guide of 1M programmes. Run with
// `dart run tool/bench.dart [dir]`; the database file goes to [dir]
// (default: the system temp directory). BENCH_BATCH=n sets the guide
// import's batch size, BENCH_IMPORT_ONLY=1 stops after the import.
//
// Desktop numbers; a TV stick is several times slower.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

const _channels = 50000;
const _guideChannels = 5000;
const _perChannel = 200; // 200 programmes of 1 h: about 8 days

final _now = DateTime.utc(2026, 11, 25, 20);
final _start = _now.subtract(const Duration(days: 1));

final _words = [
  'News', 'Sport', 'Cinema', 'Montalbano', 'Calcio', 'Meteo', 'Quiz',
  'Documentario', 'Serie', 'Cartoni', 'Telegiornale', 'Musica', 'Viaggi',
  'Cucina', 'Storia', 'Scienza', 'Natura', 'Auto', 'Moda', 'Arte', //
];

String _title(int ch, int i) =>
    '${_words[(ch * 7 + i) % _words.length]} '
    '${_words[(ch + i * 3) % _words.length]} ${(ch * 31 + i) % 997}';

Stream<XmltvItem> _guide() async* {
  for (var c = 0; c < _guideChannels; c++) {
    yield XmltvChannel(id: 'g$c.it', displayNames: ['Guide $c']);
  }
  for (var c = 0; c < _guideChannels; c++) {
    for (var i = 0; i < _perChannel; i++) {
      final s = _start.add(Duration(hours: i));
      yield XmltvProgramme(
        Programme(
          channelId: 'g$c.it',
          start: s,
          stop: s.add(const Duration(hours: 1)),
          title: _title(c, i),
          description: 'Una descrizione abbastanza lunga del programma $i.',
        ),
      );
    }
  }
}

Iterable<Channel> _channelList() sync* {
  for (var i = 0; i < _channels; i++) {
    yield Channel(
      sourceId: 'src',
      id: '$i',
      name: 'Channel $i ${_words[i % _words.length]}',
      number: i + 1,
      groupTitle: 'Group ${i ~/ 250}',
      streamUrl: Uri.parse('http://panel.example/live/u/p/$i.ts'),
      logoUrl: Uri.parse('http://logo.example/$i.png'),
      epgChannelId: i < _guideChannels * 2 ? 'g${i % _guideChannels}.it' : null,
      httpHeaders: const {'User-Agent': 'Zapline'},
    );
  }
}

T _time<T>(String label, T Function() f, {int runs = 1}) {
  late T r;
  final sw = Stopwatch()..start();
  for (var i = 0; i < runs; i++) {
    r = f();
  }
  sw.stop();
  final ms = sw.elapsedMicroseconds / 1000 / runs;
  print('${label.padRight(34)} ${ms.toStringAsFixed(2).padLeft(9)} ms');
  return r;
}

Future<void> main(List<String> args) async {
  final dir = Directory(
    args.isEmpty ? Directory.systemTemp.path : args.first,
  ).createTempSync('zapline_bench');
  final db = ZaplineDatabase.open('${dir.path}/bench.db');
  db.saveSource(
    const SourceRecord(
      id: 'src',
      kind: SourceKind.m3u,
      name: 'Bench',
      url: 'http://panel.example',
    ),
  );
  _time('replaceChannels (first)', () {
    db.replaceChannels('src', _channelList());
  });
  _time('replaceChannels (unchanged)', () {
    db.replaceChannels('src', _channelList());
  });
  List<Movie> movies(int edition) => [
    for (var i = 0; i < 100000; i++)
      Movie(
        sourceId: 'src',
        id: '$i',
        name: 'Film $i ${_words[i % _words.length]} (${1950 + i % 75})',
        category: 'Cat ${i % 60}',
        posterUrl: Uri.parse('http://img.example/posters/$i.jpg'),
        rating: (i % 100) / 10,
        addedAt: DateTime.utc(2020).add(Duration(hours: i + edition)),
        containerExtension: 'mkv',
      ),
  ];
  final films = movies(0);
  _time('replaceMovies 100k (first)', () => db.replaceMovies('src', films));
  _time('replaceMovies (unchanged)', () => db.replaceMovies('src', films));
  final changed = movies(1);
  _time('replaceMovies (all changed)', () => db.replaceMovies('src', changed));
  _time('searchMovies("montal")', () => db.searchMovies('montal'), runs: 10);
  _time('searchMovies("zzzz")', () => db.searchMovies('zzzz'), runs: 10);

  final batch = Platform.environment['BENCH_BATCH'];
  Future<GuideImportResult> import() => batch == null
      ? db.importGuide(_guide(), now: _now)
      : db.importGuide(_guide(), now: _now, batchSize: int.parse(batch));
  var sw = Stopwatch()..start();
  final r = await import();
  print(
    '${'importGuide (batch ${batch ?? 'default'})'.padRight(34)} '
    '${sw.elapsedMilliseconds.toString().padLeft(6)} ms  ($r)',
  );
  sw = Stopwatch()..start();
  await import();
  print(
    '${'importGuide again (replaces)'.padRight(34)} '
    '${sw.elapsedMilliseconds.toString().padLeft(6)} ms',
  );
  if (Platform.environment['BENCH_IMPORT_ONLY'] != null) {
    db.close();
    dir.deleteSync(recursive: true);
    return;
  }
  _time('rebuildGuideLinks', db.rebuildGuideLinks);

  final all = db.channels();
  for (var i = 0; i < 40; i++) {
    db.setFavourite(all[i * 997], true);
    db.markWatched(all[i * 991], at: _now.add(Duration(seconds: i)));
    db.setChannelHidden(all[i * 983 + 1], true);
  }

  _time('channels() all', db.channels, runs: 3);
  _time('channels(group)', () => db.channels(group: 'Group 77'), runs: 20);
  _time('groups()', db.groups, runs: 10);
  _time('recents(limit: 1)', () => db.recents(limit: 1), runs: 20);
  _time('recents()', db.recents, runs: 20);
  _time('favourites()', db.favourites, runs: 20);
  _time('hiddenChannels()', db.hiddenChannels, runs: 20);
  _time('search("chan 12")', () => db.search('chan 12'), runs: 20);
  _time(
    'searchProgrammes("montal")',
    () => db.searchProgrammes('montal', from: _now),
    runs: 5,
  );
  _time(
    'searchProgrammes("zzzz")',
    () => db.searchProgrammes('zzzz', from: _now),
    runs: 5,
  );
  final row = all.sublist(1000, 1015);
  _time(
    'guide(15 rows, 2 h)',
    () => db.guide(row, _now, _now.add(const Duration(hours: 2))),
    runs: 20,
  );
  final page = all.sublist(0, 300);
  _time(
    'guide(300 rows, 3 days)',
    () => db.guide(page, _now, _now.add(const Duration(days: 3))),
    runs: 5,
  );
  _time(
    'guide(300 rows, 3 days, no desc)',
    () => db.guide(
      page,
      _now,
      _now.add(const Duration(days: 3)),
      withDescriptions: false,
    ),
    runs: 5,
  );
  _time('nowNext x15', () {
    for (final c in row) {
      db.nowNext(c, _now);
    }
  }, runs: 20);
  _time('airingOn', () => db.airingOn('g10.it', _now), runs: 50);
  _time(
    'pruneProgrammes (nothing to drop)',
    () => db.pruneProgrammes(_now.subtract(const Duration(days: 2))),
    runs: 5,
  );
  _time('storeChannelGuide (short EPG)', () {
    final c = all[7];
    db.storeChannelGuide(c, [
      for (var i = 0; i < 4; i++)
        Programme(
          channelId: 'x',
          start: _now.add(Duration(hours: i)),
          stop: _now.add(Duration(hours: i + 1)),
          title: _title(7 % _guideChannels, 24 + i),
        ),
    ]);
  }, runs: 5);
  _time('maintain()', db.maintain);
  _time('recents() after maintain', db.recents, runs: 20);
  _time('groups() after maintain', db.groups, runs: 10);
  _time(
    'searchProgrammes("zzzz") after',
    () => db.searchProgrammes('zzzz', from: _now),
    runs: 5,
  );
  db.close();
  dir.deleteSync(recursive: true);
}
