import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/focus_card.dart';
import '../widgets/pin_pad.dart';
import 'backup_screen.dart';

/// App-wide preferences. Per-source options (guides, group filters, hidden
/// channels) live in Sources → Manage.
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
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(64, 40, 64, 48),
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                style: const TextStyle(color: ZaplineColors.ok),
              ),
            ),
          const _Section('Channels'),
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
          const _Section('TV guide'),
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
          const _Section('Parental lock'),
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
                FocusCard(
                  onPressed: _removePin,
                  child: const Text('Remove PIN'),
                ),
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
          const _Section('Backup'),
          FocusCard(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BackupScreen(state: _state),
              ),
            ),
            child: const Text('Back up or move to another device'),
          ),
          const _Section('About'),
          const Text(
            'Zapline is free and open source (MIT). It plays the sources you '
            'add and includes no channels or content.',
            style: TextStyle(color: ZaplineColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 32, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
    ),
  );
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Row(
      children: [
        Expanded(child: _Label(title, subtitle)),
        for (final MapEntry(:key, value: label) in options.entries)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FocusCard(
              selected: key == value,
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
          ),
      ],
    ),
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
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
