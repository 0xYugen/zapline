import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A D-pad friendly tile: highlights and grows slightly when focused, and
/// activates on Select/Enter, gamepad A, or a tap/click.
///
/// With [onLongPress], holding Select (or pressing the Menu key, a long tap
/// or a right click) triggers it instead; a short press then activates on
/// key release, as TV launchers do.
class FocusCard extends StatefulWidget {
  const FocusCard({
    super.key,
    required this.child,
    required this.onPressed,
    this.autofocus = false,
    this.selected = false,
    this.focusNode,
    this.onFocused,
    this.onLongPress,
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
  final VoidCallback? onLongPress;
  final EdgeInsets padding;
  final double radius;

  @override
  State<FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends State<FocusCard> {
  bool _focused = false;

  static final _selectKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  };

  /// When Select went down on this card; `null` if it did not, so a release
  /// carried over from the previous screen never activates it.
  DateTime? _downAt;
  bool _longFired = false;

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final onLong = widget.onLongPress;
    if (onLong == null) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.contextMenu && e is KeyDownEvent) {
      onLong();
      return KeyEventResult.handled;
    }
    if (!_selectKeys.contains(e.logicalKey)) return KeyEventResult.ignored;
    switch (e) {
      case KeyDownEvent():
        _downAt = DateTime.now();
        _longFired = false;
      case KeyRepeatEvent():
        // The platform only starts repeating after its own hold delay, so
        // the first repeat already means "held".
        if (_downAt != null && !_longFired) {
          _longFired = true;
          onLong();
        }
      case KeyUpEvent():
        if (_downAt != null && !_longFired) widget.onPressed();
        _downAt = null;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final bg = _focused
        ? LineupColors.focus
        : (widget.selected ? LineupColors.surfaceHigh : LineupColors.surface);
    final fg = _focused ? LineupColors.onFocus : LineupColors.text;

    final longPressMode = widget.onLongPress != null;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        // Follow real focus rather than onShowFocusHighlight: Flutter's
        // highlight mode can stay in "touch" on Android TV, which would hide
        // the only cue a remote user has.
        onFocusChange: (v) {
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
        // In long-press mode activation happens on key release (_onKey).
        shortcuts: longPressMode
            ? const {}
            : const {
                SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.gameButtonA):
                    ActivateIntent(),
              },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onPressed(),
          ),
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          onSecondaryTap: widget.onLongPress,
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
                  color: _focused
                      ? LineupColors.focusBorder
                      : Colors.transparent,
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
      ),
    );
  }
}
