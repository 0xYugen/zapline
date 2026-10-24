import 'package:zapline_core/zapline_core.dart';
import 'package:test/test.dart';

void main() {
  const groups = [
    'IT | Sport',
    'IT: News',
    'Italia Cinema',
    'ITALY 4K',
    'Hits Music',
    'British TV',
    'UK | Sport',
    'XXX Adult',
    '[IT] Kids',
    'VOD Italia',
  ];

  List<String> visible(GroupFilter f) => [
        for (final g in groups)
          if (!f.hides(g)) g
      ];

  test('whole-word terms do not match inside other words', () {
    expect(visible(const GroupFilter(include: ['it'])),
        ['IT | Sport', 'IT: News', '[IT] Kids']);
  });

  test('prefix terms and literal terms', () {
    expect(visible(const GroupFilter(include: ['ital*'])),
        ['Italia Cinema', 'ITALY 4K', 'VOD Italia']);
    expect(visible(const GroupFilter(include: ['IT|'])), ['IT | Sport']);
  });

  test('exclusions win over inclusions', () {
    expect(
      visible(
          const GroupFilter(include: ['it', 'ital*'], exclude: ['xxx', 'vod'])),
      ['IT | Sport', 'IT: News', 'Italia Cinema', 'ITALY 4K', '[IT] Kids'],
    );
    expect(visible(const GroupFilter(exclude: ['adult'])),
        hasLength(groups.length - 1));
  });

  test('empty filter hides nothing; ungrouped channels follow includes', () {
    expect(visible(GroupFilter.none), groups);
    expect(GroupFilter.none.hides(null), isFalse);
    expect(const GroupFilter(include: ['it']).hides(null), isTrue);
  });

  test('parsing and JSON round trip', () {
    final terms = GroupFilter.parseTerms(' IT, ital* ,\n XXX ,, ');
    expect(terms, ['IT', 'ital*', 'XXX']);
    final f = GroupFilter(include: terms, exclude: const ['vod']);
    expect(GroupFilter.fromJson(f.toJson()), f);
    expect(GroupFilter.fromJson(null), GroupFilter.none);
  });

  test('Programme.shifted moves both ends', () {
    final p = Programme(
        channelId: 'c',
        start: DateTime.utc(2026, 1, 1, 10),
        stop: DateTime.utc(2026, 1, 1, 11),
        title: 't');
    final s = p.shifted(const Duration(hours: -1));
    expect(s.start, DateTime.utc(2026, 1, 1, 9));
    expect(s.stop, DateTime.utc(2026, 1, 1, 10));
  });
}
