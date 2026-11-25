import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/playback/playback_engine.dart';

import '../tool/screenshots/shots.dart' show FakeEngine;
import 'helpers.dart';

/// With the system's text made larger, rows grow instead of cutting their
/// lines: any overflow fails the test.
void main() {
  setUp(() => debugEngineFactory = FakeEngine.new);
  tearDown(() => debugEngineFactory = null);

  for (final (name, size, ratio) in [
    ('phone', const Size(412, 915), 2.625),
    ('TV', const Size(1920, 1080), 1.0),
  ]) {
    testWidgets('$name lists with large text', (tester) async {
      tester.view
        ..physicalSize = size * ratio
        ..devicePixelRatio = ratio;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final state = fakeState(count: 30, groups: ['News', 'Sport']);
      await state.addSource(
        const SourceInput(
          url: 'http://x.example/get.php?username=a&password=b',
        ),
      );
      await tester.pumpWidget(ZaplineApp(state: state));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Channel 1'), findsWidgets);

      if (name == 'TV') {
        // Back opens the groups beside the grid.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Sport'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } else {
        await tester.tap(find.text('Guide').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Live TV').last);
        await tester.pumpAndSettle();
      }

      // The channel list over the player too.
      await tester.tap(find.text('Channel 1').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
