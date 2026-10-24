import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/widgets/focus_card.dart';
import 'package:zapline_data/zapline_data.dart';

import 'helpers.dart';

void main() {
  testWidgets(
    'first run shows the add-source screen and detects Xtream links',
    (tester) async {
      await tester.pumpWidget(ZaplineApp(state: fakeState()));
      expect(find.text('Add your first source'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        'http://panel.example:8080/get.php?username=alice&password=x',
      );
      await tester.pump();
      expect(
        find.textContaining('Xtream login detected: alice'),
        findsOneWidget,
      );
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'username/password fields hide once credentials are detected',
      );

      // D-pad Down must leave the text field (TV remotes have no Tab key).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(focused.findAncestorWidgetOfExactType<FocusCard>(), isNotNull);
    },
  );

  test('SourceInput builds the right record', () {
    final x = const SourceInput(
      url: 'http://p.example:8080/get.php?username=a&password=b',
    ).toRecord('1');
    expect(x.kind, SourceKind.xtream);
    expect(x.url, 'http://p.example:8080');
    expect(x.username, 'a');

    final m = const SourceInput(url: 'http://p.example/list.m3u').toRecord('2');
    expect(m.kind, SourceKind.m3u);

    final manual = const SourceInput(
      url: 'p.example:8080',
      username: 'u',
      password: 'p',
    ).toRecord('3');
    expect(manual.kind, SourceKind.xtream);
    expect(manual.name, 'p.example');
  });
}
