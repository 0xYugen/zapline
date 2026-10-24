import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';

import 'package:zapline/src/playback/playback_engine.dart';

import '../../test/helpers.dart';
import 'shots.dart';

/// Layout problems are collected, not fatal, so every screen is captured.
final problems = <String>[];

void drain(WidgetTester tester) {
  for (Object? e; (e = tester.takeException()) != null;) {
    problems.add('after $lastShot: ${'$e'.split(String.fromCharCode(10)).first}');
  }
}

Future<void> step(WidgetTester tester) async {
  await settle(tester);
  drain(tester);
}

Future<void> connect(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextField).first,
    'http://x.example/get.php?username=a&password=b',
  );
  await tester.pump();
  await tester.tap(find.text('Connect'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await step(tester);
}

Future<bool> tapText(WidgetTester tester, String label) async {
  final f = find.text(label);
  if (f.evaluate().isEmpty) {
    problems.add('missing "$label"');
    return false;
  }
  await tester.tap(f.last);
  await step(tester);
  return true;
}

Future<void> back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
  await step(tester);
}

void main() {
  setUpAll(loadFonts);

  for (final d in [phone, phoneLandscape]) {
    testWidgets('screens on ${d.name}', (tester) async {
      problems.clear();
      useDevice(tester, d);
      final state = fakeState(count: 40);
      await tester.pumpWidget(capturable(ZaplineApp(state: state), d));
      await step(tester);
      await shot(tester, d, '01-add-source');
      await connect(tester);
      state.toggleFavourite(state.channels()[2]);
      await step(tester);
      await shot(tester, d, '02-channels');

      debugEngineFactory = FakeEngine.new;
      await tester.tap(find.text('Channel 1').first);
      await step(tester);
      await shot(tester, d, '08-player');
      await tester.tap(find.byTooltip('Channels'));
      await step(tester);
      await shot(tester, d, '08b-player-list');
      await back(tester);
      await back(tester);

      await tester.longPress(find.text('Channel 2').first);
      await step(tester);
      await shot(tester, d, '02b-channel-menu');
      await back(tester);

      await tester.tap(find.byTooltip('All groups'));
      await step(tester);
      await shot(tester, d, '02c-groups');
      await back(tester);

      if (await tapText(tester, 'Guide')) {
        await shot(tester, d, '03-guide');
        await tapText(tester, 'Channel 3');
        await shot(tester, d, '03b-schedule');
        await back(tester);
      }
      if (await tapText(tester, 'Search')) {
        await tester.enterText(find.byType(TextField).last, 'Show 1');
        await tester.pump(const Duration(milliseconds: 400));
        await step(tester);
        await shot(tester, d, '04-search');
      }
      if (await tapText(tester, 'Settings')) {
        await shot(tester, d, '05-settings');
        if (await tapText(tester, 'Playlists and servers')) {
          await shot(tester, d, '06-sources');
          if (await tapText(tester, 'Manage')) {
            await shot(tester, d, '07-manage');
            await back(tester);
          }
          await back(tester);
        }
      }
      // ignore: avoid_print
      print(
        '${d.name}: ${problems.length} problems\n'
        '${problems.toSet().join('\n')}',
      );
    });
  }
}
