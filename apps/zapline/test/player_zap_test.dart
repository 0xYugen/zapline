import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/l10n.dart';
import 'package:zapline/src/playback/playback_engine.dart';
import 'package:zapline/src/screens/player_screen.dart';
import 'package:zapline/src/theme.dart';

import '../tool/screenshots/shots.dart' show FakeEngine;
import 'helpers.dart';

/// Remembers what it was asked to open; can fail every stream.
class _Engine extends FakeEngine {
  final opened = <String>[];
  final _errors = StreamController<String>.broadcast();
  bool fail = false;

  /// Streams that play sound but show no picture.
  final black = <String>{};

  /// Streams that never start.
  final hang = <String>{};

  @override
  Duration get currentPosition =>
      opened.isNotEmpty && hang.contains(opened.last)
      ? Duration.zero
      : super.currentPosition;

  /// Streams with a picture but no sound the device plays.
  final mute = <String>{};

  @override
  Future<bool?> hasSound() async =>
      opened.isEmpty || !mute.contains(opened.last);

  /// Streams that start, then stall at once.
  final stalling = <String>{};
  final _stalls = StreamController<bool>.broadcast();

  @override
  Stream<bool> get buffering => _stalls.stream;

  /// Streams that play neither sound nor picture.
  final silent = <String>{};

  @override
  bool get hasPicture =>
      opened.isEmpty ||
      !(black.contains(opened.last) || silent.contains(opened.last));

  @override
  bool get playsNothing => opened.isNotEmpty && silent.contains(opened.last);

  @override
  Future<void> open(
    Uri url, {
    Map<String, String> headers = const {},
    Duration start = Duration.zero,
  }) async {
    opened.add(url.pathSegments.last);
    if (fail) {
      scheduleMicrotask(() => _errors.add('Source error'));
      return;
    }
    if (hang.contains(url.pathSegments.last)) return;
    await super.open(url, headers: headers, start: start);
    if (stalling.contains(url.pathSegments.last)) {
      // After the first position, as such streams do.
      Timer(const Duration(milliseconds: 50), () => _stalls.add(true));
    }
  }

  @override
  Stream<String> get errors => _errors.stream;
}

Future<(AppState, _Engine)> _player(
  WidgetTester tester, {
  int count = 20,
  int channels = 20,
  List<String>? names,
}) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final engine = _Engine();
  debugEngineFactory = () => engine;
  addTearDown(() => debugEngineFactory = null);
  final state = fakeState(count: count, names: names);
  await state.addSource(
    const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PlayerScreen(
        state: state,
        channels: state.channels().sublist(
          0,
          channels.clamp(0, state.channels().length),
        ),
        initialIndex: 0,
      ),
    ),
  );
  await tester.pump();
  return (state, engine);
}

Future<void> _ok(WidgetTester tester, {Duration hold = Duration.zero}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
  await tester.pump(hold);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
  await tester.pump();
}

void main() {
  testWidgets('keys pressed in a burst open only the channel stopped on', (
    tester,
  ) async {
    final (_, engine) = await _player(tester);
    expect(engine.opened, ['1.ts']);

    // The first press opens at once; the rest of the burst waits.
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(engine.opened, ['1.ts', '2.ts']);
    // The info bar already shows where the keys stopped.
    expect(find.text('Channel 6'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(engine.opened, ['1.ts', '2.ts', '6.ts']);
  });

  testWidgets('a number outside the list being watched finds the channel', (
    tester,
  ) async {
    // Watching a list of three: channel 12 is only among all channels.
    final (_, engine) = await _player(tester, channels: 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    // The number shows with the channel it will open.
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Channel 12'), findsOneWidget);
    // OK opens it without waiting.
    await _ok(tester);
    await tester.pump();
    expect(engine.opened.last, '12.ts');

    // 0 goes back to the channel before.
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(engine.opened.last, '1.ts');
  });

  testWidgets('a failing channel is tried again, then OK retries', (
    tester,
  ) async {
    final (_, engine) = await _player(tester);
    engine.fail = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(engine.opened, ['1.ts', '2.ts']);

    // Three more attempts, further and further apart, said on screen.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Reconnecting… (1 of 3)'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(engine.opened, ['1.ts', '2.ts', '2.ts', '2.ts', '2.ts']);
    expect(
      find.text('This channel is not available right now'),
      findsOneWidget,
    );

    engine.fail = false;
    await _ok(tester);
    await tester.pump();
    expect(engine.opened.last, '2.ts');
    expect(engine.opened.length, 6);
    expect(find.text('This channel is not available right now'), findsNothing);
  });

  testWidgets('holding OK opens the options, a short press the list', (
    tester,
  ) async {
    final (state, _) = await _player(tester);
    await _ok(tester, hold: const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Audio and subtitles'), findsOneWidget);

    // The dialog stays open after a favourite, showing the new state.
    await tester.tap(find.text('Add to favourites'));
    await tester.pumpAndSettle();
    expect(state.isFavourite(state.channels().first), isTrue);
    expect(find.text('Remove from favourites'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Audio and subtitles'), findsNothing);

    await _ok(tester);
    await tester.pumpAndSettle();
    // The channel list over the picture, on the current channel.
    expect(find.text('Channel 2'), findsOneWidget);
  });

  testWidgets('M mutes, + and - set the volume, kept for next time', (
    tester,
  ) async {
    final (state, engine) = await _player(tester);
    expect(engine.volume, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pump();
    expect(engine.volume, closeTo(0.9, 0.001));
    expect(state.settings.volume, 90);
    expect(find.text('90'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(engine.volume, 0);
    expect(find.text('Muted'), findsOneWidget);
    // Zapping keeps it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(seconds: 2));
    expect(state.settings.muted, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    expect(engine.volume, closeTo(0.95, 0.001));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('with the setting on, neighbours preload while zapping', (
    tester,
  ) async {
    final (state, engine) = await _player(tester);
    // Off by default: providers often allow one connection only.
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.preloaded, isNull);

    state.settings.preloadNeighbours = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 100));
    final (current, next) = engine.preloaded!;
    expect(current, 1);
    expect(
      [for (final (i, u) in next) (i, u.pathSegments.last)],
      [(0, '1.ts'), (2, '3.ts')],
    );

    // Watching, not zapping: they are let go.
    await tester.pump(const Duration(seconds: 26));
    expect(engine.preloaded!.$2, isEmpty);
  });

  testWidgets('a version with sound but no picture gives way to the next', (
    tester,
  ) async {
    final (state, engine) = await _player(
      tester,
      count: 4,
      names: ['Rai 1 HD', 'Rai 1 FHD', 'Rai 1 4K', 'Rai 2'],
    );
    // 4K first (3.ts), then FHD (2.ts): set before the check runs.
    engine.black.addAll(['3.ts', '2.ts']);
    expect(engine.opened, ['3.ts']);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 4));
    expect(engine.opened, ['3.ts', '2.ts']);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 4));
    expect(engine.opened, ['3.ts', '2.ts', '1.ts']);
    // HD shows a picture: the channel starts on it from now on.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 4));
    expect(engine.opened, hasLength(3));
    expect(state.channels().first.name, 'Rai 1 HD');
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('no sound and no picture counts as failed, even alone', (
    tester,
  ) async {
    final (_, engine) = await _player(tester);
    engine.silent.add('2.ts');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.opened, ['1.ts', '2.ts']);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    // Tried again, said on screen.
    expect(engine.opened, ['1.ts', '2.ts', '2.ts']);

    // Sound only on a channel with no other version: maybe a radio, kept.
    engine.silent.clear();
    engine.black.add('3.ts');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 10));
    expect(engine.opened.last, '3.ts');
    expect(engine.opened.where((u) => u == '3.ts'), hasLength(1));
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('a stream that starts and stalls each time ends in a message', (
    tester,
  ) async {
    final (_, engine) = await _player(tester);
    engine.stalling.add('2.ts');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
    // Once, then tried again once: not for ever.
    expect(engine.opened.where((u) => u == '2.ts'), hasLength(2));
    expect(
      find.text('This channel is not available right now'),
      findsOneWidget,
    );
  });

  testWidgets('a version stuck loading gives way in 6 s, and is remembered', (
    tester,
  ) async {
    final (state, engine) = await _player(
      tester,
      count: 3,
      names: ['Rai 2 HD', 'Rai 2 FHD', 'Rai 3'],
    );
    expect(engine.opened, ['2.ts']);
    engine.hang.add('2.ts');
    // Opened again so the hang applies from the start.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    // Keys close together (real time) open after the burst pause.
    await tester.pump(const Duration(milliseconds: 400));
    expect(engine.opened, ['2.ts', '3.ts', '2.ts']);
    await tester.pump(const Duration(seconds: 6));
    expect(engine.opened.last, '1.ts');
    // Plays well: from now on the channel is this version.
    await tester.pump(const Duration(seconds: 5));
    expect(state.channels().first.name, 'Rai 2 HD');
    final before = engine.opened.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(seconds: 1));
    expect(engine.opened.sublist(before), ['3.ts', '1.ts']);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('a picture without voice gives way to the next version', (
    tester,
  ) async {
    final (state, engine) = await _player(
      tester,
      count: 3,
      names: ['Rai 2 HD', 'Rai 2 FHD', 'Rai 3'],
    );
    engine.mute.add('2.ts');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 4));
    expect(engine.opened, ['2.ts', '1.ts']);
    await tester.pump(const Duration(seconds: 5));
    expect(state.channels().first.name, 'Rai 2 HD');
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('OK held with key repeats opens the options, nothing in them', (
    tester,
  ) async {
    await _player(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    // The remote keeps sending OK while it is held.
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Audio and subtitles'), findsOneWidget);
    // The first option (audio and subtitles) was not opened.
    expect(find.text('Audio'), findsNothing);
    // The next press works as usual: the first option opens.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Audio'), findsOneWidget);
  });
}
