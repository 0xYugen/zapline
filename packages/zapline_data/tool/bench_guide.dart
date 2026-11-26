// A big free guide imported for a playlist that uses a tenth of its
// channels: everything kept, then only the wanted channels' programmes
// (plus what airs around now on the others). Run with
// `dart run tool/bench_guide.dart [dir]`.
//
// The guide is XMLTV text, parsed as in a sync: 3,000 channels of 200
// one-hour programmes (600k programmes, about 140 MB of XML).
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

const _guideChannels = 3000;
const _perChannel = 200;
const _wanted = _guideChannels ~/ 10;

final _now = DateTime.utc(2026, 11, 25, 20);
final _start = _now.subtract(const Duration(days: 1));

String _ts(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}'
      '00 +0000';
}

Stream<List<int>> _xml() async* {
  final b = StringBuffer('<?xml version="1.0"?>\n<tv>\n');
  for (var c = 0; c < _guideChannels; c++) {
    b.write(
      '<channel id="g$c.it"><display-name>Guide $c</display-name>'
      '<icon src="http://logo.example/$c.png"/></channel>\n',
    );
  }
  yield utf8.encode(b.toString());
  for (var c = 0; c < _guideChannels; c++) {
    b.clear();
    for (var i = 0; i < _perChannel; i++) {
      final s = _start.add(Duration(hours: i));
      b.write(
        '<programme start="${_ts(s)}" '
        'stop="${_ts(s.add(const Duration(hours: 1)))}" channel="g$c.it">'
        '<title lang="it">Programma $c $i</title>'
        '<desc lang="it">Una descrizione abbastanza lunga del programma $i, '
        'con un po\' di trama e qualche nome di attore.</desc>'
        '<category lang="it">Varie</category></programme>\n',
      );
    }
    yield utf8.encode(b.toString());
  }
  yield utf8.encode('</tv>\n');
}

Future<void> _run(String label, Directory dir, {required bool filter}) async {
  final path = '${dir.path}/$label.db';
  final db = ZaplineDatabase.open(path);
  db.saveSource(
    const SourceRecord(
      id: 'src',
      kind: SourceKind.m3u,
      name: 'Bench',
      url: 'http://panel.example',
    ),
  );
  db.replaceChannels('src', [
    for (var i = 0; i < 2000; i++)
      Channel(
        sourceId: 'src',
        id: '$i',
        name: 'Channel $i',
        streamUrl: Uri.parse('http://panel.example/$i.ts'),
        epgChannelId: i < _wanted ? 'g$i.it' : null,
      ),
  ]);
  final wants = db.guideWants();
  final sw = Stopwatch()..start();
  final r = await db.importGuide(
    XmltvParser(
      from: _now.subtract(const Duration(days: 1)),
      to: _now.add(const Duration(days: 7)),
      wanted: filter ? wants.call : null,
      around: _now,
    ).parseBytes(_xml()),
    now: _now,
  );
  final ms = sw.elapsedMilliseconds;
  db.maintain();
  db.close();
  final size = File(path).lengthSync() / (1 << 20);
  print(
    '${label.padRight(14)} ${ms.toString().padLeft(6)} ms  '
    '${r.programmes.toString().padLeft(7)} programmes  '
    '${size.toStringAsFixed(1).padLeft(6)} MB  (${r.channels} channels)',
  );
}

Future<void> main(List<String> args) async {
  final dir = Directory(
    args.isEmpty ? Directory.systemTemp.path : args.first,
  ).createTempSync('zapline_bench_guide');
  await _run('everything', dir, filter: false);
  await _run('10% wanted', dir, filter: true);
  dir.deleteSync(recursive: true);
}
