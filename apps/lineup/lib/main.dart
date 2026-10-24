import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lineup_data/lineup_data.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app_state.dart';
import 'src/screens/add_source_screen.dart';
import 'src/screens/channels_screen.dart';
import 'src/theme.dart';
import 'src/widgets/channel_logo.dart';

/// Development only: add this source at startup when none exists, e.g.
/// `--dart-define=LINEUP_DEV_SOURCE=http://localhost:8099/live/demo/demo/1.ts`
const _devSource = String.fromEnvironment('LINEUP_DEV_SOURCE');

/// Development only: open the first channel as soon as the list appears.
const _devAutoplay = bool.fromEnvironment('LINEUP_DEV_AUTOPLAY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // libmpv is bundled only where MpvEngine is the default (desktop, iOS).
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
    MediaKit.ensureInitialized();
  }
  // Bounded image memory: logo-heavy lists on 1-2 GB TV sticks.
  PaintingBinding.instance.imageCache
    ..maximumSize = 400
    ..maximumSizeBytes = 48 << 20;
  await LogoCache.init(await getApplicationCacheDirectory());
  final dir = await getApplicationSupportDirectory();
  final dbPath = '${dir.path}${Platform.pathSeparator}lineup.db';
  final state = AppState(
    LineupDatabase.open(dbPath),
    syncRunner: isolateSyncRunner(dbPath),
  );
  if (_devSource.isNotEmpty && state.sources.isEmpty) {
    state
        .addSource(SourceInput(url: _devSource))
        .then(
          (_) {},
          onError: (Object e) => debugPrint('LINEUP_DEV_SOURCE failed: $e'),
        );
  } else {
    // Startup shows cached data immediately; stale sources refresh behind it.
    state.refreshStale();
  }
  runApp(LineupApp(state: state, autoplayFirst: _devAutoplay));
}

class LineupApp extends StatelessWidget {
  const LineupApp({super.key, required this.state, this.autoplayFirst = false});

  final AppState state;
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
        listenable: state,
        builder: (context, _) => state.isEmpty
            ? AddSourceScreen(state: state)
            : ChannelsScreen(state: state, autoplayFirst: autoplayFirst),
      ),
    );
  }
}
