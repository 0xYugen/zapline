import 'dart:convert';

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
}
