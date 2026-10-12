import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One line of text laid letter by letter along an arch of [radius], its
/// middle at the box centre, shrunk to fit the box's width.
class ArcTextPainter extends CustomPainter {
  const ArcTextPainter(this.text, this.style, {required this.radius});

  final String text;
  final TextStyle style;
  final double radius;

  TextPainter _layout(String s, TextStyle st) => TextPainter(
    text: TextSpan(text: s, style: st),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final full = _layout(text, style).width;
    final k = math.min(1.0, size.width / full);
    final st = style.copyWith(fontSize: style.fontSize! * k);
    final glyphs = [for (final c in text.characters) _layout(c, st)];
    final total = glyphs.fold<double>(0, (a, g) => a + g.width);
    // Centre on the letters, not the line box: Baloo's deep descent would
    // otherwise sit the lettering high. Its caps stand ~0.72em tall.
    final baseline = glyphs.first.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final lift = baseline - 0.36 * st.fontSize!;
    final centre = Offset(size.width / 2, size.height / 2 + radius);
    var s = -total / 2;
    for (final g in glyphs) {
      final a = (s + g.width / 2) / radius;
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(a)
        ..translate(0, -radius);
      g.paint(canvas, Offset(-g.width / 2, -lift));
      canvas.restore();
      s += g.width;
    }
  }

  @override
  bool shouldRepaint(ArcTextPainter old) =>
      old.text != text || old.style != style || old.radius != radius;
}
