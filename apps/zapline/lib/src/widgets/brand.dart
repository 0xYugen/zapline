import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

// The Zapline mark and wordmark, drawn from the same geometry as
// tools/brand/generate.py so the app matches its icon at every size and
// depends on no image or font file.

/// The "Z" whose diagonal is a lightning bolt and whose base runs on into
/// a line ending in a playhead dot.
class ZaplineMark extends StatelessWidget {
  const ZaplineMark({super.key, this.size = 28, this.color});

  /// Height of the mark.
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Zapline',
    child: CustomPaint(
      size: Size(size * _markAspect, size),
      painter: _MarkPainter(color ?? ZaplineColors.focus),
    ),
  );
}

// The mark's ink spans x 91..924 and y 21..979 of its 1000-unit square.
const _markLeft = 80.0, _markTop = 10.0, _markW = 860.0, _markH = 980.0;
const _markAspect = _markW / _markH;

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / _markH;
    Offset p(double x, double y) =>
        Offset((x - _markLeft) * s, (y - _markTop) * s);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 118 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(p(150, 80).dx, p(150, 80).dy);
    for (final (x, y) in const [
      (720.0, 80.0),
      (400.0, 470.0),
      (600.0, 470.0),
      (220.0, 920.0),
      (690.0, 920.0),
    ]) {
      path.lineTo(p(x, y).dx, p(x, y).dy);
    }
    canvas
      ..drawPath(path, stroke)
      ..drawCircle(p(850, 920), 74 * s, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

/// "zapline" in the brand's stroke-drawn letters: "zap" in amber, "line"
/// in the text colour.
class ZaplineWordmark extends StatelessWidget {
  const ZaplineWordmark({super.key, this.height = 24});

  /// Height of the whole word, from the top of the "l" to the tail of the
  /// "p".
  final double height;

  @override
  Widget build(BuildContext context) {
    final xh = height / _Wordmark.heightInXh;
    return Semantics(
      label: 'Zapline',
      child: CustomPaint(
        size: Size(_Wordmark.width(xh), height),
        painter: _WordmarkPainter(xh),
      ),
    );
  }
}

/// Mark and wordmark side by side.
class ZaplineLockup extends StatelessWidget {
  const ZaplineLockup({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ZaplineMark(size: height),
      SizedBox(width: height * 0.38),
      ZaplineWordmark(height: height * 0.92),
    ],
  );
}

abstract final class _Wordmark {
  static const strokeInXh = 0.17;
  static const gapInXh = 0.3;

  // Ascender of "l" (0.48), descender of "p" (0.42), plus round caps.
  static const above = 0.48 + strokeInXh / 2;
  static const below = 0.42 + strokeInXh / 2;
  static const heightInXh = above + 1 + below;

  static const advances = {
    'z': 0.78,
    'a': 0.92,
    'p': 0.92,
    'l': 0.0,
    'i': 0.0,
    'n': 0.82,
    'e': 0.94,
  };

  static double width(double xh) {
    var w = 0.0;
    for (final ch in 'zapline'.split('')) {
      w += advances[ch]! + gapInXh;
    }
    return (w - gapInXh + strokeInXh) * xh;
  }
}

class _WordmarkPainter extends CustomPainter {
  _WordmarkPainter(this.xh);

  final double xh;

  @override
  void paint(Canvas canvas, Size size) {
    final w = xh * _Wordmark.strokeInXh;
    final top = _Wordmark.above * xh;
    var x = w / 2;
    for (final (i, ch) in 'zapline'.split('').indexed) {
      final paint = Paint()
        ..color = i < 3 ? ZaplineColors.focus : ZaplineColors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _glyph(canvas, ch, x, top, paint, w);
      x += (_Wordmark.advances[ch]! + _Wordmark.gapInXh) * xh;
    }
  }

  void _glyph(
    Canvas c,
    String ch,
    double x,
    double top,
    Paint paint,
    double w,
  ) {
    Offset pt(double u, double v) => Offset(x + u * xh, top + v * xh);
    void line(List<(double, double)> points) {
      final path = Path()
        ..moveTo(
          pt(points[0].$1, points[0].$2).dx,
          pt(points[0].$1, points[0].$2).dy,
        );
      for (final (u, v) in points.skip(1)) {
        path.lineTo(pt(u, v).dx, pt(u, v).dy);
      }
      c.drawPath(path, paint);
    }

    // Angles as in PIL: degrees clockwise from 3 o'clock.
    void ring(
      double u,
      double v,
      double r, [
      double from = 0,
      double to = 360,
    ]) {
      final rect = Rect.fromCircle(center: pt(u, v), radius: r * xh);
      if (to - from >= 360) {
        c.drawOval(rect, paint);
      } else {
        c.drawArc(
          rect,
          from * math.pi / 180,
          (to - from) * math.pi / 180,
          false,
          paint,
        );
      }
    }

    switch (ch) {
      case 'z':
        line([(0, 0), (0.78, 0), (0, 1), (0.78, 1)]);
      case 'a':
        ring(0.46, 0.5, 0.46);
        line([(0.92, 0), (0.92, 1)]);
      case 'p':
        ring(0.46, 0.5, 0.46);
        line([(0, 0), (0, 1.42)]);
      case 'l':
        line([(0, -0.48), (0, 1)]);
      case 'i':
        line([(0, 0), (0, 1)]);
        c.drawCircle(pt(0, -0.36), w * 0.62, Paint()..color = paint.color);
      case 'n':
        line([(0, 0), (0, 1)]);
        ring(0.41, 0.41, 0.41, 180, 360);
        line([(0.82, 0.41), (0.82, 1)]);
      case 'e':
        ring(0.47, 0.5, 0.47, 28, 360);
        line([(0.0, 0.5), (0.94, 0.5)]);
    }
  }

  @override
  bool shouldRepaint(_WordmarkPainter old) => old.xh != xh;
}
