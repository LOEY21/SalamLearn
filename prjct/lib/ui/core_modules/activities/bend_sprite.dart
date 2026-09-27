import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A sprite drawn on a mesh so it can bend like a plant rooted at its
/// bottom edge (or top edge, with [hang]): each point shifts sideways by [bend] times the sprite's
/// height, weighted toward the tips, dipping a touch as it leans, with a
/// small per-column [flutter] out of phase across the width.
class BendSprite extends StatefulWidget {
  const BendSprite({
    super.key,
    required this.asset,
    required this.bend,
    required this.flutter,
    required this.t,
    this.hang = false,
  });

  final String asset;
  final double bend;
  final double flutter;
  final double t;

  /// Rooted at the top edge instead (a trailing vine): the bottom swings.
  final bool hang;

  @override
  State<BendSprite> createState() => _BendSpriteState();
}

class _BendSpriteState extends State<BendSprite> {
  ImageStream? _stream;
  ui.Image? _image;
  late final _listener = ImageStreamListener(
    (info, _) => setState(() => _image = info.image),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = AssetImage(
      widget.asset,
    ).resolve(createLocalImageConfiguration(context))..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      painter: _BendPainter(
        image,
        widget.bend,
        widget.flutter,
        widget.t,
        hang: widget.hang,
      ),
    );
  }
}

class _BendPainter extends CustomPainter {
  _BendPainter(
    this.image,
    this.bend,
    this.flutter,
    this.t, {
    this.hang = false,
  });

  final ui.Image image;
  final double bend;
  final double flutter;
  final double t;
  final bool hang;

  static const int _cols = 6;
  static const int _rows = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final pos = <Offset>[];
    final tex = <Offset>[];
    Offset at(int c, int r) {
      final u = c / _cols;
      final v = r / _rows;
      final lift = math.pow(hang ? v : 1 - v, 1.7).toDouble();
      final wave = math.sin(t * 2 * math.pi / 1.3 + u * 3.1 + v * 1.7);
      final dx = (bend + flutter * wave * lift) * lift * size.height;
      return Offset(u * size.width + dx, v * size.height + dx.abs() * 0.15);
    }

    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final quad = [at(c, r), at(c + 1, r), at(c, r + 1), at(c + 1, r + 1)];
        final uv = [
          Offset(c / _cols, r / _rows),
          Offset((c + 1) / _cols, r / _rows),
          Offset(c / _cols, (r + 1) / _rows),
          Offset((c + 1) / _cols, (r + 1) / _rows),
        ];
        for (final k in const [0, 1, 2, 1, 3, 2]) {
          pos.add(quad[k]);
          tex.add(Offset(uv[k].dx * image.width, uv[k].dy * image.height));
        }
      }
    }
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..shader = ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      );
    canvas.drawVertices(
      ui.Vertices(VertexMode.triangles, pos, textureCoordinates: tex),
      BlendMode.srcOver,
      paint,
    );
  }

  @override
  bool shouldRepaint(_BendPainter old) =>
      old.image != image ||
      old.bend != bend ||
      old.flutter != flutter ||
      old.t != t ||
      old.hang != hang;
}
