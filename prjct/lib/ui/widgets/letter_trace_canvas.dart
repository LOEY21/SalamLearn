import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';

/// Shared tracing canvas: numbered start/finish badges per stroke, a
/// looping "shadow" demo that shows stroke order/direction, and the
/// learner's own ink — used by both the Learner Hub's [TraceActivity] and
/// the Teacher Hub's Hot Seat canvas so both present letters identically.
///
/// Uses raw pointer events ([Listener]) rather than
/// `GestureDetector.onPan*` so it stays gesture-safe when embedded inside
/// a scrolling ancestor (a `GestureDetector`'s pan recognizer competes with
/// a `SingleChildScrollView`'s own drag recognizer in the gesture arena and
/// intermittently loses it, cutting strokes short) — this matters for Hot
/// Seat, which lives inside a `SingleChildScrollView` on the Cast screen.
class LetterTraceCanvas extends StatefulWidget {
  const LetterTraceCanvas({
    super.key,
    required this.passed,
    required this.failed,
    required this.breathe,
    required this.guidePointsBuilder,
    required this.onStroke,
    required this.onDirectionViolation,
    required this.coverTolerance,
    this.showPassBurst = true,
    this.glyphBuilder,
  });

  final bool passed;
  final bool failed;
  final AnimationController breathe;
  final List<List<Offset>> Function(Size size) guidePointsBuilder;
  final void Function(List<List<Offset>> userStrokes, Size canvasSize) onStroke;
  final VoidCallback onDirectionViolation;

  /// How close (in canvas px) the learner's ink must pass to a guide point
  /// to "cover" it — drives the double-masking reveal (see
  /// `_TracePainter._paintGuideReveal`). Deliberately tighter than the
  /// scoring tolerance `TraceActivity._computeAccuracy` uses for its
  /// recall/pass check — that one stays lenient so near-misses still pass,
  /// but a lenient radius here made the reveal spread out from a single
  /// touch instead of only filling in along the actual dragged path.
  final double coverTolerance;

  /// Whether to play the milestone-burst Lottie on [passed]. Trace
  /// Activity wants it; Hot Seat doesn't gate on a pass threshold, so it
  /// opts out.
  final bool showPassBurst;

  /// The letter's real outline, scaled to the canvas. When given, it's the
  /// double mask: the faint letter drawn under everything, and the
  /// learner's ink and the traced-so-far reveal kept strictly inside it, so
  /// tracing fills the letter in and nothing shows outside it. Hot Seat
  /// passes none and keeps its plain band and ink.
  final Path Function(Size size)? glyphBuilder;

  @override
  State<LetterTraceCanvas> createState() => _LetterTraceCanvasState();
}

class _LetterTraceCanvasState extends State<LetterTraceCanvas>
    with SingleTickerProviderStateMixin {
  final _strokes = <List<Offset>>[];
  final _key = GlobalKey();

  /// Which guide stroke each entry in [_strokes] was drawn for. A finger
  /// lift doesn't finish a stroke — only reaching its finish badge does —
  /// so one guide stroke can be traced in several pieces without shifting
  /// every later stroke out of step (e.g. ج, whose step 3 starts right on
  /// step 1's line).
  final _strokeGuide = <int>[];

  /// The guide stroke the learner is on: advances when its finish badge
  /// (or a dot's only badge) is reached.
  var _active = 0;

  /// [_strokes] merged per guide stroke, in guide order — what scoring
  /// compares against guide stroke i.
  List<List<Offset>> _perGuide(int count) => [
    for (var i = 0; i < count; i++)
      [
        for (var s = 0; s < _strokes.length; s++)
          if (_strokeGuide[s] == i) ..._strokes[s],
      ],
  ];

  /// Sand kicked up by the finger inside the letter, drawn by
  /// `_TracePainter._paintSand`. Each grain's path is a pure function of
  /// its age, so nothing is simulated per frame.
  final _grains = <_Grain>[];
  final _rng = math.Random();
  var _dustTravel = 0.0;

  static const _sandColors = [
    Color(0xFFF3DDAA),
    Color(0xFFE8C98A),
    Color(0xFFD9AE62),
    Color(0xFFC4934A),
    Color(0xFFA9773A),
  ];

  /// Throws grains out from [at] — forward and sideways along the drag
  /// from [from], or all around for a fresh touch — plus a soft dust puff
  /// every so often. Only inside the letter's shadow.
  void _spray(Offset at, Offset? from, Size size) {
    final glyph = widget.glyphBuilder?.call(size);
    if (glyph == null || !glyph.contains(at)) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final now = DateTime.now();
    _grains.removeWhere(
      (g) => now.difference(g.born).inMilliseconds > g.lifeMs,
    );

    final d = from == null ? 0.0 : (at - from).distance;
    final dir = d > 0 ? math.atan2(at.dy - from!.dy, at.dx - from.dx) : null;
    final count = dir == null ? 14 : (d / 3).clamp(1, 8).round();
    double jitter(double s) => (_rng.nextDouble() - .5) * s;
    for (var i = 0; i < count; i++) {
      final angle = dir == null
          ? _rng.nextDouble() * 2 * math.pi
          : dir + jitter(3.4);
      final speed = 60 + _rng.nextDouble() * 200;
      _grains.add((
        at: at + Offset(jitter(10), jitter(10)),
        v: Offset(math.cos(angle), math.sin(angle)) * speed,
        vz: 50 + _rng.nextDouble() * 170,
        born: now,
        lifeMs: 450 + _rng.nextInt(450),
        r: .7 + _rng.nextDouble() * 1.6,
        color: _sandColors[_rng.nextInt(_sandColors.length)],
        dust: false,
      ));
    }

    _dustTravel += d;
    if (dir == null || _dustTravel > 24) {
      _dustTravel = 0;
      _grains.add((
        at: at,
        v: Offset(jitter(60), jitter(60)),
        vz: 0,
        born: now,
        lifeMs: 650 + _rng.nextInt(300),
        r: 7 + _rng.nextDouble() * 5,
        color: _sandColors[1],
        dust: true,
      ));
    }
    if (_grains.length > 320) _grains.removeRange(0, _grains.length - 320);
  }

  void _emit(Size size) =>
      widget.onStroke(_perGuide(widget.guidePointsBuilder(size).length), size);

  /// Per guide stroke, per point: whether any user ink has passed within
  /// `widget.coverTolerance` of it — drives `_TracePainter`'s revealed
  /// (double-masking) layer. Recomputed only when `_strokes` actually
  /// changes (pointer down/move), not inside `paint()`, since `paint()`
  /// reruns every frame from the breathing/demo-shadow animations and a
  /// fresh guide×user distance scan there would run continuously instead
  /// of just on stroke updates.
  List<List<bool>> _coveredMask = [];

  void _recomputeCoveredMask(Size size) {
    final guideStrokes = widget.guidePointsBuilder(size);
    _coveredMask = [
      for (final guide in guideStrokes)
        [
          for (final gp in guide)
            _strokes.any(
              (s) => s.any((up) => (up - gp).distance <= widget.coverTolerance),
            ),
        ],
    ];
  }

  /// Drives the traveling "shadow" that demonstrates the stroke order and
  /// direction — loops continuously so a learner who's stuck can just
  /// watch it a second time instead of the demo playing once and vanishing.
  late final _guideDemo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  /// First-touched timestamp per badge number — drives each badge's pop
  /// animation in [_TracePainter] (elapsed-time-since-hit, not a separate
  /// AnimationController per badge) and its permanent "reached" color once
  /// settled. Recreated fresh whenever the canvas clears, since callers
  /// give this widget a new `ValueKey` and remount the state.
  final _badgeHitAt = <int, DateTime>{};

  Size? get _canvasSize =>
      (_key.currentContext?.findRenderObject() as RenderBox?)?.size;

  @override
  void dispose() {
    _guideDemo.dispose();
    super.dispose();
  }

  /// Marks any not-yet-hit badge within touch tolerance of [point] as hit
  /// — called after every point added to a stroke (tap or drag) so the
  /// feedback fires the instant the learner's finger passes near a
  /// start/finish number, not just when a stroke completes.
  void _registerTouch(Offset point, Size size) {
    if (_strokes.isEmpty) return;
    final currentStrokeIdx = _strokeGuide.last;
    final guideStrokes = widget.guidePointsBuilder(size);
    final badges = _numberedBadges(guideStrokes);

    for (final badge in badges) {
      if (_badgeHitAt.containsKey(badge.number)) continue;

      // Enforce active stroke constraint: only allow hitting badges belonging to the current guide stroke
      if (badge.strokeIndex != currentStrokeIdx) continue;

      // Enforce start-to-end constraint: if this is an end badge, the start badge must be hit first
      if (badge.isEnd) {
        final startBadgeNumber = badge.number - 1;
        if (!_badgeHitAt.containsKey(startBadgeNumber)) continue;
      }

      if ((point - badge.pos).distance <= 32) {
        _badgeHitAt[badge.number] = DateTime.now();
        final finishes =
            badge.isEnd || guideStrokes[badge.strokeIndex].length == 1;
        if (finishes && badge.strokeIndex == _active) _active++;
      }
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    final size = _canvasSize;
    final startPt = event.localPosition;

    if (size != null) {
      final guideStrokes = widget.guidePointsBuilder(size);
      final currentStrokeIdx = _active;
      if (currentStrokeIdx < guideStrokes.length) {
        final guide = guideStrokes[currentStrokeIdx];
        if (guide.length >= 2 && _strokeGuide.contains(currentStrokeIdx)) {
          // Picking an unfinished stroke back up after a lift: anywhere
          // along it is fine, but a touch far off it is stray.
          if (guide.every((g) => (startPt - g).distance > 60)) return;
        } else if (guide.length == 1) {
          // Single-point stroke (a diacritic dot): a touch that lands
          // nowhere near it is the learner reaching for a different dot
          // out of authored order — ignore rather than let it consume
          // this stroke slot and desync every stroke that follows.
          if ((startPt - guide.first).distance > 40) return;
        } else if (guide.length >= 2) {
          final distToStart = (startPt - guide.first).distance;
          final distToEnd = (startPt - guide.last).distance;
          // Not near this stroke at all (e.g. the touch was meant for a
          // later checkpoint, like a dot, reached for out of order) — a
          // stray touch like that isn't a reversed attempt on THIS stroke,
          // so don't misread it as one.
          if (distToStart >= 60 && distToEnd >= 60) return;
          final guideLen = (guide.first - guide.last).distance;
          if (guideLen > 60 && distToEnd < distToStart - 40) {
            widget.onDirectionViolation();
            return;
          }
        }
      }
    }

    setState(() {
      _strokes.add([startPt]);
      _strokeGuide.add(_active);
      if (size != null) {
        _registerTouch(startPt, size);
        _recomputeCoveredMask(size);
        _spray(startPt, null, size);
      }
    });

    // A tap (down + up with no move in between, e.g. placing a diacritic
    // dot) never fires a move event, so without this the dot renders but
    // is never scored.
    if (size != null) _emit(size);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_strokes.isEmpty) return;
    final size = _canvasSize;
    final newPoint = event.localPosition;
    final currentStroke = _strokes.last;

    setState(() {
      final prev = currentStroke.last;
      currentStroke.add(newPoint);
      if (size != null) {
        _registerTouch(newPoint, size);
        _recomputeCoveredMask(size);
        _spray(newPoint, prev, size);
      }
    });

    if (size != null) _emit(size);
  }

  void clear() => setState(() {
    _strokes.clear();
    _strokeGuide.clear();
    _active = 0;
    _coveredMask = [];
  });

  @override
  Widget build(BuildContext context) {
    // No boxed card — traces directly over the sandbox scenery behind it
    // (`TraceActivity`'s background), so the whole desert scene is the
    // tracing surface instead of a separate cream/gold-bordered panel.
    return SizedBox.expand(
      child: GestureDetector(
        // Absorb pan gestures so an ancestor ScrollView can't claim the
        // arena; actual tracing goes through Listener's raw pointer
        // events below, not these callbacks.
        onVerticalDragStart: (_) {},
        onVerticalDragUpdate: (_) {},
        onHorizontalDragStart: (_) {},
        onHorizontalDragUpdate: (_) {},
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          child: AnimatedBuilder(
            animation: Listenable.merge([widget.breathe, _guideDemo]),
            builder: (context, _) {
              final glow = Curves.easeInOut.transform(widget.breathe.value);
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      key: _key,
                      painter: _TracePainter(
                        guideBuilder: widget.guidePointsBuilder,
                        userStrokes: _strokes,
                        strokeColor: widget.passed
                            ? AppColors.adventureGreen
                            : widget.failed
                            ? AppColors.coral
                            : AppColors.gold,
                        guideOpacity: 0.30 + 0.15 * glow,
                        demoProgress: _guideDemo.value,
                        badgeHitAt: _badgeHitAt,
                        coveredMask: _coveredMask,
                        glyphBuilder: widget.glyphBuilder,
                        grains: _grains,
                      ),
                      child: widget.passed && widget.showPassBurst
                          ? Center(
                              child: SizedBox(
                                width: 96,
                                height: 96,
                                child: Lottie.asset(
                                  'assets/lottie/milestone_burst.json',
                                  repeat: false,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Painter ────────────────────────────────────────────────────────────

typedef _Badge = ({int number, Offset pos, int strokeIndex, bool isEnd});

/// One kicked-up sand grain (or, with [dust], a soft dust puff): thrown
/// from [at] with ground velocity [v] and upward speed [vz], px/s.
typedef _Grain = ({
  Offset at,
  Offset v,
  double vz,
  DateTime born,
  int lifeMs,
  double r,
  Color color,
  bool dust,
});

/// Numbers every guide stroke's start/finish in authored order — e.g.
/// stroke 0 gets "1" at its start and "2" at its end, stroke 1 gets
/// "3"/"4", and so on; a single-point stroke (a diacritic dot) just gets
/// one number since start and finish are the same spot. Shared by the
/// painter (to draw the badges) and the canvas state (to detect when a
/// touch has passed near one) so the two can never number differently.
List<_Badge> _numberedBadges(List<List<Offset>> guideStrokes) {
  final badges = <_Badge>[];
  var n = 1;
  for (var i = 0; i < guideStrokes.length; i++) {
    final guide = guideStrokes[i];
    if (guide.isEmpty) continue;
    if (guide.length == 1) {
      badges.add((number: n, pos: guide.first, strokeIndex: i, isEnd: false));
      n++;
      continue;
    }
    badges.add((number: n, pos: guide.first, strokeIndex: i, isEnd: false));
    n++;
    badges.add((number: n, pos: guide.last, strokeIndex: i, isEnd: true));
    n++;
  }
  return badges;
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.guideBuilder,
    required this.userStrokes,
    required this.strokeColor,
    required this.guideOpacity,
    required this.demoProgress,
    required this.badgeHitAt,
    required this.coveredMask,
    this.glyphBuilder,
    this.grains = const [],
  });

  final List<_Grain> grains;
  final List<List<Offset>> Function(Size size) guideBuilder;
  final Path Function(Size size)? glyphBuilder;
  final List<List<Offset>> userStrokes;
  final Color strokeColor;
  final double guideOpacity;

  /// Precomputed by `_LetterTraceCanvasState._recomputeCoveredMask` (not
  /// here — see that method's doc for why) — per guide stroke, per point,
  /// whether the learner's ink has already passed near it. Drives
  /// `_paintGuideReveal`'s double-masking layer.
  final List<List<bool>> coveredMask;

  /// Badge number → the moment the learner's touch first passed near it
  /// (see `_LetterTraceCanvasState._registerTouch`) — drives each badge's
  /// pop-then-settle feedback animation via wall-clock elapsed time rather
  /// than a dedicated `AnimationController` per badge.
  final Map<int, DateTime> badgeHitAt;

  /// 0..1, loops continuously — position of the animated "shadow" that
  /// demonstrates where to trace, expressed as a fraction of the whole
  /// letter (every guide stroke gets an equal time slice, visited in
  /// their authored order).
  final double demoProgress;

  /// Paints the letter itself as a soft translucent band tracing exactly
  /// [guideStrokes] — the same coordinates used for scoring and the
  /// numbered badges, so the visible letter, the badges, and the accuracy
  /// check always agree on exactly the same shape.
  void _paintGuideBody(Canvas canvas, List<List<Offset>> guideStrokes) {
    final paint = Paint()
      ..color = const Color(0xFF4A3A1E).withValues(alpha: guideOpacity)
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in guideStrokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(
            stroke.first,
            13,
            paint..style = PaintingStyle.fill,
          );
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  /// Double-masking reveal: [_paintGuideBody] is the constant faint base
  /// mask for the whole letter; this draws a second, bold, filled mask —
  /// in [strokeColor], the same color the learner's own ink uses — but
  /// only over the sub-segments [coveredMask] marks as already traced, so
  /// tracing progress reads as the guide visibly "filling in" instead of
  /// only the separate numeric accuracy bar moving.
  void _paintGuideReveal(
    Canvas canvas,
    List<List<Offset>> guideStrokes, {
    double width = 26,
  }) {
    final paint = Paint()
      ..color = strokeColor.withValues(alpha: 0.92)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < guideStrokes.length; i++) {
      final stroke = guideStrokes[i];
      final covered = i < coveredMask.length ? coveredMask[i] : const <bool>[];

      if (stroke.length == 1) {
        if (covered.isNotEmpty && covered[0]) {
          canvas.drawCircle(
            stroke.first,
            width / 2,
            paint..style = PaintingStyle.fill,
          );
        }
        continue;
      }
      if (stroke.length < 2 || covered.length != stroke.length) continue;

      var runStart = -1;
      for (var j = 0; j <= stroke.length; j++) {
        final isCovered = j < stroke.length && covered[j];
        if (isCovered && runStart == -1) {
          runStart = j;
        } else if (!isCovered && runStart != -1) {
          if (j - runStart >= 2) {
            final path = Path()
              ..moveTo(stroke[runStart].dx, stroke[runStart].dy);
            for (var k = runStart + 1; k < j; k++) {
              path.lineTo(stroke[k].dx, stroke[k].dy);
            }
            canvas.drawPath(path, paint..style = PaintingStyle.stroke);
          }
          runStart = -1;
        }
      }
    }
  }

  /// Position [demoProgress] along the letter, giving every guide stroke
  /// an equal time slice (visit order = authored order) rather than
  /// weighting by each stroke's actual pixel length — simpler and keeps
  /// short strokes (like a diacritic dot) from flashing past too fast to
  /// register.
  Offset? _demoPosition(List<List<Offset>> guideStrokes) {
    final strokes = guideStrokes.where((s) => s.isNotEmpty).toList();
    if (strokes.isEmpty) return null;
    final slice = 1 / strokes.length;
    var strokeIdx = (demoProgress / slice).floor().clamp(0, strokes.length - 1);
    final localT = ((demoProgress - strokeIdx * slice) / slice).clamp(0.0, 1.0);
    final pts = strokes[strokeIdx];
    if (pts.length == 1) return pts.first;
    final f = localT * (pts.length - 1);
    final i0 = f.floor().clamp(0, pts.length - 2);
    final frac = f - i0;
    return Offset.lerp(pts[i0], pts[i0 + 1], frac);
  }

  Offset? _demoPositionAt(List<List<Offset>> guideStrokes, double t) {
    final strokes = guideStrokes.where((s) => s.isNotEmpty).toList();
    if (strokes.isEmpty) return null;
    final slice = 1 / strokes.length;
    final strokeIdx = (t / slice).floor().clamp(0, strokes.length - 1);
    final localT = ((t - strokeIdx * slice) / slice).clamp(0.0, 1.0);
    final pts = strokes[strokeIdx];
    if (pts.length == 1) return pts.first;
    final f = localT * (pts.length - 1);
    final i0 = f.floor().clamp(0, pts.length - 2);
    final frac = f - i0;
    return Offset.lerp(pts[i0], pts[i0 + 1], frac);
  }

  /// The traveling "shadow" itself — a soft blurred dot with a short
  /// fading tail behind it, tracking [_demoPosition] each frame so the
  /// motion (not just the static numbers) shows how to trace the letter.
  void _paintDemoShadow(Canvas canvas, List<List<Offset>> guideStrokes) {
    final pos = _demoPosition(guideStrokes);
    if (pos == null) return;
    for (var i = 4; i >= 0; i--) {
      final t = (demoProgress - i * 0.012).clamp(0.0, 1.0);
      final trailPos = i == 0 ? pos : _demoPositionAt(guideStrokes, t);
      if (trailPos == null) continue;
      final alpha = (1 - i / 5) * 0.4;
      canvas.drawCircle(
        trailPos,
        16 - i * 1.6,
        Paint()
          ..color = AppColors.gold.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  /// Drawn for every guide badge regardless of progress so the learner
  /// always has the full sequence to reference; a badge's own look changes
  /// once [badgeHitAt] records it as touched (see [_paintBadge]).
  void _paintStrokeNumbers(Canvas canvas, List<List<Offset>> guideStrokes) {
    for (final badge in _numberedBadges(guideStrokes)) {
      _paintBadge(canvas, badge.pos, badge.number, badgeHitAt[badge.number]);
    }
  }

  /// Untouched: a plain gold-ringed dot with its number. Touched: pops
  /// (scale 1 → 1.5 → settles at 1.15) and turns green over ~260ms — the
  /// "yes, you're doing it right" feedback — then stays that way for the
  /// rest of this stroke's attempt.
  void _paintBadge(Canvas canvas, Offset at, int number, DateTime? hitAt) {
    const restRadius = 11.0;
    var scale = 1.0;
    var fill = const Color(0xFF4A3A1E).withValues(alpha: guideOpacity + 0.35);
    var ring = AppColors.gold;

    if (hitAt != null) {
      const popMs = 260.0;
      final elapsed = DateTime.now()
          .difference(hitAt)
          .inMilliseconds
          .toDouble();
      final t = (elapsed / popMs).clamp(0.0, 1.0);
      scale = t < 0.45
          ? 1.0 + 0.5 * (t / 0.45)
          : 1.5 - 0.35 * ((t - 0.45) / 0.55);
      fill = AppColors.adventureGreen;
      ring = Colors.white;
    }

    final radius = restRadius * scale;
    canvas.drawCircle(at, radius, Paint()..color = fill);
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          fontSize: 12 * scale,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  /// Grains skid out and slow to a stop (drag), hopping up and falling back
  /// (gravity) with a small shadow under them while airborne, then fade
  /// where they land. Dust puffs drift, swell and thin out.
  void _paintSand(Canvas canvas) {
    const drag = 6.0, gravity = 1100.0;
    final now = DateTime.now();
    for (final g in grains) {
      final t = now.difference(g.born).inMicroseconds / 1e6;
      final life = g.lifeMs / 1000;
      if (t < 0 || t >= life) continue;
      final fade = t < life * .55 ? 1.0 : 1 - (t - life * .55) / (life * .45);
      if (g.dust) {
        canvas.drawCircle(
          g.at + g.v * t,
          g.r * (1 + t * 2.5),
          Paint()
            ..color = g.color.withValues(alpha: .28 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
        continue;
      }
      final ground = g.at + g.v * ((1 - math.exp(-drag * t)) / drag);
      final h = math.max(0.0, g.vz * t - .5 * gravity * t * t);
      if (h > 0) {
        canvas.drawCircle(
          ground,
          g.r * .9,
          Paint()
            ..color = const Color(0xFF4A3A1E).withValues(alpha: .22 * fade),
        );
      }
      canvas.drawCircle(
        ground.translate(0, -h),
        g.r,
        Paint()..color = g.color.withValues(alpha: fade),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final guideStrokes = guideBuilder(size);
    final glyph = glyphBuilder?.call(size);
    if (glyph != null) {
      _paintInGlyph(canvas, size, glyph, guideStrokes);
      _paintSand(canvas);
      _paintDemoShadow(canvas, guideStrokes);
      _paintStrokeNumbers(canvas, guideStrokes);
      return;
    }
    _paintGuideBody(canvas, guideStrokes);
    _paintGuideReveal(canvas, guideStrokes);
    _paintDemoShadow(canvas, guideStrokes);
    _paintStrokeNumbers(canvas, guideStrokes);

    final userPaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in userStrokes) {
      if (stroke.length > 1) {
        final userPath = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        var prev = stroke.first;
        for (final p in stroke.skip(1)) {
          if ((p - prev).distance > 2.0) {
            userPath.lineTo(p.dx, p.dy);
            prev = p;
          }
        }
        if (prev != stroke.last) {
          userPath.lineTo(stroke.last.dx, stroke.last.dy);
        }
        canvas.drawPath(userPath, userPaint);
      } else if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 5.5, Paint()..color = strokeColor);
      }
    }
  }

  /// [strokes] as one path; single points (dots) become tiny ovals so a
  /// round stroke turns them into discs.
  static Path _path(List<List<Offset>> strokes) {
    final path = Path();
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        path.addOval(Rect.fromCircle(center: stroke.first, radius: 0.5));
        continue;
      }
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  /// How much the letter's outline is fattened (stroke width, px) so a
  /// child's finger fits comfortably inside even the thinner strokes.
  static const _glyphSpread = 12.0;

  /// Width of the traced fill as a fraction of the letter's longer side —
  /// wide enough to cover a stroke's full thickness (the fill is cut to the
  /// letter's shape anyway), narrow enough not to reach a neighbouring dot.
  static const _fillFraction = 0.16;

  static void _drawGlyph(Canvas canvas, Path glyph, Paint paint) {
    canvas.drawPath(glyph, paint..style = PaintingStyle.fill);
    canvas.drawPath(
      glyph,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = _glyphSpread
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Double mask. Mask one: the letter itself, faint, pressed into the
  /// sand. Mask two: the traced-so-far reveal and the learner's ink, drawn
  /// wide and cut to the letter's shape, so tracing fills the whole shape
  /// and nothing ever lands outside it.
  void _paintInGlyph(
    Canvas canvas,
    Size size,
    Path glyph,
    List<List<Offset>> guideStrokes,
  ) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(
      bounds,
      Paint()..color = Color.fromRGBO(0, 0, 0, guideOpacity),
    );
    _drawGlyph(canvas, glyph, Paint()..color = const Color(0xFF4A3A1E));
    canvas.restore();
    final fillWidth =
        glyph.getBounds().longestSide * _fillFraction + _glyphSpread;
    canvas.saveLayer(bounds, Paint());
    _paintGuideReveal(canvas, guideStrokes, width: fillWidth);
    canvas.drawPath(
      _path(userStrokes),
      Paint()
        ..color = strokeColor
        ..strokeWidth = fillWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
    _drawGlyph(canvas, glyph, Paint()..color = const Color(0xFF000000));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) =>
      oldDelegate.userStrokes != userStrokes ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.guideOpacity != guideOpacity ||
      oldDelegate.demoProgress != demoProgress ||
      oldDelegate.coveredMask != coveredMask;
}
