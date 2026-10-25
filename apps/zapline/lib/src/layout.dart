import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// What the app is running on, which decides the layout family:
///
/// - [tv]: 10-foot UI driven by a remote (Android TV, Fire TV);
/// - [phone]: touch-first, narrow (any device whose short side is under
///   600 dp, including small desktop windows);
/// - [wide]: tablets and desktop windows; the TV layout with pointer
///   affordances.
enum FormFactor {
  tv,
  phone,
  wide;

  /// Set once at startup from the platform (see [detectTv]).
  static bool isTv = false;

  /// Lets tests and screenshots force a layout.
  static FormFactor? debugOverride;

  static FormFactor of(BuildContext context) {
    if (debugOverride != null) return debugOverride!;
    if (isTv) return tv;
    return MediaQuery.sizeOf(context).shortestSide < 600 ? phone : wide;
  }

  /// Asks Android whether this is a television (Android TV, Google TV,
  /// Fire TV). Other platforms are never TVs.
  static Future<void> detectTv() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      isTv =
          await const MethodChannel('zapline/device')
              .invokeMethod<bool>('isTv') ??
          false;
    } on PlatformException {
      isTv = false;
    } on MissingPluginException {
      isTv = false;
    }
  }
}

/// What other devices call this one: the name set in Android's settings
/// ("Soggiorno"), else the model or the computer's name.
Future<String> deviceName() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final name = await const MethodChannel('zapline/device')
          .invokeMethod<String>('deviceName');
      if (name != null && name.isNotEmpty) return name;
    } on PlatformException {
      // fall through
    } on MissingPluginException {
      // fall through
    }
  }
  return kIsWeb ? 'Zapline' : Platform.localHostname;
}

extension FormFactorContext on BuildContext {
  FormFactor get formFactor => FormFactor.of(this);
  bool get isPhone => FormFactor.of(this) == FormFactor.phone;
}

/// Sizes that differ between a phone in the hand and a TV across the room.
class Metrics {
  const Metrics._({
    required this.pagePadding,
    required this.title,
    required this.section,
    required this.body,
    required this.small,
    required this.gap,
  });

  static const _tv = Metrics._(
    pagePadding: EdgeInsets.fromLTRB(64, 40, 64, 48),
    title: 32,
    section: 22,
    body: 17,
    small: 14,
    gap: 12,
  );

  static const _phone = Metrics._(
    pagePadding: EdgeInsets.fromLTRB(16, 8, 16, 32),
    title: 22,
    section: 17,
    body: 15,
    small: 13,
    gap: 8,
  );

  static Metrics of(BuildContext context) => context.isPhone ? _phone : _tv;

  final EdgeInsets pagePadding;
  final double title, section, body, small, gap;
}

/// A titled, scrolling page that looks right everywhere: an app bar with a
/// back arrow on phones, a large in-page title on TV and desktop.
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// App bar actions on phones; shown after the title elsewhere.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    if (context.isPhone) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: ListView(
          padding: m.pagePadding,
          children: [
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  subtitle!,
                  style: const TextStyle(color: ZaplineColors.textMuted),
                ),
              ),
            ...children,
          ],
        ),
      );
    }
    return Scaffold(
      body: ListView(
        padding: m.pagePadding,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: m.title,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                subtitle!,
                style: const TextStyle(color: ZaplineColors.textMuted),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// A section heading inside an [AdaptivePage].
class PageSection extends StatelessWidget {
  const PageSection(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return Padding(
      padding: EdgeInsets.only(top: m.gap * 2.5, bottom: m.gap),
      child: Text(
        title,
        style: TextStyle(fontSize: m.section, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Muted explanatory text.
class Hint extends StatelessWidget {
  const Hint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: Metrics.of(context).small,
        color: ZaplineColors.textMuted,
      ),
    ),
  );
}

/// A label with controls beside it on wide screens and below it when there
/// is no room, so labels are never squeezed into a single letter column.
class LabeledRow extends StatelessWidget {
  const LabeledRow({
    super.key,
    required this.label,
    required this.children,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: m.body, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(fontSize: m.small, color: ZaplineColors.textMuted),
          ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: m.gap),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                SizedBox(height: m.gap),
                Wrap(spacing: m.gap, runSpacing: m.gap, children: children),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              for (final c in children)
                Padding(
                  padding: EdgeInsets.only(left: m.gap),
                  child: c,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Bars drawn by the system: transparent with light icons, so the dark
/// ground shows through on phones.
const systemBarsStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: ZaplineColors.ground,
  statusBarIconBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.light,
);
