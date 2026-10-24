import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';

import 'package:zapline/src/playback/playback_engine.dart';

import '../../test/helpers.dart';
import 'shots.dart';

/// Layout problems are collected, not fatal, so every screen is captured.
final problems = <String>[];

void drain(WidgetTester tester) {
  for (Object? e; (e = tester.takeException()) != null;) {
    problems.add(
      'after $lastShot: ${'$e'.split(String.fromCharCode(10)).first}',
    );
  }
}

Future<void> step(WidgetTester tester) async {
  await settle(tester);
  drain(tester);
}

Future<void> connect(WidgetTester tester, Device d) async {
  await tester.ensureVisible(find.text('Server login (Xtream)'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Server login (Xtream)'));
  await step(tester);
  await shot(tester, d, '01b-xtream-form');
  await tester.enterText(
    find.byType(TextField).first,
    'http://x.example/get.php?username=a&password=b',
  );
  await tester.pump();
  await tester.ensureVisible(find.text('Connect'));
  await tester.pumpAndSettle();
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
      await connect(tester, d);
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

      await tester.tap(find.byTooltip('Search channels and programmes').first);
      await step(tester);
      await tester.enterText(find.byType(TextField).last, 'Show 1');
      await tester.pump(const Duration(milliseconds: 400));
      await step(tester);
      await shot(tester, d, '04-search');
      await back(tester);

      if (await tapText(tester, 'Guide')) {
        await shot(tester, d, '03-guide');
        await tapText(tester, 'Channel 3');
        await shot(tester, d, '03b-schedule');
        final upcoming = find.text('Show 3.1').evaluate().isEmpty
            ? 'Show 3.-1'
            : 'Show 3.1';
        if (await tapText(tester, upcoming)) {
          await shot(tester, d, '03c-programme');
          await back(tester);
        }
        await back(tester);
      }
      if (await tapText(tester, 'Favourites')) {
        await shot(tester, d, '04b-favourites');
      }
      if (await tapText(tester, 'Settings')) {
        await shot(tester, d, '05-settings');
        if (await tapText(tester, state.sources.single.name)) {
          await shot(tester, d, '06-source');
          if (await tapText(tester, 'Groups and filters')) {
            await shot(tester, d, '07-groups');
            await back(tester);
          }
          if (await tapText(tester, 'TV guide (EPG)')) {
            await shot(tester, d, '07b-epg');
            await back(tester);
          }
          await back(tester);
        }
      }
      // The same app in Italian.
      state.settings.setLanguage('it');
      await step(tester);
      await shot(tester, d, '09-settings-it');
      if (await tapText(tester, 'TV in diretta')) {
        await shot(tester, d, '09b-channels-it');
      }
      if (await tapText(tester, 'Guida')) {
        await shot(tester, d, '09c-guide-it');
      }
      // ignore: avoid_print
      print(
        '${d.name}: ${problems.length} problems\n'
        '${problems.toSet().join('\n')}',
      );
    });
  }

  for (final d in [phone, phoneLandscape]) {
    testWidgets('films and series on ${d.name}', (tester) async {
      problems.clear();
      useDevice(tester, d);
      debugEngineFactory = FakeEngine.new;
      final state = fakeState(count: 10, vod: true);
      await state.addSource(
        const SourceInput(
          url: 'http://x.example/get.php?username=a&password=b',
        ),
      );
      await tester.pumpWidget(capturable(ZaplineApp(state: state), d));
      await step(tester);
      await shot(tester, d, '10-tv-vod');
      await tapText(tester, 'Movies');
      await shot(tester, d, '11-movies');
      // The pill, not the row title of the same name.
      await tester.tap(find.text('IT | Commedia').first);
      await step(tester);
      await shot(tester, d, '11b-category');
      await tester.tap(find.text('Film 4').first);
      await step(tester);
      await shot(tester, d, '12-movie');
      await tester.ensureVisible(find.text('Play'));
      await step(tester);
      await tapText(tester, 'Play');
      await tester.pump(const Duration(seconds: 1));
      await step(tester);
      await shot(tester, d, '13-vod-player');
      await back(tester);
      await tester.pump(const Duration(seconds: 1));
      await step(tester);
      await shot(tester, d, '12b-movie-resume');
      await back(tester);
      await tapText(tester, 'All');
      await shot(tester, d, '11c-movies-continue');
      await tapText(tester, 'Series');
      await shot(tester, d, '14-series');
      await tester.tap(find.text('Serie 2').first);
      await step(tester);
      await shot(tester, d, '15-show');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await step(tester);
      await shot(tester, d, '15b-show-episodes');
      await back(tester);
      state.settings.setLanguage('it');
      await step(tester);
      await shot(tester, d, '16-series-it');
      // ignore: avoid_print
      print(
        '${d.name} vod: ${problems.length} problems\n'
        '${problems.toSet().join('\n')}',
      );
    });
  }
}
