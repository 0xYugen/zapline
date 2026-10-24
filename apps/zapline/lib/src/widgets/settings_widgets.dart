import 'package:flutter/material.dart';

import '../layout.dart';
import '../theme.dart';
import 'focus_card.dart';

// Grouped settings rows, like a phone's own settings: every row is a
// FocusCard, so the same screens work with a finger, a mouse and a remote.

/// A titled group of rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return Padding(
      padding: EdgeInsets.only(top: m.gap * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                title!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: ZaplineColors.textMuted,
                ),
              ),
            ),
          for (final (i, c) in children.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 3),
              child: c,
            ),
        ],
      ),
    );
  }
}

/// A row: optional icon, title and subtitle, the current value on the
/// right and a chevron when it opens something.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.icon,
    this.iconColor,
    this.leading,
    this.chevron = true,
    this.danger = false,
    this.accent = false,
    this.autofocus = false,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final VoidCallback onTap;
  final bool chevron;
  final bool danger;
  final bool accent;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final color = danger
        ? ZaplineColors.live
        : accent
        ? ZaplineColors.focus
        : null;
    return FocusCard(
      autofocus: autofocus,
      radius: 12,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: context.isPhone ? 12 : 14,
      ),
      onPressed: onTap,
      child: Row(
        children: [
          ?leading,
          if (icon != null) ...[
            Icon(icon, size: 22, color: color ?? iconColor),
            const SizedBox(width: 14),
          ] else if (leading != null)
            const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: m.body,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (subtitle != null)
                  Opacity(
                    opacity: 0.7,
                    child: Text(subtitle!, style: TextStyle(fontSize: m.small)),
                  ),
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Opacity(
                opacity: 0.7,
                child: Text(value!, style: TextStyle(fontSize: m.small + 1)),
              ),
            ),
          if (chevron)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right_rounded, size: 22),
            ),
        ],
      ),
    );
  }
}

/// An on/off row; the whole row toggles.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
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
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return FocusCard(
      autofocus: autofocus,
      radius: 12,
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      onPressed: () => onChanged(!value),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: m.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Opacity(
                    opacity: 0.7,
                    child: Text(subtitle!, style: TextStyle(fontSize: m.small)),
                  ),
              ],
            ),
          ),
          // Display only: the row handles OK, clicks and taps.
          ExcludeFocus(
            child: IgnorePointer(
              child: Switch(value: value, onChanged: (_) {}),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the user pick one of [options]: a sheet on phones, a list the
/// remote can walk elsewhere. Returns the picked key wrapped in a record
/// (`null` keys are valid choices); `null` when dismissed.
Future<({T value})?> showChoice<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  required T current,
}) {
  Widget option(BuildContext ctx, T key, String label, {bool focus = false}) =>
      FocusCard(
        autofocus: focus,
        radius: 12,
        selected: key == current,
        onPressed: () => Navigator.of(ctx).pop((value: key)),
        child: Row(
          children: [
            Icon(
              key == current
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  List<Widget> list(BuildContext ctx) => [
    for (final MapEntry(:key, :value) in options.entries)
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: option(ctx, key, value, focus: key == current),
      ),
  ];

  if (context.isPhone) {
    return showModalBottomSheet<({T value})>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ...list(ctx),
          ],
        ),
      ),
    );
  }
  return showDialog<({T value})>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: ZaplineColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ...list(ctx),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Asks to confirm something that can't be undone.
Future<bool> confirmDanger(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  required String cancel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: ZaplineColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: ZaplineColors.textMuted),
              ),
              const SizedBox(height: 20),
              FocusCard(
                autofocus: true,
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Center(
                  child: Text(
                    cancel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FocusCard(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Center(
                  child: Text(
                    confirm,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: ZaplineColors.live,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok ?? false;
}
