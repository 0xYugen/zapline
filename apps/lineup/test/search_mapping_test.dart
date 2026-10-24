import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lineup/main.dart';
import 'package:lineup/src/app_state.dart';

import 'helpers.dart';

Future<AppState> _ready(
  WidgetTester tester, {
  Set<int> unmatched = const {},
}) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  final state = fakeState(count: 12, unmatched: unmatched);
  await state.addSource(
    const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
  );
  await tester.pumpWidget(LineupApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('search finds channels by prefix', (tester) async {
    await _ready(tester);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'chan 1');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    // "Channel 1", "Channel 10", "Channel 11", "Channel 12".
    expect(find.textContaining(RegExp(r'^Channel 1\d?$')), findsNWidgets(4));
  });

  testWidgets('unmatched channels can be linked to a guide channel', (
    tester,
  ) async {
    final state = await _ready(tester, unmatched: {5});
    expect(state.unmatchedChannels(state.sources.single.id), hasLength(1));

    await tester.tap(find.text('Sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fix TV guide (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Suggestions for Channel 5 Extra'), findsOneWidget);

    await tester.tap(find.text('Channel 5').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('now uses the guide of Channel 5'),
      findsOneWidget,
    );
    expect(state.unmatchedChannels(state.sources.single.id), isEmpty);
    expect(state.coverage(state.sources.single.id).matched, 12);
  });
}
