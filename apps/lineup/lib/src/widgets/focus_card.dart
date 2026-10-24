import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A D-pad friendly tile: highlights and grows slightly when focused, and
/// activates on Select/Enter, gamepad A, or a tap/click.
class FocusCard extends StatefulWidget {
  const FocusCard({
    super.key,
    required this.child,
    required this.onPressed,
    this.autofocus = false,
    this.selected = false,
    this.focusNode,
    this.onFocused,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.radius = 14,
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool autofocus;

  /// Persistent highlight (e.g. the current group) shown when not focused.
  final bool selected;
  final FocusNode? focusNode;
  final VoidCallback? onFocused;
  final EdgeInsets padding;
  final double radius;

  @override
  State<FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends State<FocusCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bg = _focused
        ? LineupColors.focus
        : (widget.selected ? LineupColors.surfaceHigh : LineupColors.surface);
    final fg = _focused ? LineupColors.onFocus : LineupColors.text;

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onShowFocusHighlight: (v) {
        setState(() => _focused = v);
        if (v) {
          widget.onFocused?.call();
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 120),
          );
        }
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onPressed(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _focused ? 1.02 : 1,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(
                color: _focused ? LineupColors.focusBorder : Colors.transparent,
                width: 3,
              ),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg),
              child: IconTheme.merge(
                data: IconThemeData(color: fg),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
