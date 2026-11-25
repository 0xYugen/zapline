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
    return super.open(url, headers: headers, start: start);
  }

  @override
  Stream<String> get errors => _errors.stream;
}

Future<(AppState, _Engine)> _player(
  WidgetTester tester, {
  int count = 20,
  int channels = 20,
}) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final engine = _Engine();
  debugEngineFactory = () => engine;
  addTearDown(() => debugEngineFactory = null);
  final state = fakeState(count: count);
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
        channels: state.channels().sublist(0, channels),
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
}
