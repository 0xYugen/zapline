import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lineup/main.dart';
import 'package:lineup/src/library.dart';
import 'package:lineup/src/widgets/focus_card.dart';
import 'package:lineup_core/lineup_core.dart';

class _FakeLibrary extends Library {
  @override
  Future<void> load(SourceInput input) async {
    sourceName = 'test';
    channels = [
      for (var i = 1; i <= 20; i++)
        Channel(
          sourceId: 's',
          id: '$i',
          name: 'Channel $i',
          number: i,
          groupTitle: i.isEven ? 'Even' : 'Odd',
          streamUrl: Uri.parse('http://x.example/$i.ts'),
        ),
    ];
    groups = ['Odd', 'Even'];
    notifyListeners();
  }
}

String? _focusedLabel() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return null;
  final card = ctx.findAncestorWidgetOfExactType<FocusCard>();
  if (card == null) return null;
  final texts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Text && w.data != null) texts.add(w.data!);
    e.visitChildren(visit);
  }

  (ctx as Element).visitChildren(visit);
  return texts.join(' ');
}

void main() {
  testWidgets('after connecting, the first channel has focus and D-pad moves', (
    tester,
  ) async {
    final lib = _FakeLibrary();
    await tester.pumpWidget(LineupApp(library: lib));
    await tester.enterText(
      find.byType(TextField).first,
      'http://x.example/get.php?username=a&password=b',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.text('Channel 1'), findsOneWidget);
    expect(_focusedLabel(), contains('Channel 1'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedLabel(), contains('Channel 2'));
  });
}
