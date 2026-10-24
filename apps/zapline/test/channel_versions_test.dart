import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/app_state.dart';

import 'helpers.dart';

void main() {
  Future<AppState> state() async {
    final s = fakeState(
      count: 6,
      names: ['Rai 1 HD', 'Rai 1 FHD', 'Rai 1 4K', 'Rai 2', 'Rai 2 HD', 'La7'],
    );
    await s.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    return s;
  }

  test('versions fold into one channel, best picture first', () async {
    final s = await state();
    final list = s.channels();
    expect(list.map((c) => c.name), ['Rai 1 4K', 'Rai 2', 'La7']);
    expect(s.displayName(list.first), 'Rai 1');
    expect(s.versionsOf(list.first).map((c) => c.name), [
      'Rai 1 4K',
      'Rai 1 FHD',
      'Rai 1 HD',
    ]);
    expect(s.displayName(list.last), 'La7');
    expect(s.indexOfChannel(list, s.versionsOf(list.first)[2]), 0);
  });

  test('saving data plays HD; a picked version sticks', () async {
    final s = await state();
    s.settings.saveData = true;
    s.settingsChanged();
    expect(s.channels().first.name, 'Rai 1 HD');
    final fhd = s.versionsOf(s.channels().first)[1];
    expect(fhd.name, 'Rai 1 FHD');
    s.preferVersion(fhd);
    expect(s.channels().first.name, 'Rai 1 FHD');
  });

  test('merging can be turned off', () async {
    final s = await state();
    s.settings.mergeVersions = false;
    s.settingsChanged();
    expect(s.channels(), hasLength(6));
  });
}
