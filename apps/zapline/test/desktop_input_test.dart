import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/screens/search_screen.dart';
import 'package:zapline/src/widgets/focus_card.dart';

import 'helpers.dart';

Future<void> _ready(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  final state = fakeState(count: 6);
  await state.addSource(
    const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
  );
  await tester.pumpWidget(ZaplineApp(state: state));
  await tester.pumpAndSettle();
}

String? _focusedText() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx?.findAncestorWidgetOfExactType<FocusCard>() == null) return null;
  final texts = <String>[];
  void visit(Element e) {
    if (e.widget case Text(:final data?)) texts.add(data);
    e.visitChildren(visit);
  }

  (ctx! as Element).visitChildren(visit);
  return texts.join(' ');
}

void main() {
  testWidgets('Esc goes back on desktop', (tester) async {
    await _ready(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
  });

  testWidgets('mouse back button goes back', (tester) async {
    await _ready(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    await mouse.down(const Offset(900, 500));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
  });

  testWidgets('hovering moves the highlight; back arrow only for the mouse', (
    tester,
  ) async {
    await _ready(tester);
    expect(_focusedText(), contains('Show 1.0'));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Show 3.0')));
    await tester.pumpAndSettle();
    expect(_focusedText(), contains('Show 3.0'));

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    final back = find.byIcon(Icons.arrow_back_rounded);
    expect(back, findsOneWidget);

    // Back to keys: the arrow disappears.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(back, findsNothing);

    await mouse.moveTo(const Offset(40, 40));
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
    await mouse.removePointer();
  });
}
