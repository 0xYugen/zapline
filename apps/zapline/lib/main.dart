import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:zapline_core/zapline_core.dart' show redactSecrets;
import 'package:zapline_data/zapline_data.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app_state.dart';
import 'src/cast/cast_link.dart';
import 'src/vod/vod_detail_screens.dart';
import 'src/keep_awake.dart';
import 'src/input_mode.dart';
import 'src/l10n.dart';
import 'src/layout.dart';
import 'src/mobile/mobile_home.dart';
import 'src/secret_store.dart';
import 'src/screens/add_source_screen.dart';
import 'src/screens/channels_screen.dart';
import 'src/screens/player_screen.dart';
import 'src/screens/settings_screen.dart';
import 'src/theme.dart';
import 'src/updates.dart';
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
    vod: VodCatalog(db),
    updater: updatesSupported ? Updater() : null,
  );
  // Show the UI at once; the keystore can take seconds on first use and
  // passwords are only needed when syncing (which waits for them).
  runApp(ZaplineApp(state: state, autoplayFirst: _devAutoplay));
  await state.loadSecrets();
  // Offline or GitHub busy: no update this time, nothing to say.
  unawaited(state.checkForUpdate().then((_) {}, onError: (Object _) {}));
  if (_devSource.isNotEmpty && state.sources.isEmpty) {
    state
        .addSource(SourceInput(url: _devSource))
        .then(
          (_) {},
          onError: (Object e) =>
              debugPrint(redactSecrets('ZAPLINE_DEV_SOURCE failed: $e')),
        );
  } else {
    // Startup shows cached data immediately; stale sources refresh behind it.
    // Once after the guide-replacement fix, every source refreshes so
    // programmes left doubled by the daylight saving change go away.
    final cleanup = state.db.setting('guideReplaceFix4') == null;
    if (cleanup) state.db.setSetting('guideReplaceFix4', '1');
    state.refreshStale(maxAge: cleanup ? Duration.zero : null);
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

class _ZaplineAppState extends State<ZaplineApp>
    with WidgetsBindingObserver
    implements CastHandler {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _backStack = BackStackObserver();
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    InputMode.instance.attach();
    WidgetsBinding.instance.addObserver(this);
    keepScreenAwake(widget.state.settings.keepScreenOn);
    _startCast();
    _reminderTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkReminders(),
    );
    widget.state.addListener(_announceUpdate);
    // A TV can stay on for days: look again now and then.
    _updateTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => _checkForUpdate(),
    );
  }

  Timer? _updateTimer;

  /// Offline or GitHub busy: no update this time, nothing to say.
  void _checkForUpdate() => unawaited(
    widget.state.checkForUpdate().then((_) {}, onError: (Object _) {}),
  );

  /// Says once per release that a new version is out, with a shortcut to
  /// the settings row that installs it.
  void _announceUpdate() {
    final state = widget.state, update = state.update;
    final context = _navigator.currentContext;
    if (update == null || context == null) return;
    if (state.settings.updateAnnounced >= update.build) return;
    state.settings.updateAnnounced = update.build;
    final l = AppLocalizations.of(context);
    _messenger.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(l.updateAnnounce),
        action: SnackBarAction(
          label: l.updateNow,
          onPressed: () => _navigator.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsScreen(state: state),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.state.removeListener(_announceUpdate);
    _updateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cast?.close();
    _reminderTimer?.cancel();
    super.dispose();
  }

  CastReceiver? _cast;

  /// Listens for phones sending what to play ("Send to TV"); not in tests.
  Future<void> _startCast() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    final r = await CastReceiver.start(
      this,
      id: widget.state.settings.castDeviceId(castSecret),
      name: await deviceName(),
    );
    if (!mounted) {
      await r?.close();
      return;
    }
    _cast = r;
    widget.state.castPort = r?.port;
  }

  @override
  Future<String?> castPlay(Map<String, Object?> request) async {
    final state = widget.state;
    final source = state.sources
        .where((s) => sourceFingerprint(s) == request['source'])
        .firstOrNull;
    if (source == null) return 'unknown-source';
    final navigator = _navigator.currentState;
    final context = _navigator.currentContext;
    if (navigator == null || context == null) return 'not-ready';
    final at = Duration(milliseconds: (request['position'] as int?) ?? 0);
    switch (request['kind']) {
      case 'live':
        final id = request['channel'];
        final all = state.channels();
        var i = all.indexWhere((c) => c.sourceId == source.id && c.id == id);
        final channels = i >= 0
            ? all
            : [
                ...state.db
                    .channels(
                      sourceId: source.id,
                      visibility: ChannelVisibility.all,
                    )
                    .where((c) => c.id == id),
              ];
        if (channels.isEmpty) return 'unknown-channel';
        // A locked group stays locked whoever asks.
        if (state.isLocked(channels[i < 0 ? 0 : i].groupTitle ?? '')) {
          return 'locked';
        }
        if (i < 0) i = 0;
        navigator.popUntil((r) => r.isFirst);
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                PlayerScreen(state: state, channels: channels, initialIndex: i),
          ),
        );
      case 'movie':
        final m = state.db.movie(source.id, '${request['movie']}');
        if (m == null) return 'unknown-channel';
        navigator.popUntil((r) => r.isFirst);
        unawaited(playMovie(context, state, m, start: at));
      case 'episode':
        final show = state.db.show(source.id, '${request['show']}');
        if (show == null) return 'unknown-channel';
        final details = await state.showDetails(show);
        final ep = details.episodes
            .where((e) => e.id == '${request['episode']}')
            .firstOrNull;
        if (ep == null || !context.mounted) return 'unknown-channel';
        navigator.popUntil((r) => r.isFirst);
        unawaited(playEpisodes(context, state, show, details, ep, start: at));
      default:
        return 'unsupported';
    }
    return null;
  }

  @override
  void castKey(String key) => widget.state.remoteKeys.add(key);

  @override
  void castStop() => _navigator.currentState?.popUntil((r) => r.isFirst);

  @override
  CastStatus? get castStatus => widget.state.nowPlaying;

  Route<void>? _codeDialog;

  @override
  void castShowCode(String? code, String from) {
    final navigator = _navigator.currentState;
    if (navigator == null) return;
    if (_codeDialog case final open?) {
      if (open.isActive) navigator.removeRoute(open);
      _codeDialog = null;
    }
    if (code == null) return;
    final route = DialogRoute<void>(
      context: navigator.context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.castPairing),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.castPairingAsk(from.isEmpty ? l.castAPhone : from),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                  color: ZaplineColors.focus,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.cancel),
            ),
          ],
        );
      },
    );
    _codeDialog = route;
    navigator.push(route);
  }

  @override
  String castPaired(String from) {
    final token = castSecret();
    final s = widget.state.settings;
    s.castTokens = {...s.castTokens, token: from};
    widget.state.settingsChanged();
    return token;
  }

  @override
  bool castTrusts(String token) =>
      widget.state.settings.castTokens.containsKey(token);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      keepScreenAwake(widget.state.settings.keepScreenOn);
      _checkForUpdate();
    }
  }

  /// Programmes the user asked about that are starting: a banner with a
  /// shortcut to the channel.
  void _checkReminders() {
    final context = _navigator.currentContext;
    if (context == null) return;
    for (final (reminder, channel) in widget.state.takeDueReminders(
      DateTime.now().toUtc(),
    )) {
      final l = AppLocalizations.of(context);
      _messenger.currentState?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 20),
          content: Text(l.reminderNow(reminder.title, channel?.name ?? '')),
          action: channel == null
              ? null
              : SnackBarAction(
                  label: l.watch,
                  onPressed: () {
                    final all = widget.state.channels();
                    final i = widget.state.indexOfChannel(all, channel);
                    _navigator.currentState?.push(
                      MaterialPageRoute<void>(
                        builder: (_) => PlayerScreen(
                          state: widget.state,
                          channels: i < 0 ? [channel] : all,
                          initialIndex: i < 0 ? 0 : i,
                        ),
                      ),
                    );
                  },
                ),
        ),
      );
    }
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
    // Rebuilds only when the language setting changes.
    return ValueListenableBuilder<String?>(
      valueListenable: state.settings.language,
      builder: (context, language, _) => _materialApp(language),
    );
  }

  Widget _materialApp(String? language) {
    final state = widget.state;
    return MaterialApp(
      locale: language == null ? null : Locale(language),
      title: 'Zapline',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Italian or English, following the device; English otherwise.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
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
          if (state.isEmpty) {
            return context.isPhone
                ? WelcomeScreen(state: state)
                : AddSourceScreen(state: state);
          }
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
