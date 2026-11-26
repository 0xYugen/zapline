import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/playback/playback_engine.dart';
import 'package:zapline/src/screens/player_screen.dart';
import 'package:zapline/src/widgets/focus_card.dart';

import '../tool/screenshots/shots.dart' show FakeEngine;
import 'helpers.dart';

/// Text inside the focused card.
String? _focused() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null || ctx.findAncestorWidgetOfExactType<FocusCard>() == null) {
    return null;
  }
  final texts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Text && w.data != null) texts.add(w.data!);
    e.visitChildren(visit);
  }

  (ctx as Element).visitChildren(visit);
  return texts.join(' ');
}

Future<AppState> _home(
  WidgetTester tester, {
  int count = 60,
  List<String>? groups,
}) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  debugEngineFactory = FakeEngine.new;
  addTearDown(() => debugEngineFactory = null);
  final state = fakeState(count: count, groups: groups);
  await state.addSource(
    const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
  );
  await tester.pumpWidget(ZaplineApp(state: state));
  await tester.pumpAndSettle();
  expect(_focused(), 'Show 1.0');
  return state;
}

void main() {
  testWidgets('Page Down and Channel Down move a screen of channels', (
    tester,
  ) async {
    await _home(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    final paged = _focused()!;
    final row = int.parse(paged.split(' ').last.split('.').first);
    expect(row, greaterThan(5));

    await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
    await tester.pumpAndSettle();
    final again = int.parse(_focused()!.split(' ').last.split('.').first);
    expect(again, row + (row - 1));

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(_focused(), paged);
  });

  testWidgets('typing a number jumps to that channel, even off screen', (
    tester,
  ) async {
    await _home(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    expect(find.text('42'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(_focused(), 'Show 42.0');
  });

  testWidgets('back from the player, the grid is on the channel zapped to', (
    tester,
  ) async {
    await _home(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsNothing);
    expect(_focused(), 'Show 4.0');
  });

  testWidgets('Back in the guide returns to now before leaving the grid', (
    tester,
  ) async {
    await _home(tester);
    // Four half-hours ahead.
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    expect(_focused(), isNot('Show 1.0'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_focused(), 'Show 1.0');
    // Then Back opens the groups as before.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_focused(), 'All channels');
  });

  testWidgets('groups: Page Down moves a screen, a letter finds a group', (
    tester,
  ) async {
    await _home(
      tester,
      count: 80,
      groups: [
        for (var i = 1; i <= 38; i++) 'Group ${i.toString().padLeft(2, '0')}',
        'IT | Sport',
        'News',
      ],
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_focused(), 'All channels');

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    final paged = _focused()!;
    expect(paged, startsWith('Group '));
    expect(int.parse(paged.substring(6)), greaterThan(8));

    // S: past the country tag, "IT | Sport", far down the list.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    expect(_focused(), 'IT | Sport');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(_focused(), 'News');
  });
}
