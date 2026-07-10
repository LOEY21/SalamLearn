import 'package:flutter/material.dart';

/// Shared role glyphs — used by the role picker and the sign-in/sign-up
/// screen so the same icon always means the same role everywhere.

/// School-backpack glyph — reads instantly as "student", and echoes the
/// "Digital backpack" feature already in the Student Hub.
Widget backpackIcon(Color color, {double size = 26}) => CustomPaint(
      size: Size(size, size),
      painter: _BackpackPainter(color: color),
    );

class _BackpackPainter extends CustomPainter {
  const _BackpackPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final strap = Path()
      ..moveTo(p(8, 7.5).dx, p(8, 7.5).dy)
      ..cubicTo(p(8, 5).dx, p(8, 5).dy, p(8, 3.5).dx, p(8, 3.5).dy, p(12, 3.5).dx,
          p(12, 3.5).dy)
      ..cubicTo(p(16, 3.5).dx, p(16, 3.5).dy, p(16, 5).dx, p(16, 5).dy, p(16, 7.5).dx,
          p(16, 7.5).dy);
    canvas.drawPath(strap, paint);

    final body = RRect.fromRectAndRadius(
      Rect.fromPoints(p(5, 7.5), p(19, 20.5)),
      Radius.circular(3 * s),
    );
    canvas.drawRRect(body, paint);

    final pocket = Path()
      ..moveTo(p(9, 7.5).dx, p(9, 7.5).dy)
      ..lineTo(p(9, 10).dx, p(9, 10).dy)
      ..cubicTo(p(9, 11.66).dx, p(9, 11.66).dy, p(10.34, 13).dx, p(10.34, 13).dy,
          p(12, 13).dx, p(12, 13).dy)
      ..cubicTo(p(13.66, 13).dx, p(13.66, 13).dy, p(15, 11.66).dx, p(15, 11.66).dy,
          p(15, 10).dx, p(15, 10).dy)
      ..lineTo(p(15, 7.5).dx, p(15, 7.5).dy);
    canvas.drawPath(pocket, paint);

    canvas.drawLine(p(12, 14), p(12, 17), paint);
  }

  @override
  bool shouldRepaint(covariant _BackpackPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Two-figure family glyph for Parent/Guardian — the clearest literal
/// option for this role.
Widget familyIcon(Color color, {double size = 26}) => CustomPaint(
      size: Size(size, size),
      painter: _FamilyPainter(color: color),
    );

class _FamilyPainter extends CustomPainter {
  const _FamilyPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final faded = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);

    canvas.drawCircle(p(8, 7), 2.6 * s, paint);
    final body = Path()
      ..moveTo(p(3, 20).dx, p(3, 20).dy)
      ..cubicTo(p(3, 17).dx, p(3, 17).dy, p(5.2, 15).dx, p(5.2, 15).dy, p(8, 15).dx,
          p(8, 15).dy)
      ..cubicTo(p(10.8, 15).dx, p(10.8, 15).dy, p(13, 17).dx, p(13, 17).dy,
          p(13, 20).dx, p(13, 20).dy);
    canvas.drawPath(body, paint);

    canvas.drawCircle(p(17, 6), 2 * s, faded);
    final body2 = Path()
      ..moveTo(p(13.5, 12.2).dx, p(13.5, 12.2).dy)
      ..cubicTo(p(14.5, 11.4).dx, p(14.5, 11.4).dy, p(15.7, 11.1).dx, p(15.7, 11.1).dy,
          p(17, 11.1).dx, p(17, 11.1).dy)
      ..cubicTo(p(19.6, 11.1).dx, p(19.6, 11.1).dy, p(21.5, 13.1).dx, p(21.5, 13.1).dy,
          p(21.5, 16).dx, p(21.5, 16).dy);
    canvas.drawPath(body2, faded);
  }

  @override
  bool shouldRepaint(covariant _FamilyPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Graduation-cap glyph for Asatidz/Teacher — the universal education-role
/// icon, kept distinct in silhouette from Learner and Parent.
Widget graduationCapIcon(Color color, {double size = 26}) => CustomPaint(
      size: Size(size, size),
      painter: _GraduationCapPainter(color: color),
    );

class _GraduationCapPainter extends CustomPainter {
  const _GraduationCapPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final cap = Path()
      ..moveTo(p(2, 9.5).dx, p(2, 9.5).dy)
      ..lineTo(p(12, 5).dx, p(12, 5).dy)
      ..lineTo(p(22, 9.5).dx, p(22, 9.5).dy)
      ..lineTo(p(12, 14).dx, p(12, 14).dy)
      ..close();
    canvas.drawPath(cap, paint);

    final band = Path()
      ..moveTo(p(6.5, 11.7).dx, p(6.5, 11.7).dy)
      ..lineTo(p(6.5, 15.7).dx, p(6.5, 15.7).dy)
      ..cubicTo(p(6.5, 17.1).dx, p(6.5, 17.1).dy, p(9, 18.3).dx, p(9, 18.3).dy,
          p(12, 18.3).dx, p(12, 18.3).dy)
      ..cubicTo(p(15, 18.3).dx, p(15, 18.3).dy, p(17.5, 17.1).dx, p(17.5, 17.1).dy,
          p(17.5, 15.7).dx, p(17.5, 15.7).dy)
      ..lineTo(p(17.5, 11.7).dx, p(17.5, 11.7).dy);
    canvas.drawPath(band, paint);

    canvas.drawLine(p(20.5, 10.2), p(20.5, 15.5), paint);
  }

  @override
  bool shouldRepaint(covariant _GraduationCapPainter oldDelegate) =>
      oldDelegate.color != color;
}
