import 'package:flutter/material.dart';

import '../theme.dart';

// The Zapline logo, drawn from the same geometry as tools/brand/generate.py
// so the app matches its icon at every size and needs no image file.

/// The "hidden Z": a dark play button on an amber tile, cut through by a Z
/// in the tile's colour. It is the app icon.
class ZaplineMark extends StatelessWidget {
  const ZaplineMark({super.key, this.size = 28});

  /// Width and height of the tile.
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Zapline',
    child: CustomPaint(size: Size.square(size), painter: const _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  static const _amberTop = Color(0xFFFFD166);
  static const _amberBottom = Color(0xFFF59E0B);
  static const _ink = Color(0xFF141922);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final tile = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(23 * s),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_amberTop, _amberBottom],
        ).createShader(Offset.zero & size),
    );
    final play = Path()
      ..moveTo(31 * s, 21 * s)
      ..quadraticBezierTo(27 * s, 19 * s, 27 * s, 24 * s)
      ..lineTo(27 * s, 76 * s)
      ..quadraticBezierTo(27 * s, 81 * s, 31 * s, 79 * s)
      ..lineTo(81 * s, 53.5 * s)
      ..quadraticBezierTo(85 * s, 50 * s, 81 * s, 46.5 * s)
      ..close();
    final cut = Path()
      ..moveTo(20 * s, 40 * s)
      ..lineTo(60 * s, 40 * s)
      ..lineTo(39 * s, 60 * s)
      ..lineTo(90 * s, 60 * s);
    // The Z is a gap in the play, so the tile shows through it.
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..drawPath(play, Paint()..color = _ink)
      ..drawPath(
        cut,
        Paint()
          ..blendMode = BlendMode.clear
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5 * s
          ..strokeJoin = StrokeJoin.miter,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}

/// "zapline" in Inter ExtraBold.
class ZaplineWordmark extends StatelessWidget {
  const ZaplineWordmark({super.key, this.height = 24});

  /// Rough height of the word; the font size follows from it.
  final double height;

  @override
  Widget build(BuildContext context) => Text(
    'zapline',
    textHeightBehavior: const TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    ),
    style: TextStyle(
      fontFamily: 'Inter',
      fontSize: height,
      height: 1,
      fontWeight: FontWeight.w800,
      letterSpacing: -height * 0.02,
      color: ZaplineColors.text,
    ),
  );
}

/// The icon and the name side by side, for headers.
class ZaplineLockup extends StatelessWidget {
  const ZaplineLockup({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ZaplineMark(size: height),
      SizedBox(width: height * 0.36),
      ZaplineWordmark(height: height * 0.86),
    ],
  );
}
