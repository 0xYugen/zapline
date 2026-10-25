import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/widgets/focus_card.dart';

/// Holding OK opens a card's menu even on remotes that send no key
/// repeats while a key is held (Fire TV); a short press still activates.
void main() {
  Future<(List<String>, FocusNode)> card(WidgetTester tester) async {
    final events = <String>[];
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: FocusCard(
          focusNode: node,
          onPressed: () => events.add('press'),
          onLongPress: () => events.add('long'),
          child: const Text('Channel'),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    return (events, node);
  }

  testWidgets('held OK without repeats opens the menu', (tester) async {
    final (events, _) = await card(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(events, ['long']);
  });

  testWidgets('a short OK activates', (tester) async {
    final (events, _) = await card(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(seconds: 1));
    expect(events, ['press']);
  });
}
