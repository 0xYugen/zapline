import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/device_controls.dart';
import 'package:zapline/src/playback/playback_engine.dart';

import '../tool/screenshots/shots.dart' show FakeEngine;
import 'helpers.dart';

/// The phone player: up and down on the left sets the brightness, on the
/// right the volume; going home shrinks it to picture-in-picture.
void main() {
  final calls = <MethodCall>[];

  setUp(() {
    debugEngineFactory = FakeEngine.new;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zapline/device'), (
          call,
        ) async {
          calls.add(call);
          return switch (call.method) {
            'volume' => 0.5,
            'brightness' => 0.5,
            'setPip' => true,
            'isTv' => false,
            _ => null,
          };
        });
  });
  tearDown(() {
    debugEngineFactory = null;
    DeviceControls.inPip.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zapline/device'), null);
  });

  Future<void> openPlayer(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(915, 412) * 2.625
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final state = fakeState(count: 5);
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    await tester.pumpWidget(ZaplineApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Channel 1').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Iterable<Object?> args(String method, String key) => [
    for (final c in calls)
      if (c.method == method) (c.arguments as Map)[key],
  ];

  testWidgets('sides of the picture set brightness and volume', (
    tester,
  ) async {
    await openPlayer(tester);
    // Up on the left: brighter.
    await tester.dragFrom(const Offset(80, 300), const Offset(0, -120));
    await tester.pump();
    final b = args('setBrightness', 'value').whereType<double>().toList();
    expect(b, isNotEmpty);
    expect(b.last, greaterThan(0.5));
    expect(find.byIcon(Icons.brightness_6_rounded), findsOneWidget);

    // Down on the right: quieter. Neither zaps.
    await tester.dragFrom(const Offset(840, 150), const Offset(0, 120));
    await tester.pump();
    final v = args('setVolume', 'value').whereType<double>().toList();
    expect(v.last, lessThan(0.5));
    expect(find.text('1 · Channel 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));

    // Leaving the player gives the brightness back to the system.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(args('setBrightness', 'value').last, isNull);
  });

  testWidgets('picture-in-picture shows only the picture', (tester) async {
    await openPlayer(tester);
    expect(args('setPip', 'enabled').first, isTrue);
    expect(find.byTooltip('Next channel'), findsOneWidget);

    DeviceControls.inPip.value = true;
    await tester.pump();
    expect(find.byTooltip('Next channel'), findsNothing);
    DeviceControls.inPip.value = false;
    await tester.pump();
    expect(find.byTooltip('Next channel'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(args('setPip', 'enabled').last, isFalse);
  });
}
