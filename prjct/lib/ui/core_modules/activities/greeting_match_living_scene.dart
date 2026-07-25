import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/scheduler.dart';

/// Greeting Match's animated background — ports the project owner's
/// "Living Scene" HTML/CSS prototype (sun rays, drifting clouds, flapping
/// birds, waterfall sparkle, falling leaves, twinkling sparkles, and a
/// tap-to-scatter gold burst) onto the same static `greeting_match_bg.png`
/// used before. One [Ticker]-driven elapsed-time clock feeds every looping
/// layer instead of one `AnimationController` per element — each layer just
/// reads its own phase out of the shared clock via [_phase], mirroring how
/// the CSS prototype scaled every `animation-duration` off a single `--spd`
/// custom property.
///
/// Ambient layers (rays/clouds/birds/waterfall/leaves/sparkles) are purely
/// decorative — wrapped in [IgnorePointer] so they never steal taps from
/// [child]'s real buttons, which are stacked on top. A translucent
/// full-size [GestureDetector] sits between the ambient layers and [child]
/// to catch taps that land on empty background (not on a button) and spawn
/// the scatter burst + bird startle, same as the prototype's whole-scene
/// `onClick`.
class GreetingMatchLivingScene extends StatefulWidget {
  const GreetingMatchLivingScene({super.key, required this.child});

  final Widget child;

  @override
  State<GreetingMatchLivingScene> createState() =>
      _GreetingMatchLivingSceneState();
}

class _BurstParticle {
  _BurstParticle(this.spawnedAt, this.angle, this.distance);
  final double spawnedAt;
  final double angle;
  final double distance;
}

class _Burst {
  _Burst(this.spawnedAt, this.dx, this.dy)
    : particles = List.generate(
        9,
        (i) => _BurstParticle(
          spawnedAt,
          (i / 9) * math.pi * 2,
          26 + (i * 37 % 26).toDouble(),
        ),
      );
  final double spawnedAt;
  final double dx;
  final double dy;
  final List<_BurstParticle> particles;
}

class _GreetingMatchLivingSceneState extends State<GreetingMatchLivingScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  double _scatterAt = -10;
  final List<_Burst> _bursts = [];

  static const _burstDuration = 0.7;
  static const _startleRise = 0.7;
  static const _startleHold = 1.5;
  static const _startleFall = 2.2;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _t = elapsed.inMicroseconds / 1e6);
      _bursts.removeWhere((b) => _t - b.spawnedAt > _burstDuration + 0.1);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Sawtooth 0→1 phase for a looping animation, matching a CSS
  /// `animation-duration: periodSeconds` with `animation-delay:
  /// -delaySeconds` (negative delay = start already partway into the loop).
  double _phase(double period, [double delay = 0]) =>
      ((_t + delay) % period) / period;

  /// `(1 - cos(2π·phase)) / 2` — 0 at phase 0, 1 at phase 0.5, back to 0 at
  /// phase 1. Used for every "dip/peak and return" CSS keyframe (bob,
  /// twinkle, ray pulse) instead of a per-element Curve.
  double _peak(double phase) => (1 - math.cos(phase * 2 * math.pi)) / 2;

  void _onScatterTap(TapUpDetails details, Size size) {
    final dx = details.localPosition.dx / size.width;
    final dy = details.localPosition.dy / size.height;
    setState(() {
      _scatterAt = _t;
      _bursts.add(_Burst(_t, dx, dy));
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                'assets/images/greeting_match/greeting_match_bg.png',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(child: _buildAmbientLayers(size)),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) => _onScatterTap(details, size),
                ),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmbientLayers(Size size) {
    return Stack(
      children: [
        ..._buildRays(size),
        ..._buildClouds(size),
        ..._buildBirds(size),
        ..._buildWaterfall(size),
        ..._buildLeaves(size),
        ..._buildSparkles(size),
        ..._buildBursts(size),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // SUN RAYS
  // ---------------------------------------------------------------------
  List<Widget> _buildRays(Size size) {
    const rays = [
      (left: 0.20, width: 0.11, height: 0.66, angle: 20.0, period: 7.0, delay: 0.0),
      (left: 0.42, width: 0.09, height: 0.60, angle: 22.0, period: 9.0, delay: 2.0),
      (left: 0.63, width: 0.12, height: 0.64, angle: 18.0, period: 8.0, delay: 4.0),
    ];
    return rays.map((r) {
      final opacity = 0.12 + _peak(_phase(r.period, r.delay)) * 0.26;
      return Positioned(
        top: -size.height * 0.14,
        left: size.width * r.left,
        width: size.width * r.width,
        height: size.height * r.height,
        child: Transform.rotate(
          alignment: Alignment.topCenter,
          angle: r.angle * math.pi / 180,
          child: Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFF6D6),
                    const Color(0xFFFFF6D6).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ---------------------------------------------------------------------
  // CLOUDS
  // ---------------------------------------------------------------------
  List<Widget> _buildClouds(Size size) {
    const clouds = [
      (top: 0.05, width: 0.27, height: 0.07, period: 60.0, delay: 0.0),
      (top: 0.13, width: 0.20, height: 0.055, period: 74.0, delay: 20.0),
      (top: 0.22, width: 0.16, height: 0.045, period: 66.0, delay: 42.0),
    ];
    return clouds.map((c) {
      final phase = _phase(c.period, c.delay);
      final left = -0.30 + phase * 1.60;
      return Positioned(
        top: size.height * c.top,
        left: size.width * left,
        width: size.width * c.width,
        height: size.height * c.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.9),
                Colors.white.withValues(alpha: 0.5),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.55, 0.72],
            ),
          ),
        ),
      );
    }).toList();
  }

  // ---------------------------------------------------------------------
  // BIRDS
  // ---------------------------------------------------------------------
  double _startleFactor() {
    final dt = _t - _scatterAt;
    if (dt < 0 || dt > _startleFall) return 0;
    if (dt < _startleRise) return Curves.easeOut.transform(dt / _startleRise);
    if (dt < _startleHold) return 1;
    return 1 - Curves.easeOut.transform((dt - _startleHold) / (_startleFall - _startleHold));
  }

  List<Widget> _buildBirds(Size size) {
    const birds = [
      (top: 0.11, scale: 1.0, period: 28.0, delay: 0.0, reverse: false, bobPeriod: 2.4, flapPeriod: 0.5, dir: -1),
      (top: 0.17, scale: 0.72, period: 34.0, delay: 6.0, reverse: false, bobPeriod: 2.8, flapPeriod: 0.6, dir: 1),
      (top: 0.09, scale: 0.85, period: 31.0, delay: 14.0, reverse: true, bobPeriod: 2.6, flapPeriod: 0.55, dir: -1),
      (top: 0.24, scale: 0.6, period: 40.0, delay: 24.0, reverse: false, bobPeriod: 3.0, flapPeriod: 0.65, dir: 1),
    ];
    final startle = _startleFactor();
    return birds.map((b) {
      final phase = _phase(b.period, b.delay);
      final left = b.reverse ? 1.30 - phase * 1.60 : -0.15 + phase * 1.45;
      final bob = -7 * _peak(_phase(b.bobPeriod));
      final flapScale = 1 - 0.55 * _peak(_phase(b.flapPeriod));
      final startleDy = -75 * startle * b.scale;
      final startleOpacity = 1 - 0.8 * startle;
      return Positioned(
        top: size.height * b.top + bob + startleDy,
        left: size.width * left + (b.dir * 55 * startle),
        child: Opacity(
          opacity: startleOpacity,
          child: Transform.scale(
            scaleX: (b.reverse ? -b.scale : b.scale) * (1 - 0.45 * startle),
            scaleY: b.scale * (1 - 0.45 * startle),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  alignment: Alignment.centerRight,
                  scaleY: flapScale,
                  child: _wing(),
                ),
                Transform.scale(
                  alignment: Alignment.centerLeft,
                  scaleY: flapScale,
                  child: _wing(),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _wing() => Container(
    width: 11,
    height: 7,
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFF4A3F35), width: 3)),
      borderRadius: BorderRadius.all(Radius.elliptical(11, 7)),
    ),
  );

  // ---------------------------------------------------------------------
  // WATERFALL SPARKLE + POND SHIMMER
  // ---------------------------------------------------------------------
  List<Widget> _buildWaterfall(Size size) {
    const droplets = [
      (left: 0.15, period: 1.6, delay: 0.0),
      (left: 0.42, period: 1.9, delay: 0.6),
      (left: 0.68, period: 1.4, delay: 1.0),
    ];
    final areaLeft = size.width * 0.64;
    final areaTop = size.height * 0.38;
    final areaW = size.width * 0.11;
    final areaH = size.height * 0.08;

    final dropletWidgets = droplets.map((d) {
      final phase = _phase(d.period, d.delay);
      final dy = -14 + phase * 60;
      final scaleY = 0.6 + phase * 0.8;
      final opacity = phase < 0.25 ? phase / 0.25 : (1 - phase) / 0.75;
      return Positioned(
        left: areaLeft + areaW * d.left,
        top: areaTop + dy,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scaleY: scaleY,
            child: Container(
              width: 4,
              height: 9,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    const Color(0xFFBEEBFF).withValues(alpha: 0.2),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.white, blurRadius: 5),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();

    const twinkles = [
      (left: 0.28, top: 0.20, period: 2.2, delay: 0.0, size: 5.0),
      (left: 0.58, top: 0.10, period: 1.8, delay: 0.8, size: 4.0),
    ];
    final twinkleWidgets = twinkles.map((s) {
      final peak = _peak(_phase(s.period, s.delay));
      return Positioned(
        left: areaLeft + areaW * s.left,
        top: areaTop + areaH * s.top,
        child: Opacity(
          opacity: 0.15 + peak * 0.85,
          child: Transform.scale(
            scale: 0.5 + peak * 0.65,
            child: _glowDot(s.size, const Color(0xFFFFFFFF)),
          ),
        ),
      );
    }).toList();

    final shimmerPhase = _phase(5.0);
    final shimmerLeft = size.width * 0.52;
    final shimmerTop = size.height * 0.435;
    final shimmerW = size.width * 0.25;
    final shimmerH = size.height * 0.03;
    final shimmer = Positioned(
      left: shimmerLeft,
      top: shimmerTop,
      width: shimmerW,
      height: shimmerH,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(shimmerH / 2),
        child: Stack(
          children: [
            Positioned(
              left: -shimmerW * 1.4 + shimmerPhase * shimmerW * 4.0,
              top: 0,
              width: shimmerW * 0.4,
              height: shimmerH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return [...dropletWidgets, ...twinkleWidgets, shimmer];
  }

  // ---------------------------------------------------------------------
  // FALLING LEAVES
  // ---------------------------------------------------------------------
  List<Widget> _buildLeaves(Size size) {
    const leaves = [
      (left: 0.12, period: 11.0, delay: 0.0, swayPeriod: 3.0, color1: 0xFFFFB300, color2: 0xFFF57C00, petal: false),
      (left: 0.26, period: 9.0, delay: 3.0, swayPeriod: 2.4, color1: 0xFF9CCC65, color2: 0xFF558B2F, petal: false),
      (left: 0.40, period: 13.0, delay: 6.0, swayPeriod: 3.4, color1: 0xFFF06292, color2: 0xFFF06292, petal: true),
      (left: 0.56, period: 10.0, delay: 2.0, swayPeriod: 2.8, color1: 0xFFFFCA28, color2: 0xFFFB8C00, petal: false),
      (left: 0.70, period: 12.0, delay: 8.0, swayPeriod: 3.1, color1: 0xFFAED581, color2: 0xFF689F38, petal: false),
      (left: 0.83, period: 8.5, delay: 4.0, swayPeriod: 2.6, color1: 0xFFBA68C8, color2: 0xFFBA68C8, petal: true),
      (left: 0.92, period: 14.0, delay: 10.0, swayPeriod: 3.3, color1: 0xFFFFB300, color2: 0xFFEF6C00, petal: false),
    ];
    return leaves.map((l) {
      final fallPhase = _phase(l.period, l.delay);
      final top = -0.08 + fallPhase * 1.18;
      final swaySin = math.sin(_phase(l.swayPeriod) * 2 * math.pi);
      final swayX = 12 * swaySin;
      final swayAngle = 25 * swaySin * math.pi / 180;
      return Positioned(
        left: size.width * l.left + swayX,
        top: size.height * top,
        child: Transform.rotate(
          angle: swayAngle,
          child: l.petal
              ? Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.white, Color(l.color1)],
                      stops: const [0.2, 0.22],
                    ),
                  ),
                )
              : Container(
                  width: 13,
                  height: 9,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(l.color1), Color(l.color2)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
        ),
      );
    }).toList();
  }

  // ---------------------------------------------------------------------
  // MAGIC SPARKLES
  // ---------------------------------------------------------------------
  List<Widget> _buildSparkles(Size size) {
    const sparkles = [
      (left: 0.08, top: 0.52, period: 3.2, delay: 0.0, gold: true),
      (left: 0.33, top: 0.47, period: 2.6, delay: 1.0, gold: false),
      (left: 0.78, top: 0.50, period: 3.6, delay: 2.0, gold: true),
      (left: 0.18, top: 0.63, period: 3.0, delay: 0.5, gold: false),
      (left: 0.60, top: 0.58, period: 2.8, delay: 1.5, gold: true),
      (left: 0.88, top: 0.66, period: 3.4, delay: 2.5, gold: false),
      (left: 0.44, top: 0.72, period: 3.1, delay: 0.8, gold: true),
      (left: 0.70, top: 0.78, period: 2.7, delay: 1.8, gold: false),
      (left: 0.25, top: 0.82, period: 3.5, delay: 2.2, gold: true),
      (left: 0.55, top: 0.88, period: 3.0, delay: 1.2, gold: false),
    ];
    return sparkles.map((s) {
      final peak = _peak(_phase(s.period, s.delay));
      final color = s.gold ? const Color(0xFFFFE082) : const Color(0xFFFFF59D);
      return Positioned(
        left: size.width * s.left,
        top: size.height * s.top,
        child: Opacity(
          opacity: 0.15 + peak * 0.85,
          child: Transform.scale(
            scale: 0.5 + peak * 0.65,
            child: _glowDot(6, color),
          ),
        ),
      );
    }).toList();
  }

  Widget _glowDot(double size, Color glow) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [Colors.white, glow, glow.withValues(alpha: 0)],
        stops: const [0.0, 0.45, 0.7],
      ),
      boxShadow: [BoxShadow(color: glow, blurRadius: 6)],
    ),
  );

  // ---------------------------------------------------------------------
  // TAP-TO-SCATTER GOLD BURST
  // ---------------------------------------------------------------------
  List<Widget> _buildBursts(Size size) {
    return _bursts.expand<Widget>((burst) {
      final dt = _t - burst.spawnedAt;
      if (dt < 0 || dt > _burstDuration) return const <Widget>[];
      final progress = Curves.easeOut.transform(dt / _burstDuration);
      final cx = burst.dx * size.width;
      final cy = burst.dy * size.height;
      return burst.particles.map((p) {
        final dist = p.distance * progress;
        final dx = math.cos(p.angle) * dist;
        final dy = math.sin(p.angle) * dist;
        return Positioned(
          left: cx + dx - 3.5,
          top: cy + dy - 3.5,
          child: Opacity(
            opacity: (1 - progress).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1 - progress,
              child: _glowDot(7, const Color(0xFFFFD54F)),
            ),
          ),
        );
      });
    }).toList();
  }
}
