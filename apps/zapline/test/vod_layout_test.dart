import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/playback/playback_engine.dart';

import '../tool/screenshots/shots.dart' show FakeEngine;
import 'helpers.dart';

/// Films and series on a phone: tabs, rows, grids, detail pages and the
/// player lay out without errors, and positions feed "Continue watching".
void main() {
  setUp(() => debugEngineFactory = FakeEngine.new);
  tearDown(() => debugEngineFactory = null);

  for (final (name, size) in [
    ('portrait', const Size(412, 915)),
    ('landscape', const Size(915, 412)),
  ]) {
    testWidgets('phone $name: films and series', (tester) async {
      tester.view
        ..physicalSize = size * 2.625
        ..devicePixelRatio = 2.625
        ..padding = const FakeViewPadding(top: 63, bottom: 126);
      addTearDown(tester.view.reset);

      final state = fakeState(count: 10, vod: true);
      await state.addSource(
        const SourceInput(
          url: 'http://x.example/get.php?username=a&password=b',
        ),
      );
      await tester.pumpWidget(ZaplineApp(state: state));
      await tester.pumpAndSettle();

      Future<void> back() async {
        tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
        await tester.pumpAndSettle();
      }

      // Five tabs: favourites move into the TV tab.
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Favourites'), findsNothing);

      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      expect(find.text('Recently added'), findsWidgets);
      expect(find.text('Film 36'), findsWidgets);

      // A category as a grid.
      await tester.tap(find.text('IT | Commedia').first);
      await tester.pumpAndSettle();
      expect(find.text('Film 4'), findsWidgets);
      expect(find.text('Film 3'), findsNothing);

      // Film page, then play and leave half-way.
      await tester.tap(find.text('Film 4').first);
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);
      await tester.ensureVisible(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byTooltip('Back 10 seconds'), findsOneWidget);
      await back();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('Resume'), findsOneWidget);
      await back();

      await tester.tap(find.text('All').first);
      await tester.pumpAndSettle();
      expect(find.text('Continue watching'), findsWidgets);

      // Series page with seasons and episodes.
      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Serie 2').first);
      await tester.pumpAndSettle();
      expect(find.text('Play S1·E1'), findsOneWidget);
      // My list from the detail page shows on the tab.
      await tester.ensureVisible(find.text('My list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My list'));
      await tester.pumpAndSettle();
      expect(find.text('In my list'), findsOneWidget);
      final page = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Season 2'),
        200,
        scrollable: page,
      );
      await tester.tap(find.text('Season 2'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('1. Episode title 1'),
        200,
        scrollable: page,
      );
      await back();
      expect(state.myShows().single.name, 'Serie 2');
    });
  }
}
