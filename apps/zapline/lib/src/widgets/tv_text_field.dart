import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../input_mode.dart';

/// Wraps a single-line text field for the remote.
///
/// Flutter's text fields consume arrow keys for cursor movement, which traps
/// focus on a TV remote that has no Tab key: here Up/Down always leave the
/// field, while Left/Right still move the cursor.
///
/// On Android, focusing a field pops up the on-screen keyboard, so walking
/// past a form with the D-pad would open it at every field. With the remote
/// the field stays read-only until OK is pressed on it, like other TV apps;
/// mouse and touch edit straight away.
class TvTextField extends StatefulWidget {
  const TvTextField({super.key, required this.builder});

  /// Builds the text field; pass `readOnly` on to it.
  final Widget Function(bool readOnly) builder;

  /// Whether the keyboard waits for OK. Tests may turn it on.
  static bool keyboardOnSelect = !kIsWeb && Platform.isAndroid;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  bool _editing = false;

  bool get _readOnly =>
      TvTextField.keyboardOnSelect && !InputMode.instance.pointer && !_editing;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (_readOnly &&
        event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      // Rebuilding with readOnly off opens the keyboard on the focused field.
      setState(() => _editing = true);
      return KeyEventResult.handled;
    }
    if (TvTextField.keyboardOnSelect &&
        _editing &&
        event is KeyDownEvent &&
        key == LogicalKeyboardKey.select) {
      // The keyboard may have been closed with Back: OK brings it back.
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      return KeyEventResult.handled;
    }
    final scope = FocusScope.of(context);
    if (key == LogicalKeyboardKey.arrowDown) {
      scope.focusInDirection(TraversalDirection.down) || scope.nextFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      scope.focusInDirection(TraversalDirection.up) || scope.previousFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: InputMode.instance,
    builder: (context, _) => Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!focused && _editing) setState(() => _editing = false);
      },
      onKeyEvent: _onKey,
      child: widget.builder(_readOnly),
    ),
  );
}
