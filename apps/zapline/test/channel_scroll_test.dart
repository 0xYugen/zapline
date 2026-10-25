import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/playback/playback_engine.dart';

import '../tool/screenshots/shots.dart' show FakeEngine;
import 'helpers.dart';

/// Turning the phone (the player does, for full screen) keeps the channel
/// list where it was scrolled.
void main() {
  setUp(() => debugEngineFactory = FakeEngine.new);
  tearDown(() => debugEngineFactory = null);

  testWidgets('the channel list keeps its place across a rotation', (
    tester,
  ) async {
    void use(Size size) => tester.view
      ..physicalSize = size * 2.625
      ..devicePixelRatio = 2.625;
    use(const Size(412, 915));
    addTearDown(tester.view.reset);

    final state = fakeState(count: 80);
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    await tester.pumpWidget(ZaplineApp(state: state));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    double offset() => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    final before = offset();
    expect(before, greaterThan(1000));

    use(const Size(915, 412));
    await tester.pumpAndSettle();
    use(const Size(412, 915));
    await tester.pumpAndSettle();
    expect(offset(), closeTo(before, 1));
    expect(find.text('Channel 1'), findsNothing);
  });
}
