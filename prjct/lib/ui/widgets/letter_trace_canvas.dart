import 'package:flutter/material.dart';
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
    this.showPassBurst = true,
  });

  final bool passed;
  final bool failed;
  final AnimationController breathe;
  final List<List<Offset>> Function(Size size) guidePointsBuilder;
  final void Function(List<List<Offset>> userStrokes, Size canvasSize) onStroke;
  final VoidCallback onDirectionViolation;

  /// Whether to play the milestone-burst Lottie on [passed]. Trace
  /// Activity wants it; Hot Seat doesn't gate on a pass threshold, so it
  /// opts out.
  final bool showPassBurst;

  @override
  State<LetterTraceCanvas> createState() => _LetterTraceCanvasState();
}

class _LetterTraceCanvasState extends State<LetterTraceCanvas>
    with SingleTickerProviderStateMixin {
  final _strokes = <List<Offset>>[];
  final _key = GlobalKey();

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
    final currentStrokeIdx = _strokes.length - 1;
    final badges = _numberedBadges(widget.guidePointsBuilder(size));

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
      }
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    final size = _canvasSize;
    final startPt = event.localPosition;

    if (size != null) {
      final guideStrokes = widget.guidePointsBuilder(size);
      final currentStrokeIdx = _strokes.length;
      if (currentStrokeIdx < guideStrokes.length) {
        final guide = guideStrokes[currentStrokeIdx];
        if (guide.length == 1) {
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
      if (size != null) _registerTouch(startPt, size);
    });

    // A tap (down + up with no move in between, e.g. placing a diacritic
    // dot) never fires a move event, so without this the dot renders but
    // is never scored.
    if (size != null) widget.onStroke(_strokes, size);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_strokes.isEmpty) return;
    final size = _canvasSize;
    final newPoint = event.localPosition;
    final currentStroke = _strokes.last;

    setState(() {
      currentStroke.add(newPoint);
      if (size != null) _registerTouch(newPoint, size);
    });

    if (size != null) widget.onStroke(_strokes, size);
  }

  void clear() => setState(_strokes.clear);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3A1E), Color(0xFF2F2410)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.goldTint,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.goldSoft, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
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
                        ),
                        child: widget.passed && widget.showPassBurst
                            ? Center(
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: Lottie.asset(
                                    'assets/lottie/milestone_burst.json',
                                    repeat: false,
                                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
      ),
    );
  }
}

// ─── Painter ────────────────────────────────────────────────────────────

typedef _Badge = ({int number, Offset pos, int strokeIndex, bool isEnd});

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
  });

  final List<List<Offset>> Function(Size size) guideBuilder;
  final List<List<Offset>> userStrokes;
  final Color strokeColor;
  final double guideOpacity;

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
        if (stroke.length == 1) canvas.drawCircle(stroke.first, 13, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
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
      final elapsed = DateTime.now().difference(hitAt).inMilliseconds.toDouble();
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

  @override
  void paint(Canvas canvas, Size size) {
    final guideStrokes = guideBuilder(size);
    _paintGuideBody(canvas, guideStrokes);
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

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) =>
      oldDelegate.userStrokes != userStrokes ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.guideOpacity != guideOpacity ||
      oldDelegate.demoProgress != demoProgress;
}
