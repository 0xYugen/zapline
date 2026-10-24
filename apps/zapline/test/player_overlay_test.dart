import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/playback/playback_engine.dart';

import '../tool/screenshots/shots.dart' show FakeEngine;
import 'helpers.dart';

/// On phones a tap on the picture hides the controls and the next tap
/// brings them back, wherever the tap lands.
void main() {
  setUp(() => debugEngineFactory = FakeEngine.new);
  tearDown(() => debugEngineFactory = null);

  testWidgets('tapping the picture toggles the controls', (tester) async {
    tester.view
      ..physicalSize = const Size(412, 915) * 2.625
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final state = fakeState(count: 5);
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    await tester.pumpWidget(ZaplineApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Channel 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    double opacity() => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byTooltip('Next channel'),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;

    expect(opacity(), 1);
    // Away from the buttons, near the top-left corner.
    await tester.tapAt(const Offset(200, 260));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opacity(), 0);
    await tester.tapAt(const Offset(200, 260));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opacity(), 1);
  });
}
