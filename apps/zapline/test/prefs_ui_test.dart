import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/screens/manage_source_screen.dart';
import 'package:zapline/src/screens/settings_screen.dart';
import 'package:zapline_core/zapline_core.dart';

import 'helpers.dart';

Future<void> _connect(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextField).first,
    'http://x.example/get.php?username=a&password=b',
  );
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
}

Future<void> _push(WidgetTester tester, Widget screen) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.push(MaterialPageRoute<void>(builder: (_) => screen));
  await tester.pumpAndSettle();
}

Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
  // The dialog closes itself shortly after the fourth digit.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {});

  testWidgets('group filter keeps only matching groups', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    final state = fakeState();
    await tester.pumpWidget(ZaplineApp(state: state));
    await _connect(tester);
    final source = state.sources.single;

    expect(
      state.previewFilter(source.id, const GroupFilter(include: ['even'])),
      (1, 2, 10),
    );
    await _push(tester, ManageSourceScreen(state: state, sourceId: source.id));
    expect(find.textContaining('Shows 2 of 2 groups'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), 'even');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Shows 1 of 2 groups · 10 channels'),
      findsOneWidget,
    );
    await tester.tap(find.text('Apply filter'));
    await tester.pumpAndSettle();

    expect(state.groups, ['Even']);
    expect(state.channels().length, 10);
    expect(state.sources.single.groupFilter.include, ['even']);

    // A group chosen by hand wins over the filter.
    state.setGroupHidden(state.sources.single, 'Odd', false);
    expect(state.groups, containsAll(['Even', 'Odd']));
  });

  testWidgets('hidden channels disappear and come back from Manage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    final state = fakeState();
    await tester.pumpWidget(ZaplineApp(state: state));
    await _connect(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide this channel'));
    await tester.pumpAndSettle();
    expect(find.text('Channel 1'), findsNothing);
    expect(state.channels().length, 19);

    final id = state.sources.single.id;
    expect(state.hiddenChannels(id).single.name, 'Channel 1');
    await _push(tester, ManageSourceScreen(state: state, sourceId: id));
    await tester.scrollUntilVisible(
      find.text('Show again'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ManageSourceScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Show again'));
    await tester.pumpAndSettle();
    expect(state.channels().length, 20);
  });

  testWidgets('locked groups need the PIN', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    final state = fakeState();
    await tester.pumpWidget(ZaplineApp(state: state));
    await _connect(tester);

    state.setPin('1234');
    state.setGroupLocked(state.sources.single, 'Odd', true);
    await tester.pumpAndSettle();
    expect(state.channels().length, 10);
    expect(
      state.search('Channel 1').map((c) => c.name),
      isNot(contains('Channel 1')),
    );
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

    await tester.tap(find.text('Odd'));
    await tester.pumpAndSettle();
    expect(find.text('This group is locked'), findsOneWidget);
    expect(find.text('Enter the PIN'), findsOneWidget);
    await _typePin(tester, '9999');
    expect(find.text('Wrong PIN'), findsOneWidget);
    expect(state.unlocked, isFalse);

    await tester.tap(find.text('Odd'));
    await tester.pumpAndSettle();
    await _typePin(tester, '1234');
    expect(state.unlocked, isTrue);
    expect(state.channels().length, 20);
    expect(find.text('This group is locked'), findsNothing);

    // Removing the PIN unlocks everything for good.
    state.setPin(null);
    state.lock();
    expect(state.channels().length, 20);
  });

  testWidgets('settings: sequential numbers and 12-hour clock', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    final state = fakeState();
    await tester.pumpWidget(ZaplineApp(state: state));
    await _connect(tester);
    state.setGroupHidden(state.sources.single, 'Odd', true);
    await tester.pumpAndSettle();
    // Provider numbers: the first visible channel is number 2.
    final first = state.channels().first;
    expect(state.channelNumber(first, 0), 2);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(state.settings.sequentialNumbers, isTrue);
    expect(state.channelNumber(first, 0), 1);

    await tester.tap(find.text('24-hour clock'));
    await tester.pumpAndSettle();
    expect(state.settings.clock24h, isFalse);
    expect(state.time(DateTime(2026, 1, 1, 15, 5)), '3:05 PM');

    await tester.tap(find.text('Zoom'));
    await tester.pumpAndSettle();
    expect(state.settings.videoFit, BoxFit.cover);
  });

  testWidgets('search finds programmes in the guide', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    final state = fakeState();
    await tester.pumpWidget(ZaplineApp(state: state));
    await _connect(tester);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Show 3.0');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('In the TV guide'), findsOneWidget);
    expect(find.text('Show 3.0'), findsWidgets);
    expect(find.text('ON NOW'), findsOneWidget);
  });
}
