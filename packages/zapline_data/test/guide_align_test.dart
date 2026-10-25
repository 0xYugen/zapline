import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

void main() {
  late ZaplineDatabase db;
  setUp(() => db = ZaplineDatabase.inMemory());
  tearDown(() => db.close());

  final now = DateTime.utc(2026, 10, 25, 8);
  const shows = [
    'Morning News',
    'Cartoons',
    'Family Guy',
    'The Middle',
    'Big Bang Theory',
    'Will and Grace',
    'Studio Live',
  ];

  /// One guide with [channels], each airing [shows] every 40 minutes from
  /// two hours ago, [off] later than the truth.
  Stream<XmltvItem> guide(List<String> channels, Duration off) async* {
    for (final (i, ch) in channels.indexed) {
      for (final (j, title) in shows.indexed) {
        final start = now
            .subtract(const Duration(hours: 2))
            .add(Duration(minutes: 40 * j + i))
            .add(off);
        yield XmltvProgramme(
          Programme(
            channelId: ch,
            start: start,
            stop: start.add(const Duration(minutes: 40)),
            // Twins share titles: "a1.it" and "a 1.it" both air "… a".
            title: '$title ${ch[0]}',
          ),
        );
      }
    }
  }

  /// What [id] airs every 20 minutes, from two hours ago.
  List<String?> airing(String id) => [
    for (var m = -120; m < 240; m += 20)
      db.airingOn(id, now.add(Duration(minutes: m)))?.title,
  ];

  test('a guide an hour late is moved onto the guide before it', () async {
    final claimed = <String>{};
    await db.importGuide(
      guide(['a1.it', 'b2.it', 'c3.it'], Duration.zero),
      claimed: claimed,
      now: now,
    );
    final before = Set.of(claimed);
    final late = await db.importGuide(
      guide(['a 1.it', 'b 2.it', 'c 3.it', 'd 4.it'], const Duration(hours: 1)),
      claimed: claimed,
      now: now,
    );
    // Three channels have a twin an hour earlier; the fourth follows them.
    expect(db.alignGuide(late.starts, before, now: now), 4);
    expect(airing('a 1.it'), airing('a1.it'));
    expect(airing('c 3.it'), airing('c3.it'));
    // Two hours ago (now 06:00 after the move) the first show was on.
    expect(airing('d 4.it')[1], 'Morning News d');
  });

  test('a guide in step with the one before it stays put', () async {
    final claimed = <String>{};
    await db.importGuide(
      guide(['a1.it', 'b2.it'], Duration.zero),
      claimed: claimed,
      now: now,
    );
    final before = Set.of(claimed);
    final same = await db.importGuide(
      guide(['a 1.it', 'b 2.it'], const Duration(minutes: 5)),
      claimed: claimed,
      now: now,
    );
    expect(db.alignGuide(same.starts, before, now: now), 0);
  });
}
