import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/brand.dart';
import '../widgets/pin_pad.dart';
import 'backup_screen.dart';
import 'sources_screen.dart';

/// App-wide preferences. Per-source options (guides, group filters, hidden
/// channels) live in Sources → Manage.
/// Set by release builds: `--dart-define=ZAPLINE_VERSION=0.1.0 (42)`.
const appVersion = String.fromEnvironment(
  'ZAPLINE_VERSION',
  defaultValue: 'development build',
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _message;

  AppState get _state => widget.state;

  /// Saves a preference and redraws every screen that shows it.
  void _set(void Function() change) {
    change();
    _state.settingsChanged();
    setState(() => _message = null);
  }

  Future<void> _changePin() async {
    final first = await askPin(context, title: 'Choose a 4-digit PIN');
    if (first == null || !mounted) return;
    final again = await askPin(context, title: 'Enter it again');
    if (again == null || !mounted) return;
    if (again != first) {
      setState(() => _message = 'The two PINs differ. Nothing changed.');
      return;
    }
    _state.setPin(first);
    setState(() => _message = 'PIN saved. Lock groups from Sources → Manage.');
  }

  Future<void> _removePin() async {
    final pin = await askPin(context, title: 'Enter the current PIN');
    if (pin == null || !mounted) return;
    if (!_state.unlock(pin)) {
      setState(() => _message = 'Wrong PIN.');
      return;
    }
    _state.setPin(null);
    setState(() => _message = 'PIN removed and all groups unlocked.');
  }

  @override
  Widget build(BuildContext context) {
    final s = _state.settings;
    return AdaptivePage(
      title: 'Settings',
      children: [
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _message!,
              style: const TextStyle(color: ZaplineColors.ok),
            ),
          ),
        if (context.isPhone) ...[
          const PageSection('Sources'),
          FocusCard(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SourcesScreen(state: _state),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.dns_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: _Label(
                    'Playlists and servers',
                    '${_state.sources.length} added · guides, filters, '
                        'hidden channels',
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
        PageSection(context.l10n.language),
        ValueListenableBuilder<String?>(
          valueListenable: s.language,
          builder: (context, language, _) => _Choice<String?>(
            title: context.l10n.language,
            value: language,
            options: {
              null: context.l10n.languageDevice,
              'it': 'Italiano',
              'en': 'English',
            },
            onChanged: s.setLanguage,
          ),
        ),
        const PageSection('Channels'),
        _Toggle(
          autofocus: true,
          title: 'Number channels 1, 2, 3…',
          subtitle: 'Instead of the numbers your provider sends.',
          value: s.sequentialNumbers,
          onChanged: (v) => _set(() => s.sequentialNumbers = v),
        ),
        _Toggle(
          title: 'Open the last channel at startup',
          subtitle: 'Like turning on a TV.',
          value: s.resumeLastChannel,
          onChanged: (v) => _set(() => s.resumeLastChannel = v),
        ),
        _Choice<BoxFit>(
          title: 'Picture',
          value: s.videoFit,
          options: const {
            BoxFit.contain: 'Fit',
            BoxFit.cover: 'Zoom',
            BoxFit.fill: 'Stretch',
          },
          onChanged: (v) => _set(() => s.videoFit = v),
        ),
        const PageSection('TV guide'),
        _Toggle(
          title: '24-hour clock',
          value: s.clock24h,
          onChanged: (v) => _set(() => s.clock24h = v),
        ),
        _Choice<int>(
          title: 'Days of guide to keep',
          subtitle: 'Fewer days sync faster on small devices.',
          value: s.guideDays,
          options: const {2: '2', 3: '3', 7: '7', 14: '14'},
          onChanged: (v) => _set(() => s.guideDays = v),
        ),
        _Choice<int>(
          title: 'Refresh sources automatically',
          value: s.refreshHours,
          options: const {0: 'Never', 6: 'Every 6 h', 12: '12 h', 24: '24 h'},
          onChanged: (v) => _set(() => s.refreshHours = v),
        ),
        const PageSection('Parental lock'),
        const Text(
          'Locked groups stay out of lists, search and the guide until the '
          'PIN is entered. Lock groups from Sources → Manage.',
          style: TextStyle(color: ZaplineColors.textMuted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FocusCard(
              onPressed: _changePin,
              child: Text(_state.hasPin ? 'Change PIN' : 'Set a PIN'),
            ),
            if (_state.hasPin)
              FocusCard(onPressed: _removePin, child: const Text('Remove PIN')),
            if (_state.unlocked)
              FocusCard(
                onPressed: () {
                  _state.lock();
                  setState(() => _message = 'Locked groups hidden again.');
                },
                child: const Text('Lock now'),
              ),
          ],
        ),
        const PageSection('Backup'),
        FocusCard(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BackupScreen(state: _state),
            ),
          ),
          child: const Text('Back up or move to another device'),
        ),
        const PageSection('About'),
        const Row(
          children: [
            ZaplineLockup(height: 26),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                appVersion,
                style: TextStyle(color: ZaplineColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Zapline is free and open source (MIT). It plays the sources you '
          'add and includes no channels or content.',
          style: TextStyle(color: ZaplineColors.textMuted),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.autofocus = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: FocusCard(
      autofocus: autofocus,
      padding: context.isPhone
          ? const EdgeInsets.fromLTRB(16, 8, 8, 8)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      onPressed: () => onChanged(!value),
      child: Row(
        children: [
          Expanded(child: _Label(title, subtitle)),
          // Display only: the card handles OK, clicks and taps.
          ExcludeFocus(
            child: IgnorePointer(
              child: Switch(value: value, onChanged: (_) {}),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A row of options; Left/Right moves between them like any other card.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => LabeledRow(
    label: title,
    subtitle: subtitle,
    children: [
      for (final MapEntry(:key, value: label) in options.entries)
        FocusCard(
          selected: key == value,
          padding: context.isPhone
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          onPressed: () => onChanged(key),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (key == value) ...[
                const Icon(Icons.check_rounded, size: 20),
                const SizedBox(width: 6),
              ],
              Text(label),
            ],
          ),
        ),
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label(this.title, this.subtitle);

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: Metrics.of(context).body,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (subtitle != null)
        // Inherits the card's colour so it stays readable when focused.
        Opacity(
          opacity: 0.7,
          child: Text(subtitle!, style: const TextStyle(fontSize: 13)),
        ),
    ],
  );
}
