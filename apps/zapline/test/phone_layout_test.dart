import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/playback/playback_engine.dart';

import '../tool/screenshots/shots.dart' show FakeEngine;
import 'helpers.dart';

/// Walks every phone screen, upright and sideways, with system bars, and
/// fails on any layout error (overflow, unbounded sizes).
void main() {
  setUp(() => debugEngineFactory = FakeEngine.new);
  tearDown(() => debugEngineFactory = null);

  for (final (name, size) in [
    ('portrait', const Size(412, 915)),
    ('landscape', const Size(915, 412)),
  ]) {
    testWidgets('phone $name: every screen lays out', (tester) async {
      tester.view
        ..physicalSize = size * 2.625
        ..devicePixelRatio = 2.625
        ..padding = const FakeViewPadding(top: 63, bottom: 126);
      addTearDown(tester.view.reset);

      final state = fakeState(count: 30);
      await tester.pumpWidget(ZaplineApp(state: state));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'http://x.example/get.php?username=a&password=b',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Connect'));
      await tester.tap(find.text('Connect'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      // Phone shell, not the TV rail with groups.
      expect(find.text('All channels'), findsOneWidget);
      expect(
        find.byType(size.width > size.height ? NavigationRail : NavigationBar),
        findsOneWidget,
      );

      Future<void> back() async {
        tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
        await tester.pumpAndSettle();
      }

      // Channel menu as a bottom sheet.
      await tester.longPress(find.text('Channel 2'));
      await tester.pumpAndSettle();
      expect(find.text('Hide this channel'), findsOneWidget);
      await back();

      // Player with touch controls and the channel list.
      await tester.tap(find.text('Channel 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Next channel'), findsOneWidget);
      await tester.tap(find.byTooltip('Channels'));
      await tester.pump();
      expect(find.text('Channel 4'), findsWidgets);
      await back();
      await back();
      await tester.pumpAndSettle();

      // Search opens from the header as a page.
      await tester.tap(find.byTooltip('Search channels and programmes').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Show 2');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In the TV guide'));
      await tester.pumpAndSettle();
      await back();

      for (final tab in ['Guide', 'Favourites', 'Settings']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(state.sources.single.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groups and filters'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
      await tester.pumpAndSettle();
      await back();
      await back();

      await tester.tap(find.text('Guide').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Channel 3').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Channel 3').first);
      await tester.pumpAndSettle();
      expect(find.text('ON NOW'), findsOneWidget);

      // A programme opens its sheet; an upcoming one can be reminded.
      // The next programme may already fall on tomorrow's page.
      if (find.text('Show 3.1').evaluate().isEmpty) {
        await tester.tap(find.text('Tomorrow'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Show 3.1'));
      await tester.pumpAndSettle();
      expect(find.text('Remind me'), findsOneWidget);
      await tester.tap(find.text('Remind me'));
      await tester.pumpAndSettle();
      expect(find.text('Reminder set'), findsOneWidget);
    });
  }
}
