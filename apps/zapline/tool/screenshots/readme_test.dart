// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/layout.dart';
import 'package:zapline/src/playback/playback_engine.dart';
import 'package:zapline/src/screens/guide_screen.dart';
import 'package:zapline/src/vod/vod_browse.dart';
import 'package:zapline/src/widgets/channel_logo.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import 'shots.dart';

// The README's screenshots: a TV with a made-up but believable library
// (tool/screenshots/make_assets.py draws the logos and posters).
//
//   flutter test tool/screenshots/readme_test.dart
//
// PNGs land in build/screenshots/readme-*.png.

const _assets = 'tool/screenshots/assets';
const readme = Device('readme', Size(960, 540), 2);

Uri _img(String name) => Uri.parse('http://img.test/$name.png');

/// Channel, logo, group and what it airs, in order, with minutes.
const _channels = <(String, String, String, List<(String, int)>)>[
  (
    'Meridian News',
    'meridian',
    'News',
    [
      ('Morning Briefing', 60),
      ('World Today', 30),
      ('Markets Live', 30),
      ('Meridian Reports', 45),
      ('The Big Interview', 45),
      ('Newsroom', 60),
    ],
  ),
  (
    'Arena Sports',
    'arena',
    'Sports',
    [
      ('Champions Weekly', 45),
      ('Live: City vs Rovers', 120),
      ('Post-Match Analysis', 30),
      ('Tennis: Open Finals', 90),
    ],
  ),
  (
    'Velvet Cinema',
    'velvet',
    'Movies',
    [('Neon Harbor', 110), ('The Last Lighthouse', 125), ('Saltwater', 100)],
  ),
  (
    'Terra Docs',
    'terra',
    'Documentaries',
    [
      ('Planet Below', 60),
      ('The Deep Blue', 50),
      ('Wild Islands', 50),
      ('Frozen Worlds', 60),
    ],
  ),
  (
    'Kite Kids',
    'kite',
    'Kids',
    [
      ('Pip & Pebble', 25),
      ('Rocket Club', 25),
      ('Ocean Pals', 20),
      ('The Tiny Builders', 30),
      ('Story Time', 25),
      ('Rocket Club', 25),
    ],
  ),
  (
    'Harbor One',
    'harbor',
    'Entertainment',
    [
      ('The Morning Show', 90),
      ('Kitchen Rivals', 60),
      ('Open House', 45),
      ('Quiz Night', 45),
    ],
  ),
  (
    'Pulse Music',
    'pulse',
    'Music',
    [
      ('Top 40 Countdown', 60),
      ('Live at the Roundhouse', 90),
      ('Fresh Picks', 30),
      ('Late Mix', 60),
    ],
  ),
  (
    'Orbit Science',
    'orbit',
    'Documentaries',
    [
      ('How It\'s Made Today', 30),
      ('Mission to Europa', 60),
      ('The Brain Lab', 45),
      ('Starlight', 45),
    ],
  ),
  (
    'Summit Sports 2',
    'summit',
    'Sports',
    [
      ('Motorsport Weekend', 75),
      ('Basketball Tonight', 120),
      ('Ski Highlights', 30),
    ],
  ),
  (
    'Lumen Drama',
    'lumen',
    'Entertainment',
    [('The Harbour Line', 60), ('Small Hours', 55), ('The Harbour Line', 60)],
  ),
  (
    'Bistro Food',
    'bistro',
    'Lifestyle',
    [
      ('Street Food Stories', 30),
      ('Bake Off: Home Edition', 60),
      ('Market to Table', 30),
      ('Chef\'s Table', 45),
    ],
  ),
  (
    'Atlas Weather',
    'atlas',
    'News',
    [
      ('Weather Now', 30),
      ('Weekend Outlook', 15),
      ('Weather Now', 30),
      ('Storm Watch', 45),
    ],
  ),
];

/// What a few programmes are about, shown above the guide.
const _about = {
  'Live: City vs Rovers':
      'Top of the table clash at the Riverside. City need a win to stay '
      'in the title race; Rovers have not lost away since August.',
  'Markets Live': "Stocks, currencies and the day's biggest company news.",
  'The Last Lighthouse':
      'A keeper on a remote island finds a message that changes everything.',
  'The Deep Blue':
      "Life in the ocean's twilight zone, filmed for the first time.",
};

const _films = [
  'The Last Lighthouse',
  'Neon Harbor',
  'Glass Mountains',
  'Signal Lost',
  'Paper Moons',
  'Red Meridian',
  'Saltwater',
  'Northbound',
  'The Quiet Orbit',
  'Wild Hours',
  'Ember',
  'Small Hours',
];
const _plots = {
  'Neon Harbor':
      'A dockworker and a runaway hacker uncover what moves through the '
      'harbour at night, and who pays to keep it quiet.',
};
const _genres = ['Drama', 'Sci-Fi', 'Thriller', 'Adventure'];

AppState _state({required bool withSource}) {
  final db = ZaplineDatabase.inMemory();
  db.setSetting('holdOkHintShown', '1');
  return AppState(
    db,
    syncRunner: (source, onProgress) async {
      final channels = [
        for (final (i, (name, logo, group, _)) in _channels.indexed)
          Channel(
            sourceId: source.id,
            id: '$i',
            name: name,
            number: i + 1,
            groupTitle: group,
            logoUrl: _img('logo-$logo'),
            epgChannelId: 'g$i',
            streamUrl: Uri.parse('http://x.example/live/u/p/$i.ts'),
            catchup: const CatchupInfo(mode: CatchupMode.xtream, days: 3),
          ),
      ];
      db.replaceChannels(source.id, channels);
      final added = DateTime.utc(2026, 9, 1);
      db.replaceMovies(source.id, [
        for (final (i, title) in _films.indexed)
          Movie(
            sourceId: source.id,
            id: '$i',
            name: title,
            category: _genres[i % _genres.length],
            posterUrl: _img('poster-${i + 1}'),
            rating: 6.5 + (i * 7 % 30) / 10,
            addedAt: added.add(Duration(days: (i * 5) % 12)),
            streamUrl: Uri.parse('http://x.example/movie/u/p/$i.mp4'),
          ),
      ]);
      db.replaceShows(source.id, [
        for (final (i, title) in _films.indexed)
          Show(
            sourceId: source.id,
            id: 's$i',
            name: title,
            category: _genres[i % _genres.length],
            coverUrl: _img('poster-${i + 1}'),
            backdropUrl: _img('backdrop-${i + 1}'),
            rating: 6.5 + (i * 7 % 30) / 10,
            plot: _plots[title],
            releaseDate: '${2019 + i % 7}-03-01',
            // The newest is featured on top.
            updatedAt: added.add(Duration(days: i == 1 ? 30 : i)),
          ),
      ]);
      final now = DateTime.now().toUtc();
      final from = DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
      ).subtract(const Duration(minutes: 70));
      Stream<XmltvItem> guide() async* {
        for (final (i, (name, _, _, shows)) in _channels.indexed) {
          yield XmltvChannel(id: 'g$i', displayNames: [name]);
          var t = from.add(Duration(minutes: i * 7 % 25));
          for (var k = 0; t.isBefore(now.add(const Duration(hours: 10))); k++) {
            final (title, minutes) = shows[k % shows.length];
            yield XmltvProgramme(
              Programme(
                channelId: 'g$i',
                start: t,
                stop: t.add(Duration(minutes: minutes)),
                title: title,
                description: _about[title],
              ),
            );
            t = t.add(Duration(minutes: minutes));
          }
        }
      }

      final g = await db.importGuide(guide());
      final cov = db.rebuildGuideLinks();
      db.markSynced(source.id, now);
      return SyncResult(channels: channels.length, guide: g, coverage: cov);
    },
  );
}

/// Lets the pictures load and decode before a shot.
Future<void> _images(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    LogoCache.debugReset();
    LogoCache.debugLoader = (url) async =>
        File('$_assets/${Uri.parse(url).pathSegments.last}').readAsBytesSync();
  });
  tearDown(() => LogoCache.debugLoader = null);

  Future<AppState> start(WidgetTester tester, {required bool source}) async {
    FormFactor.isTv = true;
    addTearDown(() => FormFactor.isTv = false);
    debugEngineFactory = FakeEngine.new;
    useDevice(tester, readme);
    final state = _state(withSource: source);
    if (source) {
      await state.addSource(
        const SourceInput(
          url: 'http://x.example/get.php?username=a&password=b',
        ),
      );
    }
    state.settings.setLanguage('en');
    await tester.pumpWidget(capturable(ZaplineApp(state: state), readme));
    await settle(tester);
    return state;
  }

  testWidgets('readme: welcome', (tester) async {
    await start(tester, source: false);
    await shot(tester, readme, 'welcome');
  });

  testWidgets('readme: guide and films', (tester) async {
    final state = await start(tester, source: true);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);

    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => GuideScreen(state: state, channels: state.channels()),
      ),
    );
    await settle(tester);
    // Onto the match, on the second channel.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    await _images(tester);
    await shot(tester, readme, 'guide');
    nav.pop();
    await settle(tester);

    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => VodScreen(state: state, kind: VodKind.shows),
      ),
    );
    await settle(tester);
    await _images(tester);
    await shot(tester, readme, 'series');
  });
}
