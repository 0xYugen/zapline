import 'package:test/test.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/db_write.dart';
import 'package:zapline_data/zapline_data.dart';

import 'helpers.dart';

/// Work that must never hold up what's on screen: small writes while a
/// sync holds the database, settings read in loops, refreshes while a
/// channel plays.
void main() {
  test('a write refused while the database is busy is done later', () async {
    var tries = 0;
    writeSoon(() {
      tries++;
      if (tries < 3) throw Exception('SqliteException(5): database is locked');
    });
    expect(tries, 1);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(tries, 3);
  });

  test('other write errors are not tried again', () async {
    var tries = 0;
    writeSoon(() {
      tries++;
      throw Exception('no such table');
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(tries, 1);
  });

  test('settings are read once, written through, read again on reload', () {
    final db = ZaplineDatabase.inMemory();
    final state = fakeState(database: db);
    final s = state.settings;
    expect(s.sequentialNumbers, isFalse);
    s.sequentialNumbers = true;
    expect(s.sequentialNumbers, isTrue);
    expect(db.setting('sequentialNumbers'), 'true');
    // Written past it (a restore): seen after a reload only.
    db.setSetting('sequentialNumbers', 'false');
    expect(s.sequentialNumbers, isTrue);
    s.reload();
    expect(s.sequentialNumbers, isFalse);
  });

  test('no refresh of a source with data while a channel plays', () async {
    final state = fakeState(count: 3);
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    var syncs = 0;
    state.syncProgress.addListener(() {
      if (state.syncProgress.value != null) syncs++;
    });
    state.nowPlaying = (title: 'Channel 1', subtitle: null);
    state.startAutoRefresh(all: true);
    await state.maybeRefresh();
    expect(syncs, 0);

    // Nobody watching: it refreshes.
    state.nowPlaying = null;
    await state.maybeRefresh();
    expect(syncs, 1);
    state.dispose();
  });
}
