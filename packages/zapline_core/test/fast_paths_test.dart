import 'dart:math';

import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';

/// The regular expression parseXmltvTime used before it read by hand.
DateTime? _regexTime(String? raw) {
  if (raw == null) return null;
  final m = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{2}:?\d{2})?',
  ).firstMatch(raw.trim());
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i)!);
  final base = DateTime.utc(
    g(1),
    g(2),
    g(3),
    g(4),
    g(5),
    m.group(6) == null ? 0 : g(6),
  );
  final off = m.group(7);
  if (off == null) return base;
  final digits = off.replaceAll(':', '');
  final sign = digits.startsWith('-') ? -1 : 1;
  final minutes = sign *
      (int.parse(digits.substring(1, 3)) * 60 +
          int.parse(digits.substring(3, 5)));
  return base.subtract(Duration(minutes: minutes));
}

const _diacritics = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'î': 'i',
  'ï': 'i', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ù': 'u',
  'ú': 'u', 'û': 'u', 'ü': 'u', 'ñ': 'n', 'ç': 'c', 'ß': 'ss',
};

/// The accent folding normalizeChannelName did before, one string per
/// character.
String _oldFold(String s) => s.split('').map((c) => _diacritics[c] ?? c).join();

void main() {
  group('parseXmltvTime reads what the regular expression read', () {
    final cases = [
      '20261125200000 +0100',
      '20261125200000 -0530',
      '20261125200000+0100',
      '20261125200000 +01:00',
      '202611252000 +0100',
      '20261125200000',
      '202611252000',
      '  20261125200000 +0000  ',
      '20261125200000\t+0200',
      '20261125200000   +0200',
      '20261125200000 +010',
      '20261125200000 +01:0',
      '20261125200000 +01:',
      '20261125200000 0100',
      '20261125200000 +0100 extra',
      '20261125200000Z',
      '2026112520000 +0100',
      '2026112520',
      '',
      'not a time',
      '2026-11-25 20:00',
      '20261332250000 +0100',
      '20261125200000 +9999',
      '20261125200000 ++0100',
      '٢٠٢٦١١٢٥٢٠٠٠٠٠',
    ];
    for (final c in cases) {
      test('"$c"', () => expect(parseXmltvTime(c), _regexTime(c)));
    }

    test('random inputs', () {
      final r = Random(7);
      const alphabet = '0123456789 +-:\tZ';
      for (var n = 0; n < 20000; n++) {
        final b = StringBuffer('2026')
          ..write(r.nextInt(100).toString().padLeft(2, '0'));
        final len = r.nextInt(16);
        for (var i = 0; i < len; i++) {
          b.write(alphabet[r.nextInt(alphabet.length)]);
        }
        final s = b.toString();
        expect(parseXmltvTime(s), _regexTime(s), reason: s);
      }
    });
  });

  group('the parser skips programmes outside the window', () {
    final now = DateTime.utc(2026, 11, 25, 20);
    String prog(String start, String? stop, {String channel = 'a'}) =>
        '<programme start="$start"${stop == null ? '' : ' stop="$stop"'} '
        'channel="$channel"><title>T $start</title><desc>D</desc>'
        '<icon src="http://i.example/x.png"/></programme>';

    test('as it did when it filtered built programmes', () async {
      final xml = '<tv><channel id="a"><display-name>A</display-name></channel>'
          '${prog('20261125150000 +0000', '20261125160000 +0000')}'
          // Ends exactly at the window's start: out.
          '${prog('20261125170000 +0000', '20261125180000 +0000')}'
          '${prog('20261125175900 +0000', '20261125180100 +0000')}'
          // No stop: an hour, so 17:30 reaches 18:30.
          '${prog('20261125173000 +0000', null)}'
          '${prog('20261125165000 +0000', null)}'
          '${prog('20261125220000 +0000', '20261125230000 +0000')}'
          // Starts exactly at the window's end: in.
          '${prog('20261126000000 +0000', '20261126010000 +0000')}'
          '${prog('20261126000100 +0000', '20261126010000 +0000')}'
          '<programme start="20261125210000 +0000"><title>No channel'
          '</title></programme>'
          '</tv>';
      final items = await XmltvParser(
        from: now.subtract(const Duration(hours: 2)),
        to: now.add(const Duration(hours: 4)),
      ).parse(Stream.value(xml)).toList();
      final titles = [
        for (final i in items)
          if (i is XmltvProgramme) i.programme.title,
      ];
      expect(titles, [
        'T 20261125175900 +0000',
        'T 20261125173000 +0000',
        'T 20261125220000 +0000',
        'T 20261126000000 +0000',
      ]);
      final p = (items[1] as XmltvProgramme).programme;
      expect(p.description, 'D');
      expect(p.iconUrl, Uri.parse('http://i.example/x.png'));
      final channel = items.first as XmltvChannel;
      expect(channel.displayNames, ['A']);
      expect(channel.iconUrl, isNull, reason: 'programme icons stay theirs');
    });
  });

  group('channel name keys', () {
    test('accents fold as before', () {
      for (final s in [
        'rai uno',
        'canale 5 hd',
        'tv5monde',
        'télé-québec',
        'ßport straße',
        'çà et là',
        'ñandú',
        'emoji 📺 tv',
        'ÀÉÎ'.toLowerCase(),
        'ṁixed ẞ',
        '',
      ]) {
        expect(normalizeChannelName(s), _oldNormalize(s), reason: s);
      }
    });

    test('ranking scores as before', () {
      final guide = [
        const XmltvChannel(id: 'Rai1.it', displayNames: ['Rai 1', 'Rai Uno']),
        const XmltvChannel(id: 'Rai2.it', displayNames: ['Rai 2']),
        const XmltvChannel(id: 'Cine1.it', displayNames: ['Cinema One']),
        const XmltvChannel(id: 'Sky.it', displayNames: ['Sky Sport Uno']),
        const XmltvChannel(id: 'Tele.fr', displayNames: ['Télé Québec']),
      ];
      final index = GuideIndex(guide);
      for (final name in [
        'Rai 1 HD',
        'IT: Rai Uno',
        'Cinema 1',
        'Sport Uno',
        'Tele Quebec',
        'Nothing alike',
        'Sky',
      ]) {
        final got = [
          for (final (c, s) in index.rank(name))
            '${c.id} ${s.toStringAsFixed(6)}',
        ];
        final want = [
          for (final (c, s) in _oldRank(name, guide))
            '${c.id} ${s.toStringAsFixed(6)}',
        ];
        expect(got, want, reason: name);
      }
    });
  });
}

// The previous implementations, for comparison.

final _prefix = RegExp(
  r'^\s*(?:\[[^\]]{1,12}\]|\([^)]{1,12}\)|\|[a-z]{2,3}\||'
  r'[a-z]{2,3}\s*[:|]+|[a-z]{2}\s+-\s+)\s*',
  caseSensitive: false,
);
final _quality = RegExp(
  r'\b(?:uhd|fhd|hd|sd|hq|4k|8k|1080p?|720p?|h\.?265|h\.?264|hevc|backup|bk|vip|raw)\b',
  caseSensitive: false,
);

String _oldNormalize(String name) => _oldFold(
      name.toLowerCase(),
    ).replaceFirst(_prefix, '').replaceAll(_quality, ' ').replaceAll(
          RegExp(r'[^a-z0-9+]+'),
          '',
        );

Set<String> _oldWords(String s) => _oldFold(s.toLowerCase())
    .replaceFirst(_prefix, '')
    .replaceAll(_quality, ' ')
    .split(RegExp(r'[^a-z0-9+]+'))
    .where((w) => w.isNotEmpty)
    .toSet();

List<(XmltvChannel, double)> _oldRank(
  String channelName,
  List<XmltvChannel> guide,
) {
  final target = _oldNormalize(channelName);
  final targetWords = _oldWords(channelName);
  final scored = <(XmltvChannel, double)>[];
  for (final gc in guide) {
    var best = 0.0;
    for (final name in [...gc.displayNames, gc.id.split('.').first]) {
      final n = _oldNormalize(name);
      final words = _oldWords(name);
      if (n.isEmpty) continue;
      double s;
      if (n == target) {
        s = 1.0;
      } else if (target.isNotEmpty &&
          (n.contains(target) || target.contains(n))) {
        s = 0.8 *
                (n.length < target.length
                    ? n.length / target.length
                    : target.length / n.length) +
            0.1;
      } else {
        final shared = words.intersection(targetWords).length;
        final prefix = words.any(
          (w) => targetWords.any(
            (t) =>
                w.length >= 3 &&
                t.length >= 3 &&
                (w.startsWith(t) || t.startsWith(w)),
          ),
        )
            ? 0.5
            : 0.0;
        final union = words.union(targetWords).length;
        s = union == 0 ? 0 : 0.6 * shared / union;
        if (shared == 0) s = prefix * 0.6;
      }
      if (s > best) best = s;
    }
    if (best > 0.15) scored.add((gc, best));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return scored.take(8).toList();
}
