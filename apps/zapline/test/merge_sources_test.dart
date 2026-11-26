import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline_data/zapline_data.dart';

import 'helpers.dart';

/// The same channel from two sources is one entry, and the other source
/// is its next version: the player falls back to it when one fails.
void main() {
  test('two sources: one entry per channel, versions across sources', () async {
    final state = fakeState(count: 6);
    await state.addSource(
      const SourceInput(url: 'http://a.example/get.php?username=a&password=b'),
    );
    await state.addSource(
      const SourceInput(url: 'http://b.example/get.php?username=a&password=b'),
    );
    expect(state.sources, hasLength(2));

    final list = state.channels();
    expect(list, hasLength(6));
    final versions = state.versionsOf(list.first);
    expect(versions, hasLength(2));
    expect({for (final v in versions) v.sourceId}, hasLength(2));
    // Found in the list from either source.
    expect(state.indexOfChannel(list, versions.last), 0);

    // A choice by hand sticks.
    state.preferVersion(versions.last);
    expect(
      ZaplineDatabase.channelKey(state.channels().first),
      ZaplineDatabase.channelKey(versions.last),
    );

    // Off: each source's channels on their own.
    state.settings.mergeSources = false;
    state.settingsChanged();
    expect(state.channels(), hasLength(12));
  });

  test('channels sharing a guide but named apart stay apart', () async {
    final state = fakeState(count: 2, names: ['Rai 3', 'Rai 3 TGR Lazio']);
    await state.addSource(
      const SourceInput(url: 'http://a.example/get.php?username=a&password=b'),
    );
    await state.addSource(
      const SourceInput(url: 'http://b.example/get.php?username=a&password=b'),
    );
    // The regional channel shares Rai 3's guide in both sources.
    for (final c in state.db.channels()) {
      if (c.name.contains('TGR')) state.assignGuide(c, 'g1');
    }
    // Rai 3 merges with Rai 3, the regional one with itself only.
    final list = state.channels();
    expect([for (final c in list) c.name], ['Rai 3', 'Rai 3 TGR Lazio']);
    expect(state.versionsOf(list.first), hasLength(2));
    expect(state.versionsOf(list.last), hasLength(2));
  });

  test('a large list loaded off screen merges across sources too', () async {
    final db = ZaplineDatabase.inMemory();
    final state = fakeState(
      count: 1100,
      database: db,
      background: <R>(job) async => job(db),
    );
    await state.addSource(
      const SourceInput(url: 'http://a.example/get.php?username=a&password=b'),
    );
    await state.addSource(
      const SourceInput(url: 'http://b.example/get.php?username=a&password=b'),
    );
    // 2,200 channels: above the size that loads off screen.
    expect(state.channelCount, greaterThan(2000));
    expect(state.channelsReady(null), isNull);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final list = state.channelsReady(null)!;
    expect(list.length, lessThan(1200));
    expect(state.versionsOf(list.first), hasLength(2));
  });
}
