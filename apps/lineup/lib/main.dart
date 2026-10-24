import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'src/library.dart';
import 'src/screens/add_source_screen.dart';
import 'src/screens/channels_screen.dart';
import 'src/theme.dart';

/// Development only: load this source at startup, e.g.
/// `--dart-define=LINEUP_DEV_SOURCE=http://localhost:8099/get.php?username=demo&password=demo`
const _devSource = String.fromEnvironment('LINEUP_DEV_SOURCE');

/// Development only: open the first channel as soon as the list appears.
const _devAutoplay = bool.fromEnvironment('LINEUP_DEV_AUTOPLAY');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final library = Library();
  if (_devSource.isNotEmpty) {
    library
        .load(SourceInput(url: _devSource))
        .catchError((Object e) => debugPrint('LINEUP_DEV_SOURCE failed: $e'));
  }
  runApp(LineupApp(library: library, autoplayFirst: _devAutoplay));
}

class LineupApp extends StatelessWidget {
  const LineupApp({
    super.key,
    required this.library,
    this.autoplayFirst = false,
  });

  final Library library;
  final bool autoplayFirst;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      // TV remotes send Select; make it behave like Enter everywhere.
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _recoverLostFocus,
        child: _app(),
      ),
    );
  }

  /// On a remote, focus lost after a screen change leaves the user stuck:
  /// arrow keys do nothing when no element is focused. Pick the first one.
  static KeyEventResult _recoverLostFocus(FocusNode _, KeyEvent e) {
    final arrows = {
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    };
    final primary = FocusManager.instance.primaryFocus;
    if (e is KeyDownEvent &&
        arrows.contains(e.logicalKey) &&
        primary is FocusScopeNode &&
        primary.focusedChild == null) {
      primary.nextFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _app() {
    return MaterialApp(
      title: 'Lineup',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: library,
        builder: (context, _) => library.isEmpty
            ? AddSourceScreen(library: library)
            : ChannelsScreen(library: library, autoplayFirst: autoplayFirst),
      ),
    );
  }
}
