import 'dart:io';

import 'package:test/test.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline_data/zapline_data.dart';

import 'helpers.dart';

/// Plain `test`: real isolates, each with its own connection to the file.
void main() {
  test('guide search and guide links run on another isolate', () async {
    final dir = await Directory.systemTemp.createTemp('zapline');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/z.db';
    final db = ZaplineDatabase.open(path);
    addTearDown(db.close);
    final state = fakeState(
      count: 5,
      database: db,
      background: isolateDatabaseRunner(path),
    );
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );

    final found = await state.searchProgrammes('Show 3');
    expect(found, isNotEmpty);
    expect(found.every((e) => e.$2.title.startsWith('Show 3')), isTrue);

    // Restoring on another device links guides there off screen too.
    final otherPath = '${dir.path}/other.db';
    final other = ZaplineDatabase.open(otherPath);
    addTearDown(other.close);
    final restored = await fakeState(
      database: other,
      background: isolateDatabaseRunner(otherPath),
    ).restoreBackup(state.exportBackup());
    expect(restored, contains('1 sources restored'));
  });
}
