import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/screens/filters_screen.dart';

import 'helpers.dart';

void main() {
  Future<AppState> state() async {
    final s = fakeState(
      count: 8,
      groups: ['IT | Rai', 'IT | Sport', 'UK | News', 'XXX Adult'],
    );
    await s.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    return s;
  }

  Future<void> open(WidgetTester tester, AppState s) async {
    tester.view
      ..physicalSize = const Size(412, 915) * 2.625
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ZaplineApp(state: s));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold).first)).push(
      MaterialPageRoute<void>(
        builder: (_) => FiltersScreen(state: s, sourceId: s.sources.single.id),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Italian only, undo, adult switch', (tester) async {
    final s = await state();
    await open(tester, s);
    expect(find.text("You'll see 8 channels in 4 groups"), findsOneWidget);

    await tester.tap(find.text('Italian channels only'));
    await tester.pumpAndSettle();
    expect(s.channels().map((c) => c.groupTitle).toSet(), {
      'IT | Rai',
      'IT | Sport',
    });
    expect(find.text("You'll see 4 channels in 2 groups"), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(s.channels(), hasLength(8));

    await tester.tap(find.text('Hide adult content'));
    await tester.pumpAndSettle();
    expect(s.channels().where((c) => c.groupTitle == 'XXX Adult'), isEmpty);
  });

  testWidgets('a country page switches its groups', (tester) async {
    final s = await state();
    await open(tester, s);
    await tester.ensureVisible(find.text('United Kingdom'));
    await tester.tap(find.text('United Kingdom'));
    await tester.pumpAndSettle();
    expect(find.text('UK | News'), findsOneWidget);
    await tester.tap(find.text('UK | News'));
    await tester.pumpAndSettle();
    expect(s.channels().where((c) => c.groupTitle == 'UK | News'), isEmpty);
    expect(find.text('UK | News hidden'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      s.channels().where((c) => c.groupTitle == 'UK | News'),
      hasLength(2),
    );
  });
}
