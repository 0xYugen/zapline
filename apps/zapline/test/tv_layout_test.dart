import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/layout.dart';

import 'helpers.dart';

/// Android TV renders 1080p at 960x540 logical pixels (density 2).
void _tvView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  // At 960x540 only the platform check tells a TV from a phone.
  FormFactor.isTv = true;
  addTearDown(() => FormFactor.isTv = false);
}

void main() {
  testWidgets('TV size: list starts at the top and Back reaches the groups', (
    tester,
  ) async {
    _tvView(tester);
    final state = fakeState(count: 12);
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    await tester.pumpWidget(ZaplineApp(state: state));
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).last;
    final position = tester.state<ScrollableState>(list).position;
    debugPrint('offset after start: ${position.pixels}');
    debugPrint('focus: ${FocusManager.instance.primaryFocus}');
    expect(position.pixels, 0);

    // These channels keep an archive, so left goes back in time; Back
    // opens the groups.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    debugPrint('focus after back: ${FocusManager.instance.primaryFocus}');
    // Focus left the grid for the groups on the left of the screen.
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      tester.getCenter(find.byWidget(focused.widget).first).dx,
      lessThan(400),
    );
  });
}
