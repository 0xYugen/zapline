// Frame timings of the screens that must stay smooth on a TV stick.
//
// On a device (a Fire TV stick, a phone), in profile mode:
//
//   flutter drive --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf_test.dart
//
// The summary for each scenario (average and worst build and raster times,
// missed frames) lands in build/integration_response_data.json and is
// printed at the end. The library is made up (no network): 5,000 channels
// in 40 groups with a guide, as a big real playlist would be.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/layout.dart';
import 'package:zapline/src/playback/playback_engine.dart';
import 'package:zapline/src/screens/player_screen.dart';

import '../test/helpers.dart';
import '../tool/screenshots/shots.dart' show FakeEngine;

/// Channels in the made-up library; `--dart-define=PERF_CHANNELS=50000`
/// for a really large one.
const _channels = int.fromEnvironment('PERF_CHANNELS', defaultValue: 5000);

/// The physical key of each key pressed: profile builds can't look it up.
final _physical = {
  LogicalKeyboardKey.arrowDown: PhysicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowRight: PhysicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.pageDown: PhysicalKeyboardKey.pageDown,
  LogicalKeyboardKey.select: PhysicalKeyboardKey.select,
};

/// A press and release as a TV remote sends them, whatever the device
/// running the test.
Future<void> _press(LogicalKeyboardKey key) async {
  final physical = _physical[key]!;
  await simulateKeyDownEvent(key, platform: 'android', physicalKey: physical);
  await simulateKeyUpEvent(key, platform: 'android', physicalKey: physical);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> keys(
    WidgetTester tester,
    LogicalKeyboardKey key,
    int times, {
    Duration gap = const Duration(milliseconds: 60),
  }) async {
    for (var i = 0; i < times; i++) {
      await _press(key);
      await tester.pump(gap);
    }
  }

  testWidgets('TV: guide, groups and zapping', (tester) async {
    FormFactor.isTv = true;
    // Zapping is about the screen here; a real stream's start time shows
    // in the player's info bar in profile builds.
    debugEngineFactory = FakeEngine.new;
    final state = fakeState(
      count: _channels,
      groups: [for (var i = 1; i <= 40; i++) 'Group $i'],
    );
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    await tester.pumpWidget(ZaplineApp(state: state));
    await tester.pumpAndSettle();

    // Down the guide one channel at a time, as a held key would.
    await binding.watchPerformance(
      () => keys(tester, LogicalKeyboardKey.arrowDown, 80),
      reportKey: 'guide_down',
    );
    // A screen at a time, then along the time line.
    await binding.watchPerformance(() async {
      await keys(
        tester,
        LogicalKeyboardKey.pageDown,
        15,
        gap: const Duration(milliseconds: 250),
      );
      await keys(
        tester,
        LogicalKeyboardKey.arrowRight,
        12,
        gap: const Duration(milliseconds: 150),
      );
    }, reportKey: 'guide_page');

    // The groups beside the grid.
    await binding.watchPerformance(() async {
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      await keys(tester, LogicalKeyboardKey.arrowDown, 30);
    }, reportKey: 'groups');

    // Into the grid and the player; quick zaps, then single ones.
    await _press(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await _press(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
    await binding.watchPerformance(() async {
      await keys(tester, LogicalKeyboardKey.arrowDown, 20);
      await keys(
        tester,
        LogicalKeyboardKey.arrowDown,
        6,
        gap: const Duration(milliseconds: 700),
      );
    }, reportKey: 'zap');
  });

  testWidgets('phone: channel list and guide', (tester) async {
    FormFactor.isTv = false;
    debugEngineFactory = FakeEngine.new;
    final state = fakeState(count: _channels);
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    await tester.pumpWidget(ZaplineApp(state: state));
    await tester.pumpAndSettle();
    // The phone layout only shows on a phone-sized screen.
    if (find.byType(CustomScrollView).evaluate().isEmpty) return;

    await binding.watchPerformance(() async {
      for (var i = 0; i < 4; i++) {
        await tester.fling(
          find.byType(CustomScrollView).first,
          const Offset(0, -1500),
          3000,
        );
        await tester.pumpAndSettle();
      }
    }, reportKey: 'phone_fling');
  });
}
