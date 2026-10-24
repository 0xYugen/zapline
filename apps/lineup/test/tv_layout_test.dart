import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lineup/main.dart';
import 'package:lineup/src/app_state.dart';

import 'helpers.dart';

/// Android TV renders 1080p at 960x540 logical pixels (density 2).
void _tvView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('TV size: list starts at the top and Left reaches the menu', (
    tester,
  ) async {
    _tvView(tester);
    final state = fakeState(count: 12);
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    await tester.pumpWidget(LineupApp(state: state));
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).last;
    final position = tester.state<ScrollableState>(list).position;
    debugPrint('offset after start: ${position.pixels}');
    debugPrint('focus: ${FocusManager.instance.primaryFocus}');
    expect(position.pixels, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    debugPrint('focus after left: ${FocusManager.instance.primaryFocus}');
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'menu');
  });
}
