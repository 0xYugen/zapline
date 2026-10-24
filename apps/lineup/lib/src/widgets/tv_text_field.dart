import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a single-line text field so D-pad Up/Down leave it.
///
/// Flutter's text fields consume arrow keys for cursor movement, which traps
/// focus on a TV remote that has no Tab key. Left/Right still move the
/// cursor.
class TvTextField extends StatelessWidget {
  const TvTextField({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final scope = FocusScope.of(context);
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          scope.focusInDirection(TraversalDirection.down) || scope.nextFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          scope.focusInDirection(TraversalDirection.up) ||
              scope.previousFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
