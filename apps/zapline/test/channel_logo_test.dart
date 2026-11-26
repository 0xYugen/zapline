import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/widgets/channel_logo.dart';
import 'package:zapline_core/zapline_core.dart';

// 1x1 red PNG.
final _png = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
);

Channel _ch(String? logo) => Channel(
  sourceId: 's',
  id: '1',
  name: 'News Channel',
  streamUrl: Uri.parse('http://x/1.ts'),
  logoUrl: logo == null ? null : Uri.parse(logo),
);

void main() {
  tearDown(() {
    LogoCache.debugLoader = null;
    LogoCache.debugReset();
  });

  test('concurrent and repeated loads complete (no self-wait)', () async {
    var calls = 0;
    LogoCache.debugLoader = (_) async {
      calls++;
      return _png;
    };
    final a = LogoCache.load('http://l.example/same.png');
    final b = LogoCache.load('http://l.example/same.png');
    expect(identical(a, b), isTrue);
    await Future.wait([a, b]).timeout(const Duration(seconds: 2));
    await LogoCache.load('http://l.example/same.png')
        .timeout(const Duration(seconds: 2));
    expect(calls, 2, reason: 'in-flight dedup, then a fresh load');
  });

  testWidgets('shows the logo once loaded', (tester) async {
    LogoCache.debugLoader = (_) async => _png;
    await tester.pumpWidget(
      MaterialApp(home: ChannelLogo(channel: _ch('http://l.example/a.png'))),
    );
    expect(find.text('NC'), findsOneWidget, reason: 'badge while loading');
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('NC'), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
  });

  testWidgets('falls back to initials on error or without a URL', (
    tester,
  ) async {
    LogoCache.debugLoader = (_) async => throw StateError('404');
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ChannelLogo(channel: _ch('http://l.example/missing.png')),
            ChannelLogo(channel: _ch(null)),
          ],
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('NC'), findsNWidgets(2));
  });
  test('at most a few downloads at once, the newest first', () async {
    final started = <String>[];
    final release = <String, Completer<void>>{};
    LogoCache.debugLoader = (url) async {
      started.add(url);
      await (release[url] = Completer<void>()).future;
      return _png;
    };
    final all = [
      for (var i = 0; i < LogoCache.parallel + 3; i++)
        LogoCache.load('http://l.example/$i.png'),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(started, hasLength(LogoCache.parallel));
    release[started.first]!.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    // The last asked for (on screen now) goes before the older ones.
    expect(started.last, 'http://l.example/${LogoCache.parallel + 2}.png');
    for (var i = 0; i < 4; i++) {
      for (final c in release.values) {
        if (!c.isCompleted) c.complete();
      }
      await Future<void>.delayed(Duration.zero);
    }
    await Future.wait(all).timeout(const Duration(seconds: 2));
    expect(started, hasLength(LogoCache.parallel + 3));
  });

  testWidgets('a large logo is kept scaled down', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Noise, so the PNG is large.
      var seed = 1;
      for (var y = 0; y < 400; y += 2) {
        for (var x = 0; x < 600; x += 2) {
          seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 2, 2),
            Paint()..color = Color(0xFF000000 | (seed & 0xFFFFFF)),
          );
        }
      }
      final image = await recorder.endRecording().toImage(600, 400);
      final big = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      expect(big.length, greaterThan(24 * 1024));
      final small = await LogoCache.shrink(big);
      expect(small.length, lessThan(big.length));
      final codec = await ui.instantiateImageCodec(small);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, LogoCache.thumbSize);
      expect(frame.image.height, closeTo(LogoCache.thumbSize * 2 / 3, 1));
      // Small ones are left alone.
      expect(identical(await LogoCache.shrink(_png), _png), isTrue);
    });
  });
}
