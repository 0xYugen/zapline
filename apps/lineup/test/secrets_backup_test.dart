import 'package:flutter_test/flutter_test.dart';
import 'package:lineup/src/app_state.dart';
import 'package:lineup/src/secret_store.dart';
import 'package:lineup_data/lineup_data.dart';

import 'helpers.dart';

const _xtream = SourceInput(
  url: 'http://panel.example:8080',
  username: 'alice',
  password: 's3cret',
);

void main() {
  test('passwords go to the keystore, never the database', () async {
    final secrets = MemorySecretStore();
    final db = LineupDatabase.inMemory();
    final state = fakeState(count: 3, database: db, secrets: secrets);
    await state.addSource(_xtream);

    expect(db.sources().single.password, isEmpty);
    expect(secrets.values.values, ['s3cret']);
    expect(state.sources.single.password, 's3cret');

    state.deleteSource(state.sources.single.id);
    await Future<void>.delayed(Duration.zero);
    expect(secrets.values, isEmpty);
  });

  test('passwords left in the database by older versions are moved', () async {
    final db = LineupDatabase.inMemory()
      ..saveSource(
        const SourceRecord(
          id: 'old',
          kind: SourceKind.xtream,
          name: 'Old',
          url: 'http://p.example',
          username: 'u',
          password: 'legacy',
        ),
      );
    final secrets = MemorySecretStore();
    final state = fakeState(database: db, secrets: secrets);
    await state.loadSecrets();
    expect(db.sources().single.password, isEmpty);
    expect(secrets.values.values.single, 'legacy');
    expect(state.sources.single.password, 'legacy');
  });

  test('backup and restore on a new device', () async {
    final a = fakeState(count: 5, unmatched: {4});
    await a.addSource(_xtream);
    final channels = a.channels();
    a.toggleFavourite(channels[2]);
    a.assignGuide(channels[3], 'g1');
    final json = a.exportBackup();
    expect(json, contains('s3cret'));

    final b = fakeState(count: 5, unmatched: {4});
    final summary = await b.restoreBackup(json);
    expect(summary, startsWith('1 sources restored'));
    expect(b.sources.single.password, 's3cret');
    expect(b.favourites().single.name, 'Channel 3');
    expect(
      b.unmatchedChannels(b.sources.single.id),
      isEmpty,
      reason: 'manual guide link restored',
    );

    // Restoring again changes nothing.
    expect(await b.restoreBackup(json), contains('1 already present'));
    expect(b.sources, hasLength(1));
  });
}
