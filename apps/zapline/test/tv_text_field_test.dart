import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/input_mode.dart';
import 'package:zapline/src/widgets/tv_text_field.dart';

void main() {
  setUp(() => TvTextField.keyboardOnSelect = true);
  tearDown(() => TvTextField.keyboardOnSelect = false);

  testWidgets('with the remote, the keyboard waits for OK', (tester) async {
    InputMode.instance.attach();
    final first = FocusNode();
    addTearDown(first.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextButton(
                focusNode: first,
                onPressed: () {},
                child: const Text('above'),
              ),
              TvTextField(builder: (readOnly) => TextField(readOnly: readOnly)),
              TextButton(onPressed: () {}, child: const Text('below')),
            ],
          ),
        ),
      ),
    );
    first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    TextField field() => tester.widget<TextField>(find.byType(TextField));
    expect(tester.testTextInput.isVisible, isFalse);
    expect(field().readOnly, isTrue, reason: 'passing by stays quiet');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(field().readOnly, isFalse);
    expect(tester.testTextInput.isVisible, isTrue);

    // Leaving the field makes it quiet again.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(field().readOnly, isTrue);
  });
}
