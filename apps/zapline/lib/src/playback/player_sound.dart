import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../desktop_window.dart';
import '../l10n.dart';
import '../settings.dart';
import '../theme.dart';
import 'playback_engine.dart';

/// Volume, mute and full screen for a player, from the keyboard or the
/// player's buttons; the volume is kept for the next stream and the next
/// start.
///
/// Keys: M mutes, + and − (or Ctrl+Up/Down) change the volume by 5,
/// F or F11 toggles full screen and P the mini player on desktop.
class PlayerSound {
  PlayerSound(this._engine, this._settings) {
    _apply(show: false);
  }

  final PlaybackEngine _engine;
  final AppSettings _settings;

  /// Bumped on every change, for [VolumeBadge].
  final changed = ValueNotifier<int>(0);

  int get volume => _settings.volume;
  bool get muted => _settings.muted || volume == 0;

  void step(int delta) {
    _settings
      ..volume = volume + delta
      ..muted = false;
    _apply();
  }

  void toggleMute() {
    _settings.muted = !_settings.muted;
    if (!_settings.muted && volume == 0) _settings.volume = 50;
    _apply();
  }

  void _apply({bool show = true}) {
    _engine.setVolume(muted ? 0 : volume / 100);
    if (show) changed.value++;
  }

  void dispose() => changed.dispose();

  /// Handles a volume or full screen key; `true` when it was one.
  bool handleKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return false;
    final k = e.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (k == LogicalKeyboardKey.keyM && e is KeyDownEvent) {
      toggleMute();
    } else if (k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.add ||
        k == LogicalKeyboardKey.numpadAdd ||
        (ctrl && k == LogicalKeyboardKey.arrowUp)) {
      step(5);
    } else if (k == LogicalKeyboardKey.minus ||
        k == LogicalKeyboardKey.numpadSubtract ||
        (ctrl && k == LogicalKeyboardKey.arrowDown)) {
      step(-5);
    } else if (DesktopWindow.supported &&
        e is KeyDownEvent &&
        (k == LogicalKeyboardKey.keyF || k == LogicalKeyboardKey.f11)) {
      DesktopWindow.toggleFullScreen();
    } else if (DesktopWindow.supported &&
        e is KeyDownEvent &&
        k == LogicalKeyboardKey.keyP) {
      DesktopWindow.toggleMini();
    } else {
      return false;
    }
    return true;
  }

  IconData get icon => muted
      ? Icons.volume_off_rounded
      : volume < 50
      ? Icons.volume_down_rounded
      : Icons.volume_up_rounded;
}

/// The volume for a moment after it changes, top right of the picture.
class VolumeBadge extends StatefulWidget {
  const VolumeBadge({super.key, required this.sound});

  final PlayerSound sound;

  @override
  State<VolumeBadge> createState() => _VolumeBadgeState();
}

class _VolumeBadgeState extends State<VolumeBadge> {
  bool _shown = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.sound.changed.addListener(_changed);
  }

  @override
  void dispose() {
    widget.sound.changed.removeListener(_changed);
    _hide?.cancel();
    super.dispose();
  }

  void _changed() {
    _hide?.cancel();
    setState(() => _shown = true);
    _hide = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _shown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sound;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: ZaplineColors.ground.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s.icon, size: 24),
              const SizedBox(width: 10),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  value: s.muted ? 0 : s.volume / 100,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  color: ZaplineColors.accent,
                  backgroundColor: ZaplineColors.line,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                s.muted ? context.l10n.muted : '${s.volume}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
