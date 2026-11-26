import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/screens/guide_screen.dart';
import 'package:zapline/src/widgets/focus_card.dart';
import 'package:zapline_data/zapline_data.dart';

import 'helpers.dart';

/// A large playlist loads off screen: the TV home shows a spinner, then
/// the grid, which takes focus as it would have at once.
void main() {
  testWidgets('a large list loads off screen, then the grid has focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = ZaplineDatabase.inMemory();
    var jobs = 0;
    final state = fakeState(
      count: 2500,
      database: db,
      // Another isolate, as far as the screens can tell: the answer
      // comes later.
      background: <R>(job) async {
        jobs++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return job(db);
      },
    );
    // Real time: the import yields to the event loop between batches.
    await tester.runAsync(
      () => state.addSource(
        const SourceInput(
          url: 'http://x.example/get.php?username=a&password=b',
        ),
      ),
    );
    await tester.pumpWidget(ZaplineApp(state: state));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GuideGrid), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(jobs, 1);
    expect(find.byType(GuideGrid), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused?.findAncestorWidgetOfExactType<FocusCard>(), isNotNull);
    expect(find.text('Channel 1'), findsOneWidget);
    // Loaded once: the screens share it.
    final ready = state.channelsReady(null);
    expect(ready, isNotNull);
    expect(identical(ready, state.channels()), isTrue);
    expect(ready!.length, greaterThan(2400));
    expect(jobs, 1);
  });
}
