import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lineup/main.dart';
import 'package:lineup/src/library.dart';
import 'package:lineup/src/widgets/focus_card.dart';

void main() {
  testWidgets(
    'first run shows the add-source screen and detects Xtream links',
    (tester) async {
      await tester.pumpWidget(LineupApp(library: Library()));
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
}
