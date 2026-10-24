import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/screens/guide_mapping_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('one channel at a time, recognised by what airs now', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(412, 915) * 2.625
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final s = fakeState(count: 5, unmatched: {3, 4});
    await s.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    expect(s.channelsNeedingGuide(s.sources.single.id), hasLength(2));
    await tester.pumpWidget(ZaplineApp(state: s));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold).first)).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GuideMappingScreen(state: s, sourceId: s.sources.single.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Channel 1 of 2 without a guide'), findsOneWidget);
    expect(find.text('Channel 3 Extra'), findsOneWidget);
    expect(find.textContaining('Now: Show 3.0'), findsOneWidget);
    await tester.tap(find.text('Channel 3').first);
    await tester.pumpAndSettle();

    // The next one; this time it has no guide at all.
    expect(find.text('Channel 4 Extra'), findsOneWidget);
    await tester.tap(find.text('No guide'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(s.channelsNeedingGuide(s.sources.single.id), isEmpty);
    final (now, _) = s.nowNext(
      s.channels().firstWhere((c) => c.name == 'Channel 3 Extra'),
    );
    expect(now?.title, 'Show 3.0');
  });
}
