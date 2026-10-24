import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../l10n.dart';
import 'focus_card.dart';

/// Asks for a 4-digit PIN. Works with the on-screen pad (D-pad), the
/// remote's number keys and a keyboard. Returns `null` when cancelled.
Future<String?> askPin(BuildContext context, {required String title}) =>
    showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _PinDialog(title: title),
    );

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});

  final String title;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _pin = '';

  void _type(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) {
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted) Navigator.of(context).pop(_pin);
      });
    }
  }

  void _erase() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final label = e.logicalKey.keyLabel;
    if (label.length == 1 && RegExp(r'\d').hasMatch(label)) {
      _type(label);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _erase();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Icons, not ⌫/✕ characters, which Android may draw as colour emoji.
    Widget key(
      String label, {
      IconData? icon,
      VoidCallback? onPressed,
      bool autofocus = false,
    }) => SizedBox(
      width: 76,
      height: 64,
      child: FocusCard(
        autofocus: autofocus,
        padding: EdgeInsets.zero,
        onPressed: onPressed ?? () => _type(label),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 26, semanticLabel: label)
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );

    return Dialog(
      backgroundColor: ZaplineColors.surface,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? ZaplineColors.focus
                            : ZaplineColors.line,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final d in row)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: key(d, autofocus: d == '1'),
                        ),
                    ],
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: key(
                      context.l10n.pinDelete,
                      icon: Icons.backspace_outlined,
                      onPressed: _erase,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: key('0'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: key(
                      context.l10n.cancel,
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
