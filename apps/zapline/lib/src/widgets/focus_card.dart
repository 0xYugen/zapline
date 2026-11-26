import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../input_mode.dart';
import '../theme.dart';

/// Whether the card around a widget is lit (focused): accents then need
/// [ZaplineColors.accentOnLight], the light accent would vanish.
class Lit extends InheritedWidget {
  const Lit({super.key, required this.lit, required super.child});

  final bool lit;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Lit>()?.lit ?? false;

  /// The accent colour readable here.
  static Color accent(BuildContext context) =>
      of(context) ? ZaplineColors.accentOnLight : ZaplineColors.accent;

  @override
  bool updateShouldNotify(Lit old) => old.lit != lit;
}

/// Keys held down to open something, ignored by cards until released.
final _held = <LogicalKeyboardKey>{};

/// Makes cards ignore [keys] until they are released: a key held to open
/// something (OK held for the options) keeps sending presses, which would
/// otherwise activate whatever the new panel focuses first, again and
/// again.
void swallowHeldKey(Set<LogicalKeyboardKey> keys) {
  final pressed = HardwareKeyboard.instance.logicalKeysPressed;
  final held = keys.where(pressed.contains).toSet();
  if (held.isEmpty) return;
  _held.addAll(held);
  late final bool Function(KeyEvent) release;
  release = (e) {
    if (e is KeyUpEvent && _held.contains(e.logicalKey)) {
      // After this release has reached the cards, which ignore it too.
      scheduleMicrotask(() {
        _held.remove(e.logicalKey);
        if (_held.isEmpty) HardwareKeyboard.instance.removeHandler(release);
      });
    }
    return false;
  };
  HardwareKeyboard.instance.addHandler(release);
}

/// When focus last moved to a card; moves closer together than a frame or
/// two mean a key is held down.
DateTime _lastReveal = DateTime(0);

/// Scrolls every list around [context] just enough to show it whole: no
/// move when it already shows, else its edge to the list's nearest edge.
/// While a key is held the lists jump instead of animating, so they keep up
/// with the focus instead of queueing animations.
void revealFocused(BuildContext context) {
  var object = context.findRenderObject();
  if (object == null || !object.attached) return;
  final now = DateTime.now();
  final held = now.difference(_lastReveal) < const Duration(milliseconds: 160);
  _lastReveal = now;
  var scrollable = Scrollable.maybeOf(context);
  while (scrollable != null) {
    final position = scrollable.position;
    // On a cold start focus can arrive before the window has a size;
    // scrolling into a zero-height viewport would shift the list.
    if (!position.hasViewportDimension || position.viewportDimension <= 0) {
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(object);
    if (viewport == null || object == null) return;
    final start = viewport.getOffsetToReveal(object, 0).offset;
    final end = viewport.getOffsetToReveal(object, 1).offset;
    final current = position.pixels;
    // Revealing at the start needs the larger offset when the card is
    // above; at the end, the smaller when it's below.
    final target = current > start
        ? start
        : current < end
        ? end
        : null;
    if (target != null) {
      final to = target.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (held) {
        position.jumpTo(to);
      } else {
        position.animateTo(
          to,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    }
    // An outer list (a row of posters in a page) shows the inner one.
    object = scrollable.context.findRenderObject();
    scrollable = Scrollable.maybeOf(scrollable.context);
  }
}

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
    this.quiet = false,
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

  /// No card drawn until focused or selected (a menu's entries).
  final bool quiet;
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

  /// Animated once first focused: a guide shows hundreds of cards, and an
  /// animation controller each would cost a TV stick on every scroll.
  bool _animated = false;

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
    if (_held.contains(e.logicalKey)) return KeyEventResult.handled;
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
        : widget.selected
        ? ZaplineColors.surfaceHigh
        : widget.quiet
        ? Colors.transparent
        : ZaplineColors.surface;
    final fg = lit ? ZaplineColors.onFocus : ZaplineColors.text;

    // Lit: light, lifted by a shadow (only the focused card has one, so a
    // guide of hundreds of cards draws one shadow).
    final decoration = BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(widget.radius),
      border: Border.all(
        color: lit ? ZaplineColors.focusBorder : Colors.transparent,
        width: 2,
      ),
      boxShadow: lit
          ? const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ]
          : null,
    );
    final content = Lit(
      lit: lit,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: IconTheme.merge(
          data: IconThemeData(color: fg),
          child: widget.child,
        ),
      ),
    );

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
          if (v && !_animated) {
            // Built unlit with its animations first, then lit: the
            // highlight animates in as before.
            setState(() => _animated = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _node.hasFocus) setState(() => _focused = true);
            });
          } else {
            setState(() => _focused = v);
          }
          final fromPointer = _pointerFocus;
          _pointerFocus = false;
          if (v) {
            widget.onFocused?.call();
            // Scroll just enough to show the whole card: centring it pushed
            // the first rows half off screen, which also broke D-pad Left
            // (no menu item at the same height to move to).
            // On a cold start focus can arrive before the window has a size;
            // scrolling into a zero-height viewport would shift the list.
            if (!fromPointer) revealFocused(context);
          }
        },
        // In long-press mode activation happens on key release (_onKey).
        shortcuts: longPressMode
            ? const {}
            // Once per press: a held key repeating would activate the card
            // again and again.
            : const {
                SingleActivator(
                  LogicalKeyboardKey.select,
                  includeRepeats: false,
                ): ActivateIntent(),
                SingleActivator(
                  LogicalKeyboardKey.enter,
                  includeRepeats: false,
                ): ActivateIntent(),
                SingleActivator(
                  LogicalKeyboardKey.space,
                  includeRepeats: false,
                ): ActivateIntent(),
                SingleActivator(
                  LogicalKeyboardKey.gameButtonA,
                  includeRepeats: false,
                ): ActivateIntent(),
              },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (_held.isEmpty) widget.onPressed();
              return null;
            },
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
            // Read out as a button, with its text as the label.
            child: Semantics(
              button: true,
              selected: widget.selected,
              child: _animated
                  ? AnimatedScale(
                      scale: lit ? 1.04 : 1,
                      duration: const Duration(milliseconds: 100),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        padding: widget.padding,
                        decoration: decoration,
                        child: content,
                      ),
                    )
                  : Container(
                      padding: widget.padding,
                      decoration: decoration,
                      child: content,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
