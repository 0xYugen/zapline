import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/screens/filters_screen.dart' show italianTerms;
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import 'helpers.dart';

void main() {
  Future<AppState> device() async {
    final s = fakeState(
      count: 6,
      names: ['Rai 1 HD', 'Rai 1 4K', 'Rai 2', 'BBC One', 'ITV', 'La7'],
      groups: [
        'IT | Rai',
        'IT | Rai',
        'IT | Rai',
        'UK | TV',
        'UK | TV',
        'IT | Altri',
      ],
      vod: true,
    );
    await s.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    return s;
  }

  test('everything set on the phone arrives on the TV', () async {
    final phone = await device();
    final src = phone.sources.single;
    phone.setFilter(
      src,
      ContentKind.tv,
      const GroupFilter(include: italianTerms),
    );
    final rai1 = phone.channels().first;
    phone.toggleFavourite(rai1);
    phone.setChannelHidden(phone.channels().last, true);
    phone.preferVersion(phone.versionsOf(rai1).last);
    phone.settings.setLanguage('it');
    phone.settings.keepScreenOn = false;
    final film = phone.movies().first;
    phone.toggleMyList('movie:${src.id}/${film.id}');
    phone.savePosition(
      'movie:${src.id}/${film.id}',
      const Duration(minutes: 30),
      const Duration(minutes: 100),
    );

    final json = phone.exportBackup();

    final tv = fakeState(count: 6, vod: true);
    final summary = await tv.restoreBackup(json);
    expect(summary, contains('1 sources restored'));
    // Filters and settings are in place before the channels arrive.
    expect(tv.sources.single.groupFilter.include, italianTerms);
    expect(tv.settings.language.value, 'it');
    await tv.restoreDownloads;
    final id = tv.sources.single.id;
    expect(id, isNot(src.id));
    expect(tv.sources.single.groupFilter.include, italianTerms);
    expect(tv.favourites(), hasLength(1));
    expect(tv.hiddenChannels(id), hasLength(1));
    expect(tv.settings.language.value, 'it');
    expect(tv.settings.keepScreenOn, isFalse);
    expect(tv.myMovies().single.id, film.id);
    expect(tv.positionOf('movie:$id/${film.id}')?.position.inMinutes, 30);
    expect(tv.settings.versionChoices.values.single, startsWith('$id/'));
  });

  test('only the chosen parts travel', () async {
    final phone = await device();
    phone.toggleFavourite(phone.channels().first);
    phone.settings.setLanguage('it');
    final json = phone.exportBackup(parts: {BackupPart.filters});
    final tv = fakeState(count: 6);
    await tv.restoreBackup(json);
    expect(tv.sources, hasLength(1));
    expect(tv.favourites(), isEmpty);
    expect(tv.settings.language.value, isNull);
  });

  test('a source that cannot be downloaded keeps what was restored', () async {
    final phone = await device();
    final src = phone.sources.single;
    phone.setFilter(
      src,
      ContentKind.tv,
      const GroupFilter(include: italianTerms),
    );
    phone.settings.setLanguage('it');
    final json = phone.exportBackup();

    // A TV whose downloads fail (a slow stick, the server busy).
    final tv = AppState(
      ZaplineDatabase.inMemory(),
      syncRunner: (source, onProgress) async => throw Exception('offline'),
    );
    expect(await tv.restoreBackup(json), contains('1 sources restored'));
    await tv.restoreDownloads;
    expect(tv.sources, hasLength(1));
    expect(tv.sources.single.groupFilter.include, italianTerms);
    expect(tv.settings.language.value, 'it');
  });
}
