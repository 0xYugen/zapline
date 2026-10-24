import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether the user is currently driving the app with a pointer (mouse,
/// touch) or with keys (remote, keyboard). Pointer-only affordances such as
/// on-screen back and paging buttons appear only in pointer mode, so the TV
/// interface stays clean and the D-pad never lands on them.
class InputMode extends ChangeNotifier {
  InputMode._();

  static final instance = InputMode._();

  /// Starts observing the keyboard. Idempotent; call when the app starts
  /// (the handler list can be reset, e.g. between widget tests).
  void attach() {
    HardwareKeyboard.instance
      ..removeHandler(_onKey)
      ..addHandler(_onKey);
    _set(false);
  }

  bool _pointer = false;
  bool get pointer => _pointer;

  void _set(bool value) {
    if (_pointer == value) return;
    _pointer = value;
    notifyListeners();
  }

  /// Call from a root [Listener] for every pointer event.
  void onPointer(PointerEvent e) {
    if (e.kind == PointerDeviceKind.mouse ||
        e.kind == PointerDeviceKind.touch ||
        e.kind == PointerDeviceKind.trackpad) {
      _set(true);
    }
  }

  static final _navigationKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.tab,
  };

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && _navigationKeys.contains(e.logicalKey)) {
      _set(false);
    }
    return false; // observe only
  }
}

/// Signals "go back one screen": Esc, the keyboard/remote back keys and the
/// mouse back button all map to it.
class BackIntent extends Intent {
  const BackIntent();
}

/// Tracks whether the navigator can go back, for the on-screen back button.
class BackStackObserver extends NavigatorObserver {
  final depth = ValueNotifier<int>(0);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      depth.value++;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      depth.value--;

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      depth.value--;
}
