import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/scheduler.dart';

/// Ambient full-screen animation layer for the tracing scene — sun rays,
/// drifting clouds, birds, falling palm leaves, and wind-blown sand —
/// ported from the approved `Game Background.dc.html` motion preview.
/// Paints over `trace_screen_bg.png`, never intercepts touches.
class TraceAmbientBackground extends StatefulWidget {
  const TraceAmbientBackground({super.key});

  @override
  State<TraceAmbientBackground> createState() => _TraceAmbientBackgroundState();
}

class _TraceAmbientBackgroundState extends State<TraceAmbientBackground>
    with SingleTickerProviderStateMixin {
  static const _windSpeed = 1.0;
  final _rnd = math.Random();

  late final Ticker _ticker = createTicker(_tick);
  Duration _lastTick = Duration.zero;
  double _t = 0;

  final _clouds = <_CloudP>[];
  final _birds = <_BirdP>[];
  final _leaves = <_LeafP>[];
  final _sand = <_SandP>[];
  double _birdTimer = 1.5;

  double _r(double a, double b) => a + _rnd.nextDouble() * (b - a);

  static const _greens = [
    Color(0xFF7DB72F),
    Color(0xFF67A628),
    Color(0xFF4F8C1C),
    Color(0xFF8CC63F),
  ];

  /// Palm canopies only — left crown and right crown, as fractions of the
  /// full background (measured off `trace_screen_bg.png`) — leaves fall a
  /// short distance out of the fronds and recycle before reaching the
  /// sandbox, instead of drifting the whole screen height.
  static const _leftCrownX = (0.02, 0.24);
  static const _leftCrownY = (0.24, 0.42);
  static const _rightCrownX = (0.76, 0.98);
  static const _rightCrownY = (0.26, 0.44);
  static const _leafRecycleY = 0.62;

  _LeafP _spawnLeaf() {
    final left = _rnd.nextDouble() < 0.5;
    final xRange = left ? _leftCrownX : _rightCrownX;
    final yRange = left ? _leftCrownY : _rightCrownY;
    return _newLeaf(_r(xRange.$1, xRange.$2), _r(yRange.$1, yRange.$2));
  }

  _LeafP _newLeaf(double x, double y) {
    return _LeafP(
      x: x,
      y: y,
      vy: _r(0.028, 0.06),
      swayAmp: _r(0.02, 0.05),
      swayFreq: _r(0.4, 0.9),
      swayPhase: _r(0, 6.28),
      rot: _r(0, 6.28),
      vrot: _r(-1.2, 1.2),
      size: _r(9, 20),
      color: _greens[_rnd.nextInt(_greens.length)],
    );
  }

  _SandP _newSand({bool fromLeft = false}) {
    final band = _rnd.nextDouble() < 0.55 ? _r(0.44, 0.60) : _r(0.85, 1.0);
    return _SandP(
      x: fromLeft ? _r(-0.05, -0.01) : _r(0, 1),
      y: band,
      baseY: band,
      vx: _r(0.05, 0.13),
      amp: _r(0.004, 0.012),
      freq: _r(0.6, 1.4),
      phase: _r(0, 6.28),
      size: _r(1, 2.6),
      a: _r(0.25, 0.6),
    );
  }

  @override
  void initState() {
    super.initState();
    _leaves.addAll(List.generate(6, (_) => _spawnLeaf()));
    _sand.addAll(List.generate(150, (_) => _newSand()));
    _clouds.addAll(
      List.generate(
        5,
        (_) => _CloudP(
          x: _r(0, 1),
          y: _r(0.05, 0.33),
          s: _r(0.7, 1.4),
          vx: _r(0.006, 0.018),
          a: _r(0.35, 0.7),
        ),
      ),
    );
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dtMs = _lastTick == Duration.zero
        ? 16.0
        : (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    final dt = math.min(dtMs / 1000.0, 0.05);
    _t += dt;

    for (final c in _clouds) {
      c.x += c.vx * _windSpeed * dt;
      if (c.x - 0.2 > 1) c.x = -0.2;
    }

    _birdTimer -= dt;
    if (_birdTimer <= 0 && _birds.length < 5) {
      _birdTimer = _r(2.5, 6);
      final dir = _rnd.nextDouble() < 0.5 ? 1 : -1;
      _birds.add(
        _BirdP(
          x: dir == 1 ? -0.05 : 1.05,
          y: _r(0.1, 0.4),
          vx: _r(0.05, 0.09) * dir,
          vy: _r(-0.004, 0.004),
          size: _r(7, 13),
          flap: _r(0, 6.28),
          flapSpeed: _r(7, 11),
        ),
      );
    }
    for (final b in _birds) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.flap += b.flapSpeed * dt;
    }
    _birds.removeWhere((b) => b.x < -0.12 || b.x > 1.12);

    for (final l in _leaves) {
      l.y += l.vy * dt;
      l.rot += l.vrot * dt;
      if (l.y > _leafRecycleY) {
        final fresh = _spawnLeaf();
        l.x = fresh.x;
        l.y = fresh.y;
        l.vy = fresh.vy;
        l.swayAmp = fresh.swayAmp;
        l.swayFreq = fresh.swayFreq;
        l.swayPhase = fresh.swayPhase;
        l.rot = fresh.rot;
        l.vrot = fresh.vrot;
        l.size = fresh.size;
        l.color = fresh.color;
      }
    }

    for (final g in _sand) {
      g.x += g.vx * _windSpeed * dt;
      if (g.x > 1.03) {
        final fresh = _newSand(fromLeft: true);
        g.x = fresh.x;
        g.y = fresh.y;
        g.baseY = fresh.baseY;
        g.vx = fresh.vx;
        g.amp = fresh.amp;
        g.freq = fresh.freq;
        g.phase = fresh.phase;
        g.size = fresh.size;
        g.a = fresh.a;
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _AmbientPainter(
          t: _t,
          clouds: _clouds,
          birds: _birds,
          leaves: _leaves,
          sand: _sand,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _CloudP {
  _CloudP({
    required this.x,
    required this.y,
    required this.s,
    required this.vx,
    required this.a,
  });
  double x, y, s, vx, a;
}

class _BirdP {
  _BirdP({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.flap,
    required this.flapSpeed,
  });
  double x, y, vx, vy, size, flap, flapSpeed;
}

class _LeafP {
  _LeafP({
    required this.x,
    required this.y,
    required this.vy,
    required this.swayAmp,
    required this.swayFreq,
    required this.swayPhase,
    required this.rot,
    required this.vrot,
    required this.size,
    required this.color,
  });
  double x, y, vy, swayAmp, swayFreq, swayPhase, rot, vrot, size;
  Color color;
}

class _SandP {
  _SandP({
    required this.x,
    required this.y,
    required this.baseY,
    required this.vx,
    required this.amp,
    required this.freq,
    required this.phase,
    required this.size,
    required this.a,
  });
  double x, y, baseY, vx, amp, freq, phase, size, a;
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.t,
    required this.clouds,
    required this.birds,
    required this.leaves,
    required this.sand,
  });

  final double t;
  final List<_CloudP> clouds;
  final List<_BirdP> birds;
  final List<_LeafP> leaves;
  final List<_SandP> sand;

  void _drawRays(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(Offset(w * 0.5, -h * 0.05), h * 0.45, [
        const Color(0x47FFF8DC),
        const Color(0x00FFF8DC),
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.5), glowPaint);

    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
    const n = 8;
    final cx = w * 0.5, cy = -h * 0.06;
    for (var i = 0; i < n; i++) {
      final base = (i / n) * math.pi - math.pi / 2;
      final ang = base + math.sin(t * 0.2 + i) * 0.03;
      final len = h * 0.55;
      const spread = 0.045;
      final alpha = 0.05 + 0.03 * (0.5 + 0.5 * math.sin(t * 0.5 + i * 1.7));
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(ang);
      final shaftPaint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, len), [
          Color.fromRGBO(255, 244, 200, alpha),
          const Color(0x00FFF4C8),
        ]);
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(math.sin(-spread) * len, math.cos(-spread) * len)
        ..lineTo(math.sin(spread) * len, math.cos(spread) * len)
        ..close();
      canvas.drawPath(path, shaftPaint);
      canvas.restore();
    }
    canvas.restore();
  }

  void _drawClouds(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const puffs = [
      [0.0, 0.0, 1.0],
      [0.7, 0.15, 0.75],
      [-0.7, 0.15, 0.75],
      [0.35, -0.3, 0.7],
      [-0.35, -0.25, 0.65],
    ];
    for (final c in clouds) {
      final x = c.x * w, y = c.y * h, s = c.s * w * 0.13;
      for (final p in puffs) {
        final px = x + p[0] * s, py = y + p[1] * s, pr = s * p[2];
        final paint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(px, py),
            pr,
            [
              Color.fromRGBO(255, 255, 255, 0.95 * c.a),
              Color.fromRGBO(245, 250, 255, 0.55 * c.a),
              const Color(0x00F5FAFF),
            ],
            const [0.0, 0.7, 1.0],
          );
        canvas.drawCircle(Offset(px, py), pr, paint);
      }
    }
  }

  void _drawBirds(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xB82D323C);
    for (final b in birds) {
      final x = b.x * w, y = b.y * h, s = b.size;
      final wing = math.sin(b.flap) * s * 0.55 + s * 0.15;
      paint.strokeWidth = s * 0.14;
      final path = Path()..moveTo(x - s, y);
      path.quadraticBezierTo(x - s * 0.4, y - wing, x, y - wing * 0.35);
      path.quadraticBezierTo(x + s * 0.4, y - wing, x + s, y);
      canvas.drawPath(path, paint);
    }
  }

  void _drawLeaves(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final l in leaves) {
      final swayX = math.sin(t * l.swayFreq + l.swayPhase) * l.swayAmp;
      final x = (l.x + swayX) * w;
      final y = l.y * h;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(l.rot + math.sin(t * l.swayFreq + l.swayPhase) * 0.5);
      final s = l.size;
      final bodyPaint = Paint()
        ..shader = ui.Gradient.linear(Offset(-s, 0), Offset(s, 0), [
          l.color,
          const Color(0xE61E4600),
        ]);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 2, height: s * 0.84),
        bodyPaint,
      );
      final spinePaint = Paint()
        ..color = const Color(0x8C143708)
        ..strokeWidth = math.max(0.6, s * 0.06);
      canvas.drawLine(Offset(-s * 0.9, 0), Offset(s * 0.9, 0), spinePaint);
      canvas.restore();
    }
  }

  void _drawSand(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = const Color(0xFFD9B878);
    for (final g in sand) {
      final y = (g.baseY + math.sin(t * g.freq + g.phase) * g.amp) * h;
      paint.color = const Color(0xFFD9B878).withValues(alpha: g.a);
      canvas.drawCircle(Offset(g.x * w, y), g.size, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawRays(canvas, size);
    _drawClouds(canvas, size);
    _drawBirds(canvas, size);
    _drawLeaves(canvas, size);
    _drawSand(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) => true;
}
