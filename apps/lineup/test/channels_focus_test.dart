import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lineup/main.dart';
import 'package:lineup/src/screens/guide_screen.dart';
import 'package:lineup/src/widgets/focus_card.dart';

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
    await tester.pumpWidget(LineupApp(state: fakeState()));
    await _connect(tester);

    expect(find.text('Channel 1'), findsOneWidget);
    expect(_focusedLabel(), contains('Channel 1'));
    expect(_focusedLabel(), contains('Show 1.0'), reason: 'now playing shown');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedLabel(), contains('Channel 2'));
  });

  testWidgets('TV guide opens on the current programme and pages with D-pad', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    await tester.pumpWidget(LineupApp(state: fakeState()));
    await _connect(tester);

    await tester.tap(find.text('TV guide'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideScreen), findsOneWidget);
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
}
