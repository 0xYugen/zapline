import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../input_mode.dart';
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

  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  /// Focus that came from the mouse: don't auto-scroll, or the list would
  /// slide away under the pointer.
  bool _pointerFocus = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _ownNode?.dispose();
    super.dispose();
  }

  void _focusFromPointer() {
    if (_node.hasFocus) return;
    _pointerFocus = true;
    _node.requestFocus();
  }

  static final _selectKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.gameButtonA,
  };

  /// When Select went down on this card; `null` if it did not, so a release
  /// carried over from the previous screen never activates it.
  DateTime? _downAt;
  bool _longFired = false;

  /// Fires the long press after a hold even when the remote sends no key
  /// repeats while OK is held (Fire TV remotes, some Bluetooth ones).
  Timer? _holdTimer;
  static const _holdTime = Duration(milliseconds: 550);

  void _fireLong() {
    _holdTimer?.cancel();
    if (_downAt == null || _longFired || !mounted) return;
    _longFired = true;
    widget.onLongPress?.call();
  }

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
        _holdTimer?.cancel();
        _holdTimer = Timer(_holdTime, _fireLong);
      case KeyRepeatEvent():
        // The platform only starts repeating after its own hold delay, so
        // the first repeat already means "held".
        _fireLong();
      case KeyUpEvent():
        _holdTimer?.cancel();
        if (_downAt != null && !_longFired) widget.onPressed();
        _downAt = null;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // Touch has no hover or D-pad: a highlight would only stick to the last
    // tapped card.
    final lit = _focused && !InputMode.instance.touch;
    final bg = lit
        ? ZaplineColors.focus
        : (widget.selected ? ZaplineColors.surfaceHigh : ZaplineColors.surface);
    final fg = lit ? ZaplineColors.onFocus : ZaplineColors.text;

    final longPressMode = widget.onLongPress != null;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        focusNode: _node,
        // Follow real focus rather than onShowFocusHighlight: Flutter's
        // highlight mode can stay in "touch" on Android TV, which would hide
        // the only cue a remote user has.
        onFocusChange: (v) {
          setState(() => _focused = v);
          final fromPointer = _pointerFocus;
          _pointerFocus = false;
          if (v) {
            widget.onFocused?.call();
            // Scroll just enough to show the whole card: centring it pushed
            // the first rows half off screen, which also broke D-pad Left
            // (no menu item at the same height to move to).
            // On a cold start focus can arrive before the window has a size;
            // scrolling into a zero-height viewport would shift the list.
            final viewport = Scrollable.maybeOf(context)?.position;
            if (!fromPointer &&
                viewport != null &&
                viewport.hasViewportDimension &&
                viewport.viewportDimension > 0) {
              for (final policy in const [
                ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                ScrollPositionAlignmentPolicy.keepVisibleAtStart,
              ]) {
                Scrollable.ensureVisible(
                  context,
                  alignmentPolicy: policy,
                  duration: const Duration(milliseconds: 120),
                );
              }
            }
          }
        },
        // In long-press mode activation happens on key release (_onKey).
        shortcuts: longPressMode
            ? const {}
            : const {
                SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.gameButtonA):
                    ActivateIntent(),
              },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onPressed(),
          ),
        },
        // Mouse: hovering moves the highlight, like the D-pad does.
        mouseCursor: SystemMouseCursors.click,
        child: MouseRegion(
          onEnter: (_) => _focusFromPointer(),
          child: GestureDetector(
            onTap: () {
              _focusFromPointer();
              widget.onPressed();
            },
            onLongPress: widget.onLongPress,
            onSecondaryTap: widget.onLongPress,
            child: AnimatedScale(
              scale: lit ? 1.02 : 1,
              duration: const Duration(milliseconds: 100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: Border.all(
                    color: lit ? ZaplineColors.focusBorder : Colors.transparent,
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
      ),
    );
  }
}
