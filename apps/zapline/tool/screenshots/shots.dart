// Renders screens at real device sizes with real fonts, for design review
// without an emulator:
//
//   flutter test tool/screenshots/phone_test.dart
//
// PNGs land in build/screenshots/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/playback/playback_engine.dart';

/// A device to render on: logical size, pixel ratio and system bars.
class Device {
  const Device(
    this.name,
    this.size,
    this.ratio, {
    this.top = 0,
    this.bottom = 0,
  });

  final String name;
  final Size size;
  final double ratio;

  /// Status bar and navigation bar heights, in logical pixels.
  final double top, bottom;
}

const phone = Device('phone', Size(412, 915), 2.625, top: 24, bottom: 48);
const phoneLandscape = Device(
  'phone-land',
  Size(915, 412),
  2.625,
  top: 24,
  bottom: 0,
);
const tv = Device('tv', Size(960, 540), 2);

Future<void> loadFonts() async {
  final dir =
      '${Platform.environment['FLUTTER_ROOT'] ?? r'D:\tools\flutter'}'
      r'\bin\cache\artifacts\material_fonts';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File('$dir\\$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await family('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]);
  await family('MaterialIcons', ['materialicons-regular.otf']);
}

void useDevice(WidgetTester tester, Device d) {
  tester.view
    ..physicalSize = d.size * d.ratio
    ..devicePixelRatio = d.ratio
    ..padding = FakeViewPadding(
      top: d.top * d.ratio,
      bottom: d.bottom * d.ratio,
    )
    ..viewPadding = FakeViewPadding(
      top: d.top * d.ratio,
      bottom: d.bottom * d.ratio,
    );
  addTearDown(tester.view.reset);
}

final shotKey = GlobalKey();

/// Wrap the app with this so [shot] can capture it, system bars included.
Widget capturable(Widget app, Device d) => RepaintBoundary(
  key: shotKey,
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      children: [
        app,
        // Draw translucent system bars where Android would.
        if (d.top > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: d.top,
            child: const IgnorePointer(
              child: ColoredBox(color: Color(0x66000000)),
            ),
          ),
        if (d.bottom > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: d.bottom,
            child: const IgnorePointer(
              child: ColoredBox(color: Color(0x99000000)),
            ),
          ),
      ],
    ),
  ),
);

/// Like pumpAndSettle, but gives up on endless animations (spinners).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
}

/// The last screen captured, to place reported problems.
String lastShot = '';

Future<void> shot(WidgetTester tester, Device d, String name) async {
  lastShot = name;
  await settle(tester);
  tester.takeException();
  final boundary =
      shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: d.ratio / 1.5);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/screenshots/${d.name}-$name.png')
      ..createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Plays nothing; draws a test picture so overlays can be judged.
class FakeEngine implements PlaybackEngine {
  @override
  String get name => 'fake';

  @override
  Future<void> open(Uri url, {Map<String, String> headers = const {}}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Stream<Duration> get position => const Stream.empty();

  @override
  Stream<String> get errors => const Stream.empty();

  @override
  Widget buildView({BoxFit fit = BoxFit.contain}) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF2B5876), Color(0xFF4E4376), Color(0xFFB06AB3)],
      ),
    ),
  );
}
