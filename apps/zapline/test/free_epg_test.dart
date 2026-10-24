import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/free_epg.dart';
import 'package:zapline/src/screens/source_detail_screen.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import 'helpers.dart';

AppState _withChannels(List<(String, String?)> channels) {
  final db = ZaplineDatabase.inMemory();
  const source = SourceRecord(
    id: 's',
    kind: SourceKind.xtream,
    name: 'S',
    url: 'http://x.example',
  );
  db
    ..saveSource(source)
    ..replaceChannels('s', [
      for (final (i, (name, group)) in channels.indexed)
        Channel(
          sourceId: 's',
          id: '$i',
          name: name,
          groupTitle: group,
          streamUrl: Uri.parse('http://x.example/$i.ts'),
        ),
    ]);
  return AppState(db, syncRunner: (_, _) async => throw UnimplementedError());
}

void main() {
  test('the catalogue has Italy with two guides', () {
    final it = FreeEpg.countries.singleWhere((c) => c.code == 'it');
    expect(it.urls, hasLength(4));
    expect(FreeEpg.ofUrl(it.urls.last), it);
    expect(FreeEpg.forLocale(const Locale('it', 'IT')), it);
    expect(FreeEpg.forLocale(const Locale('it')), it);
    expect(FreeEpg.forLocale(const Locale('en', 'GB'))!.code, 'gb');
  });

  test('sources with an older free EPG get the newer guides', () {
    final db = ZaplineDatabase.inMemory()
      ..saveSource(
        const SourceRecord(
          id: 's',
          kind: SourceKind.m3u,
          name: 'S',
          url: 'http://x.example/list.m3u',
          extraGuideUrls: [
            'https://my.example/guide.xml',
            'https://iptv-epg.org/files/epg-it.xml.gz',
          ],
        ),
      );
    final state = AppState(
      db,
      syncRunner: (_, _) async => throw UnimplementedError(),
    );
    final urls = state.sources.single.extraGuideUrls;
    expect(urls.first, 'https://my.example/guide.xml');
    expect(
      urls,
      containsAll(FreeEpg.countries.singleWhere((c) => c.code == 'it').urls),
    );
  });

  test('the source tells which country its channels are from', () {
    expect(
      _withChannels([
        ('IT: Rai 1 HD', null),
        ('IT | Canale 5', null),
        ('Rai 3', 'ITALIA'),
        ('Sky Uno', 'ITA | Intrattenimento'),
        ('UK: BBC One', null),
      ]).likelyFreeEpg('s')!.code,
      'it',
    );
    // Names that merely start with letters are not country tags.
    expect(
      _withChannels([
        ('Rai 1', 'Generalisti'),
        ('Sky Uno', 'Intrattenimento'),
        ('La7', null),
      ]).likelyFreeEpg('s'),
      isNull,
    );
  });

  testWidgets('a source with little EPG offers a free one in one tap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    final state = fakeState(count: 10, unmatched: {1, 2, 3, 4, 5, 6});
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    await tester.pumpWidget(ZaplineApp(state: state));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SourceDetailScreen(state: state, sourceId: state.sources.single.id),
      ),
    );
    await tester.pumpAndSettle();

    // Test devices are en_US and the channels carry no country tag.
    final button = find.text('Add the free EPG for United States');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(
      state.sources.single.extraGuideUrls,
      contains('https://iptv-epg.org/files/epg-us.xml.gz'),
    );
    expect(find.textContaining('United States EPG added'), findsOneWidget);
    expect(button, findsNothing);
  });
}
