import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';

import 'dart:io';

import 'package:zapline/src/cast/cast_link.dart';
import 'package:zapline/src/l10n.dart';
import 'package:zapline/src/cast/cast_ui.dart';
import 'package:zapline/src/playback/playback_engine.dart';
import 'package:zapline/src/screens/player_screen.dart';

import '../tool/screenshots/shots.dart' show FakeEngine;
import 'helpers.dart';

void main() {
  testWidgets('the TV opens the channel a phone sends', (tester) async {
    debugEngineFactory = FakeEngine.new;
    addTearDown(() => debugEngineFactory = null);
    tester.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = fakeState(count: 5);
    await s.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    await tester.pumpWidget(ZaplineApp(state: s));
    await tester.pumpAndSettle();

    final request = castRequestFor(s, channel: s.channels()[2])!;
    final handler = tester.state(find.byType(ZaplineApp)) as CastHandler;
    expect(
      await handler.castPlay({...request, 'source': 'nope'}),
      'unknown-source',
    );
    expect(await handler.castPlay(request), isNull);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(handler.castStatus?.title, 'Channel 3');

    handler.castKey('down');
    await tester.pump(const Duration(milliseconds: 500));
    expect(handler.castStatus?.title, 'Channel 4');

    handler.castStop();
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsNothing);
  });

  testWidgets('the phone remote lays out', (tester) async {
    tester.view
      ..physicalSize = const Size(412, 915) * 2.625
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = fakeState(count: 5);
    await s.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CastRemoteScreen(
          state: s,
          device: CastDevice(
            name: 'Soggiorno',
            address: InternetAddress.loopbackIPv4,
            port: 1,
          ),
          channels: s.channels(),
          index: 1,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('On air on Soggiorno'), findsOneWidget);
    expect(find.text('Channel 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Next channel'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Channel 3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
