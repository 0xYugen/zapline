import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:zapline_data/zapline_data.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app_state.dart';
import 'src/input_mode.dart';
import 'src/layout.dart';
import 'src/mobile/mobile_home.dart';
import 'src/secret_store.dart';
import 'src/screens/add_source_screen.dart';
import 'src/screens/channels_screen.dart';
import 'src/theme.dart';
import 'src/widgets/channel_logo.dart';

/// Development only: add this source at startup when none exists, e.g.
/// `--dart-define=ZAPLINE_DEV_SOURCE=http://localhost:8099/live/demo/demo/1.ts`
const _devSource = String.fromEnvironment('ZAPLINE_DEV_SOURCE');

/// Development only: open the first channel as soon as the list appears.
const _devAutoplay = bool.fromEnvironment('ZAPLINE_DEV_AUTOPLAY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/inter/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], text);
  });
  await FormFactor.detectTv();
  // Draw behind the system bars; screens keep content inside safe areas.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(systemBarsStyle);
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
  final dbPath = '${dir.path}${Platform.pathSeparator}zapline.db';
  final db = ZaplineDatabase.open(dbPath);
  late final AppState state;
  state = AppState(
    db,
    syncRunner: isolateSyncRunner(
      dbPath,
      guideDays: () => state.settings.guideDays,
    ),
    secrets: const KeychainSecretStore(),
    guideFetcher: ChannelGuideFetcher(db),
  );
  // Show the UI at once; the keystore can take seconds on first use and
  // passwords are only needed when syncing (which waits for them).
  runApp(ZaplineApp(state: state, autoplayFirst: _devAutoplay));
  await state.loadSecrets();
  if (_devSource.isNotEmpty && state.sources.isEmpty) {
    state
        .addSource(SourceInput(url: _devSource))
        .then(
          (_) {},
          onError: (Object e) => debugPrint('ZAPLINE_DEV_SOURCE failed: $e'),
        );
  } else {
    // Startup shows cached data immediately; stale sources refresh behind it.
    state.refreshStale();
  }
}

class ZaplineApp extends StatefulWidget {
  const ZaplineApp({
    super.key,
    required this.state,
    this.autoplayFirst = false,
  });

  final AppState state;
  final bool autoplayFirst;

  @override
  State<ZaplineApp> createState() => _ZaplineAppState();
}

class _ZaplineAppState extends State<ZaplineApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _backStack = BackStackObserver();

  @override
  void initState() {
    super.initState();
    InputMode.instance.attach();
  }

  void _back() => _navigator.currentState?.maybePop();

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
        child: Listener(
          // Pointer events steer the input mode; the mouse back button
          // goes back like Esc and the remote's Back key.
          onPointerHover: InputMode.instance.onPointer,
          onPointerDown: (e) {
            InputMode.instance.onPointer(e);
            if (e.buttons & kBackMouseButton != 0) _back();
          },
          child: _app(),
        ),
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
    final state = widget.state;
    return MaterialApp(
      title: 'Zapline',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: _navigator,
      navigatorObservers: [_backStack],
      // Desktop has no Back key: Esc and the browser back key go back. The
      // Android Back key is left to the system, which pops the route itself;
      // handling it here too would pop twice and close the app on Android 16.
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
        const SingleActivator(LogicalKeyboardKey.browserBack):
            const BackIntent(),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        BackIntent: CallbackAction<BackIntent>(onInvoke: (_) => _back()),
      },
      // Content stays clear of status bar, navigation bar and cutouts; on
      // TVs the insets are zero. Phones get app bars with their own back
      // arrow instead of the floating one.
      builder: (context, child) => ColoredBox(
        color: ZaplineColors.ground,
        child: SafeArea(
          child: Stack(
            children: [
              child!,
              if (!context.isPhone)
                _PointerBackButton(depth: _backStack.depth, onPressed: _back),
            ],
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (state.isEmpty) return AddSourceScreen(state: state);
          if (context.isPhone) return MobileHome(state: state);
          return ChannelsScreen(
            state: state,
            autoplayFirst: widget.autoplayFirst,
          );
        },
      ),
    );
  }
}

/// Back arrow for mouse and touch users, shown only in pointer mode and when
/// there is somewhere to go back to. Never focusable, so the D-pad skips it.
class _PointerBackButton extends StatelessWidget {
  const _PointerBackButton({required this.depth, required this.onPressed});

  final ValueListenable<int> depth;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([depth, InputMode.instance]),
      builder: (context, _) {
        if (depth.value <= 0 || !InputMode.instance.pointer) {
          return const SizedBox.shrink();
        }
        return Positioned(
          top: 12,
          left: 12,
          child: ExcludeFocus(
            child: Material(
              color: ZaplineColors.surfaceHigh.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              // No tooltip: this sits above the navigator's Overlay, which
              // tooltips need.
              child: IconButton(
                iconSize: 28,
                color: ZaplineColors.text,
                onPressed: onPressed,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  semanticLabel: 'Back',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
