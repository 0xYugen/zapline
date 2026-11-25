import 'package:flutter/widgets.dart';

/// Whether the tab around a widget is the one on screen. Hidden tabs stop
/// following the app state, so a change doesn't rebuild (and query for)
/// every tab, and catch up as soon as they show again.
class TabVisibility extends InheritedWidget {
  const TabVisibility({super.key, required this.active, required super.child});

  final bool active;

  /// `true` outside any tab (screens pushed over the tabs).
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabVisibility>()?.active ??
      true;

  @override
  bool updateShouldNotify(TabVisibility old) => old.active != active;
}

/// A [ListenableBuilder] that listens only while its tab is on screen.
class TabListenableBuilder extends StatelessWidget {
  const TabListenableBuilder({
    super.key,
    required this.listenable,
    required this.builder,
  });

  final Listenable listenable;
  final TransitionBuilder builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // The same builder either way, so nothing below loses its state.
    listenable: TabVisibility.of(context) ? listenable : _never,
    builder: builder,
  );
}

/// Never changes.
const Listenable _never = _Never();

class _Never implements Listenable {
  const _Never();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
