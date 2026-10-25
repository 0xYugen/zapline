import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/layout.dart';
import 'package:zapline/src/playback/playback_engine.dart';
import 'package:zapline/src/screens/filters_screen.dart';
import 'package:zapline/src/screens/guide_mapping_screen.dart';
import 'package:zapline/src/screens/guide_settings_screen.dart';
import 'package:zapline/src/screens/settings_screen.dart';
import 'package:zapline/src/screens/transfer_screens.dart';
import 'package:zapline/src/vod/vod_browse.dart';

import '../../test/helpers.dart';
import 'shots.dart';

// TV (remote, 10-foot) and PC (mouse) screens, for design review:
//
//   flutter test tool/screenshots/big_screen_test.dart

final problems = <String>[];

Future<void> step(WidgetTester tester) async {
  await settle(tester);
  for (Object? e; (e = tester.takeException()) != null;) {
    problems.add('after $lastShot: ${'$e'.split('\n').first}');
  }
}

Future<void> push(WidgetTester tester, Widget page) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push(MaterialPageRoute<void>(builder: (_) => page));
  await step(tester);
}

Future<void> back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
  await step(tester);
}

const pc = Device('pc', Size(1366, 768), 1);

void main() {
  setUpAll(loadFonts);

  for (final (d, isTv) in [(tv, true), (pc, false)]) {
    testWidgets('big screens: ${d.name}', (tester) async {
      problems.clear();
      FormFactor.isTv = isTv;
      addTearDown(() => FormFactor.isTv = false);
      debugEngineFactory = FakeEngine.new;
      useDevice(tester, d);
      final state = fakeState(
        count: 30,
        vod: true,
        unmatched: {6, 12},
        names: [
          'IT | Rai 1 HD',
          'IT | Rai 1 FHD',
          'IT | Rai 1 4K',
          'IT | Rai 2',
          'IT | Rai 3',
        ],
        groups: ['IT | Rai', 'IT | Mediaset', 'UK | General', 'XXX Adult'],
      );
      await state.addSource(
        const SourceInput(
          url: 'http://x.example/get.php?username=a&password=b',
        ),
      );
      state.settings.setLanguage('it');
      await tester.pumpWidget(capturable(ZaplineApp(state: state), d));
      await step(tester);
      await shot(tester, d, '01-home');

      // Remote: move around the home screen.
      for (final k in [
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
      ]) {
        await tester.sendKeyEvent(k);
        await tester.pump(const Duration(milliseconds: 150));
      }
      await step(tester);
      await shot(tester, d, '01b-home-focus');

      await push(tester, VodScreen(state: state, kind: VodKind.movies));
      await shot(tester, d, '02-movies');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await step(tester);
      await shot(tester, d, '02b-movies-focus');
      await back(tester);

      await push(tester, SettingsScreen(state: state));
      await shot(tester, d, '03-settings');
      await back(tester);
      final id = state.sources.single.id;
      await push(tester, FiltersScreen(state: state, sourceId: id));
      await shot(tester, d, '04-filters');
      await back(tester);
      await push(tester, GuideSettingsScreen(state: state, sourceId: id));
      await shot(tester, d, '05-guide');
      await back(tester);
      await push(tester, GuideMappingScreen(state: state, sourceId: id));
      await shot(tester, d, '06-match');
      await back(tester);
      await push(tester, TransferReceiveScreen(state: state));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await step(tester);
      await shot(tester, d, '07-receive');
      await back(tester);
      // ignore: avoid_print
      print(
        '${d.name}: ${problems.length} problems\n'
        '${problems.toSet().join('\n')}',
      );
    });
  }
}
