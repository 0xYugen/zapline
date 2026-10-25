import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/screens/guide_screen.dart';
import 'package:zapline/src/widgets/focus_card.dart';

import 'helpers.dart';

String? _focusedLabel() {
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

Future<void> _connect(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextField).first,
    'http://x.example/get.php?username=a&password=b',
  );
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  // The fake sync is async; let it finish and the list appear.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('after connecting, the first channel has focus and D-pad moves', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    await tester.pumpWidget(ZaplineApp(state: fakeState()));
    await _connect(tester);

    // Channels and their guide in one grid, on what's on now.
    expect(find.text('Channel 1'), findsOneWidget);
    expect(find.byType(GuideGrid), findsOneWidget);
    expect(_focusedLabel(), 'Show 1.0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedLabel(), 'Show 2.0');
  });

  testWidgets('left and Back open the groups, then the menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    final state = fakeState(groups: ['News', 'Sport']);
    await tester.pumpWidget(ZaplineApp(state: state));
    await _connect(tester);
    // These channels keep an archive: Back, not left, opens the groups.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_focusedLabel(), 'All channels');

    // Moving over a group shows its channels; OK goes into the grid.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedLabel(), 'News');
    expect(find.text('Channel 2'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(_focusedLabel(), 'Show 1.0');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_focusedLabel(), 'Live TV');
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('TV guide opens on the current programme and pages with D-pad', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    await tester.pumpWidget(ZaplineApp(state: fakeState()));
    await _connect(tester);

    expect(_focusedLabel(), 'Show 1.0');

    // Walk right past the window edge: the grid pages forward.
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    expect(_focusedLabel(), startsWith('Show 1.'));
    expect(_focusedLabel(), isNot('Show 1.0'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedLabel(), startsWith('Show 2.'));
  });

  testWidgets('Menu key opens the channel menu; OK adds a favourite', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    final state = fakeState();
    await tester.pumpWidget(ZaplineApp(state: state));
    await _connect(tester);
    expect(find.text('Favourites'), findsNothing);

    Future<void> menuThenOk() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(find.text('Add to favourites'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Favourites'), findsOneWidget);
    expect(state.favourites().single.name, 'Channel 2');
    expect(_focusedLabel(), 'Show 2.0', reason: 'focus returns');

    await menuThenOk();
    expect(find.text('Favourites'), findsNothing);
  });

  testWidgets('past programmes with an archive are marked in the guide', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    await tester.pumpWidget(ZaplineApp(state: fakeState()));
    await _connect(tester);
    expect(find.byIcon(Icons.history), findsNothing);

    // Page back past the left edge into programmes that already aired.
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
    }
    expect(find.byIcon(Icons.history), findsWidgets);
  });

  testWidgets('from the menu, right twice or OK on Live TV reach the grid', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    await tester.pumpWidget(ZaplineApp(state: fakeState()));
    await _connect(tester);
    Future<void> key(LogicalKeyboardKey k) async {
      await tester.sendKeyEvent(k);
      await tester.pumpAndSettle();
    }

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await key(LogicalKeyboardKey.arrowLeft);
    expect(_focusedLabel(), 'Live TV');
    await key(LogicalKeyboardKey.arrowRight);
    expect(_focusedLabel(), 'All channels');
    await key(LogicalKeyboardKey.arrowRight);
    expect(_focusedLabel(), 'Show 1.0');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await key(LogicalKeyboardKey.arrowLeft);
    expect(_focusedLabel(), 'Live TV');
    await key(LogicalKeyboardKey.select);
    expect(_focusedLabel(), 'Show 1.0');
  });
}
