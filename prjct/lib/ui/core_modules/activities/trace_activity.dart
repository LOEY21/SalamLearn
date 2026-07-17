import 'package:flutter/material.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/letter_trace_canvas.dart';

/// FR-4.1's Tactile Recognition Engine — tracks the learner's continuous
/// drag (X/Y samples) and validates it against a predefined right-to-left
/// vector path drawn in the actual shape of the Arabic letter on the card.
///
/// Each letter has a stroke path defined as waypoints tracing the isolated
/// form of the letter, extracted from the bundled Cairo font's own glyph
/// outlines (see `_paths` below) rather than eyeballed. Waypoints are
/// interpolated via Catmull-Rom spline so the guide path is smooth.

class TraceActivity extends StatefulWidget {
  const TraceActivity({
    super.key,
    required this.cards,
    required this.xp,
    required this.color,
    required this.onComplete,
  });

  final List<FlashCard> cards;
  final int xp;
  final Color color;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  @override
  State<TraceActivity> createState() => _TraceActivityState();
}

class _TraceActivityState extends State<TraceActivity>
    with TickerProviderStateMixin {
  int _idx = 0;
  double _accuracy = 0.0;
  bool _checked = false;
  bool _passed = false;
  double _accuracySum = 0.0;
  int _failedChecks = 0;

  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();
  late final _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);
  late final _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  static const _overshoot = Cubic(0.34, 1.56, 0.64, 1.0);
  static const _passThreshold = 0.75;
  static const _autoPassThreshold = 0.97;

  FlashCard get _card => widget.cards[_idx];

  /// Extracts the actual Arabic letter from the card's `arabic` field.
  /// Cards follow the format `"أَلِف\nا"` where the line after `\n` is the
  /// standalone letter shape the learner should trace.
  String get _letter {
    final parts = _card.arabic.split('\n');
    return (parts.length > 1 ? parts.last : _card.arabic).trim();
  }

  // ── Waypoint paths for each letter (normalised 0-1 coordinates) ──────
  // Each entry is [x1,y1, x2,y2, ...] defining key points on the letter's
  // stroke, interpolated with a Catmull-Rom spline for a smooth guide line.
  // Waypoints are extracted from the bundled Cairo font's actual isolated-
  // form glyph outlines (offline: rasterize -> skeletonize -> centerline),
  // not hand-eyeballed, so the guide matches the real letterform. ain/ghain,
  // qaf, heh and waw are kept hand-authored: their extracted centerlines
  // either looped back on themselves (heh/waw are closed counters, so the
  // start/end of the trace ended up on top of each other) or crossed
  // themselves badly (ain/ghain/qaf).
  static const _paths = <String, List<List<double>>>{
    'ا': [[0.49,0.89,0.47,0.83,0.47,0.77,0.47,0.71,0.47,0.65,0.47,0.59,0.47,0.52,0.47,0.46,0.47,0.40,0.47,0.34,0.47,0.28,0.47,0.22,0.47,0.16,0.45,0.10]],
    'ب': [[0.88,0.34,0.89,0.47,0.89,0.60,0.89,0.73,0.89,0.87,0.78,0.89,0.64,0.89,0.51,0.89,0.37,0.89,0.25,0.86,0.15,0.79,0.11,0.67,0.12,0.55,0.19,0.45], [0.48,1.05]],
    'ت': [[0.88,0.11,0.89,0.26,0.89,0.42,0.89,0.57,0.89,0.73,0.78,0.76,0.64,0.76,0.51,0.76,0.37,0.75,0.25,0.73,0.15,0.64,0.11,0.50,0.12,0.35,0.19,0.24], [0.41,0.13], [0.59,0.13]],
    'ث': [[0.88,0.10,0.89,0.23,0.89,0.35,0.89,0.48,0.89,0.61,0.78,0.63,0.64,0.63,0.51,0.63,0.37,0.63,0.25,0.61,0.15,0.54,0.11,0.42,0.12,0.30,0.19,0.21], [0.41,0.27], [0.59,0.27], [0.50,0.11]],
    'ج': [[0.69,0.92,0.47,0.90,0.25,0.87,0.14,0.76,0.18,0.63,0.37,0.57,0.60,0.56,0.84,0.56,0.87,0.43,0.87,0.29,0.81,0.16,0.61,0.10,0.38,0.10,0.16,0.09], [0.67,0.74]],
    'ح': [[0.78,0.91,0.56,0.90,0.32,0.88,0.15,0.80,0.15,0.66,0.32,0.57,0.55,0.56,0.80,0.56,0.87,0.45,0.87,0.31,0.82,0.17,0.62,0.10,0.38,0.10,0.16,0.09]],
    'خ': [[0.78,0.77,0.56,0.76,0.32,0.75,0.15,0.68,0.15,0.56,0.32,0.49,0.55,0.47,0.80,0.47,0.87,0.39,0.87,0.26,0.82,0.15,0.62,0.10,0.38,0.09,0.16,0.09], [0.48,-0.05]],
    'د': [[0.13,0.87,0.30,0.87,0.46,0.87,0.63,0.87,0.79,0.87,0.85,0.78,0.85,0.66,0.85,0.53,0.83,0.41,0.80,0.29,0.71,0.19,0.57,0.14,0.41,0.12,0.25,0.12]],
    'ذ': [[0.13,0.66,0.30,0.66,0.46,0.66,0.63,0.66,0.79,0.66,0.85,0.59,0.85,0.50,0.85,0.40,0.83,0.31,0.80,0.23,0.71,0.16,0.57,0.12,0.41,0.10,0.25,0.10], [0.22,-0.09]],
    'ر': [[0.78,0.10,0.79,0.17,0.79,0.25,0.79,0.33,0.79,0.40,0.79,0.48,0.79,0.55,0.79,0.63,0.78,0.70,0.74,0.77,0.65,0.84,0.47,0.88,0.26,0.89,0.07,0.93]],
    'ز': [[0.78,0.09,0.79,0.15,0.79,0.21,0.79,0.27,0.79,0.33,0.79,0.39,0.79,0.45,0.79,0.52,0.78,0.58,0.74,0.63,0.65,0.68,0.47,0.72,0.26,0.73,0.07,0.75], [0.85,-0.08]],
    'س': [[0.91,0.06,0.90,0.25,0.91,0.58,0.70,0.58,0.69,0.27,0.69,0.38,0.59,0.60,0.47,0.45,0.47,0.31,0.47,0.65,0.35,0.88,0.15,0.83,0.10,0.54,0.14,0.34]],
    'ش': [[0.91,0.06,0.90,0.20,0.91,0.43,0.70,0.43,0.69,0.21,0.69,0.28,0.59,0.45,0.47,0.34,0.47,0.24,0.47,0.48,0.35,0.64,0.15,0.61,0.10,0.40,0.14,0.26], [0.49,0.05], [0.62,0.05], [0.75,0.05]],
    'ص': [[0.58,0.20,0.78,0.10,0.90,0.33,0.86,0.60,0.63,0.60,0.48,0.49,0.48,0.17,0.52,0.29,0.48,0.32,0.48,0.65,0.36,0.88,0.15,0.83,0.10,0.54,0.15,0.34]],
    'ض': [[0.58,0.17,0.78,0.10,0.90,0.28,0.86,0.50,0.63,0.50,0.48,0.41,0.48,0.15,0.52,0.24,0.48,0.27,0.48,0.54,0.36,0.72,0.15,0.68,0.10,0.44,0.15,0.28], [0.80,-0.06]],
    'ط': [[0.21,0.58,0.37,0.46,0.55,0.38,0.75,0.39,0.87,0.53,0.89,0.72,0.85,0.89,0.64,0.89,0.42,0.89,0.20,0.89,0.20,0.70,0.20,0.50,0.20,0.30,0.19,0.10]],
    'ظ': [[0.21,0.58,0.37,0.46,0.55,0.38,0.75,0.39,0.87,0.53,0.89,0.72,0.85,0.89,0.64,0.89,0.42,0.89,0.20,0.89,0.20,0.70,0.20,0.50,0.20,0.30,0.19,0.10], [0.56,0.16]],
    'ع': [[0.70,0.25,0.55,0.20,0.45,0.30,0.60,0.40,0.40,0.55,0.35,0.75,0.55,0.85,0.75,0.75]],
    'غ': [[0.70,0.25,0.55,0.20,0.45,0.30,0.60,0.40,0.40,0.55,0.35,0.75,0.55,0.85,0.75,0.75],[0.60,0.02]],
    'ف': [[0.58,0.19,0.76,0.10,0.90,0.19,0.90,0.47,0.83,0.66,0.63,0.65,0.56,0.43,0.57,0.21,0.56,0.48,0.54,0.66,0.33,0.66,0.14,0.59,0.10,0.34,0.16,0.22], [0.85,-0.06]],
    'ق': [[0.70,0.40,0.75,0.25,0.65,0.25,0.60,0.40,0.55,0.75,0.40,0.85,0.25,0.75,0.20,0.50],[0.58,0.02],[0.74,0.02]],
    'ك': [[0.59,0.48,0.56,0.48,0.52,0.48,0.49,0.48,0.45,0.48,0.43,0.46,0.43,0.42,0.44,0.39,0.45,0.36,0.47,0.34,0.50,0.33,0.54,0.33,0.57,0.32,0.60,0.31], [0.19,0.47,0.12,0.58,0.12,0.72,0.19,0.84,0.33,0.88,0.48,0.89,0.64,0.89,0.79,0.89,0.89,0.83,0.89,0.68,0.89,0.54,0.89,0.39,0.89,0.25,0.88,0.10]],
    'ل': [[0.23,0.47,0.15,0.57,0.12,0.68,0.15,0.80,0.29,0.88,0.49,0.90,0.69,0.89,0.84,0.81,0.87,0.70,0.87,0.58,0.87,0.46,0.87,0.33,0.87,0.21,0.87,0.09]],
    'م': [[0.22,0.93,0.13,0.78,0.18,0.61,0.23,0.45,0.22,0.27,0.22,0.38,0.25,0.55,0.55,0.55,0.85,0.55,0.87,0.38,0.84,0.20,0.63,0.10,0.34,0.10,0.23,0.23]],
    'ن': [[0.87,0.10,0.87,0.22,0.87,0.34,0.87,0.46,0.87,0.59,0.84,0.70,0.71,0.78,0.54,0.80,0.36,0.79,0.21,0.74,0.13,0.64,0.13,0.52,0.15,0.40,0.23,0.31], [0.50,0.11]],
    'ه': [[0.30,0.08,0.50,0.05,0.70,0.08,0.85,0.22,0.88,0.45,0.88,0.70,0.88,0.90,0.50,0.92,0.15,0.90,0.12,0.70,0.12,0.45,0.18,0.20]],
    'و': [[0.75,0.12,0.55,0.06,0.35,0.12,0.25,0.28,0.30,0.42,0.50,0.46,0.68,0.40,0.72,0.50,0.62,0.65,0.45,0.78,0.28,0.87,0.15,0.90]],
    'ي': [[0.89,0.31,0.73,0.27,0.55,0.29,0.49,0.43,0.62,0.53,0.79,0.58,0.89,0.69,0.85,0.84,0.69,0.90,0.49,0.90,0.30,0.90,0.14,0.82,0.11,0.68,0.17,0.54], [0.36,1.05], [0.61,1.05]],
  };


  /// Catmull-Rom spline interpolation through control points.
  /// Returns [targetCount] evenly-spaced points forming a smooth curve.
  static List<Offset> _catmullRom(List<Offset> pts, int targetCount) {
    if (pts.length < 2) return pts;
    if (pts.length == 2) {
      return List.generate(targetCount,
          (i) => pts[0] + (pts[1] - pts[0]) * (i / (targetCount - 1)));
    }
    final segs = pts.length - 1;
    final result = <Offset>[];
    for (var step = 0; step < targetCount; step++) {
      final u = (step / (targetCount - 1)) * segs;
      var i = u.floor();
      var t = u - i;
      if (i >= segs) {
        i = segs - 1;
        t = 1.0;
      }
      final p0 = i > 0 ? pts[i - 1] : pts[i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];
      final t2 = t * t, t3 = t2 * t;
      result.add(Offset(
        0.5 * (2 * p1.dx + (-p0.dx + p2.dx) * t +
            (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
            (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
        0.5 * (2 * p1.dy + (-p0.dy + p2.dy) * t +
            (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
            (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
      ));
    }
    return result;
  }

  static const _boxSize = 320.0;

  List<List<Offset>> _guideStrokes(Size size) {
    var key = _letter;
    if (key == 'أ' || key == 'إ' || key == 'آ') key = 'ا';
    if (key == 'ة') key = 'ت';
    if (key == 'ى') key = 'ي';
    final raw = _paths[key];
    if (raw == null) return [];

    const boxSize = _boxSize;
    final left = (size.width - boxSize) / 2;
    final top = (size.height - boxSize) / 2;

    final strokesList = <List<Offset>>[];

    for (final stroke in raw) {
      final pts = <Offset>[];
      for (var i = 0; i < stroke.length; i += 2) {
        final px = left + stroke[i] * boxSize;
        final py = top + stroke[i + 1] * boxSize;
        pts.add(Offset(px, py));
      }
      if (pts.length > 1) {
        strokesList.add(_catmullRom(pts, 40));
      } else if (pts.length == 1) {
        strokesList.add([pts.first]);
      }
    }
    return strokesList;
  }



  /// Accuracy per stroke blends two measures so both failure modes get
  /// caught: recall (how much of the guide the learner actually traced)
  /// and precision (how closely the learner's own marks stuck to the
  /// guide). Recall alone let a broad scribble across the whole card
  /// "cover" every guide point and score as a near-perfect trace, since
  /// nothing penalized ink that strayed off the letter. The average
  /// across strokes (including dots) keeps every stroke weighted
  /// equally so body strokes don't dominate the check.
  double _computeAccuracy(List<List<Offset>> userStrokes, Size canvasSize) {
    if (userStrokes.isEmpty) return 0.0;
    final guideStrokes = _guideStrokes(canvasSize);
    if (guideStrokes.isEmpty) return 0.0;
    final tolerance = _boxSize * 0.12;

    var totalScore = 0.0;
    for (var i = 0; i < guideStrokes.length; i++) {
      final guide = guideStrokes[i];
      if (guide.isEmpty) continue;
      if (i >= userStrokes.length) continue;
      final user = userStrokes[i];
      if (user.isEmpty) continue;

      var covered = 0;
      for (final gp in guide) {
        for (final up in user) {
          if ((up - gp).distance <= tolerance) {
            covered++;
            break;
          }
        }
      }
      final recall = covered / guide.length;

      var onPath = 0;
      for (final up in user) {
        for (final gp in guide) {
          if ((up - gp).distance <= tolerance) {
            onPath++;
            break;
          }
        }
      }
      final precision = onPath / user.length;

      totalScore += recall * 0.6 + precision * 0.4;
    }

    return totalScore / guideStrokes.length;
  }

  void _handleStroke(List<List<Offset>> userStrokes, Size canvasSize) {
    final acc = _computeAccuracy(userStrokes, canvasSize);
    setState(() => _accuracy = acc);
    if (acc >= _autoPassThreshold && !_passed) {
      setState(() {
        _checked = true;
        _passed = true;
      });
    }
  }

  void _handleCheck() {
    if (_accuracy < 0.1) return;
    final passed = _accuracy >= _passThreshold;
    setState(() {
      _checked = true;
      _passed = passed;
    });
    if (!passed) {
      _failedChecks++;
      _wobble.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _checked = false);
      });
    }
  }

  void _next() {
    _accuracySum += _accuracy;
    if (_idx + 1 >= widget.cards.length) {
      final avgAccuracy = (_accuracySum / widget.cards.length) * 100;
      widget.onComplete(widget.xp, avgAccuracy, _failedChecks);
    } else {
      setState(() {
        _idx += 1;
        _accuracy = 0.0;
        _checked = false;
        _passed = false;
      });
      _entrance.forward(from: 0);
    }
  }

  int _clearCounter = 0;

  void _clear() => setState(() {
    _accuracy = 0.0;
    _checked = false;
    _passed = false;
    _clearCounter++;
  });

  Color _accuracyColor(double a) {
    if (a >= 0.8) return AppColors.adventureGreen;
    if (a >= 0.45) return AppColors.gold;
    return AppColors.coral;
  }

  @override
  void dispose() {
    _entrance.dispose();
    _breathe.dispose();
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accColor = _accuracyColor(_accuracy);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Card progress dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.cards.length; i++) ...[
                if (i != 0) const SizedBox(width: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: i == _idx ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < _idx
                        ? AppColors.adventureGreen
                        : i == _idx
                        ? widget.color
                        : AppColors.creamDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Card label: shows letter name + the actual letter
          Text(
            'Trace $_letter  ·  ${_card.translit}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          // Large Arabic letter display above the canvas
          Text(
            _letter,
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              color: AppColors.ink.withValues(alpha: 0.30),
              fontFamily: 'sans',
            ),
          ),
          const SizedBox(height: 8),
          // Real-time accuracy bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 12,
                    child: Stack(
                      children: [
                        Container(color: AppColors.creamDark),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,
                              width:
                                  constraints.maxWidth * _accuracy.clamp(0.0, 1.0),
                              color: accColor,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 42,
                child: Text(
                  '${(_accuracy * 100).clamp(0, 100).round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: accColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Trace canvas
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([_entrance, _wobble]),
              builder: (context, child) {
                final e = _overshoot.transform(_entrance.value);
                final wobbleT = Curves.easeInOut.transform(_wobble.value);
                final dx = _wobble.isAnimating
                    ? (wobbleT < 0.5 ? -6.0 : 6.0) *
                          (1 - (wobbleT - 0.5).abs() * 2)
                    : 0.0;
                return Opacity(
                  opacity: e.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(dx, 12 * (1 - e)),
                    child: child,
                  ),
                );
              },
              child: LetterTraceCanvas(
                key: ValueKey('${_card.id}_${_idx}_$_clearCounter'),
                passed: _checked && _passed,
                failed: _checked && !_passed,
                breathe: _breathe,
                guidePointsBuilder: _guideStrokes,
                onStroke: _handleStroke,
                onDirectionViolation: () {
                  _wobble.forward(from: 0);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Bottom buttons
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _clear,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.creamDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.creamBorder, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _passed ? _next : _handleCheck,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _passed
                              ? const [
                                  AppColors.adventureGreen,
                                  Color(0xFF457618),
                                ]
                              : [AppColors.teal, AppColors.tealDark],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (_passed ? AppColors.adventureGreen : AppColors.teal)
                                .withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _passed
                              ? (_idx + 1 >= widget.cards.length
                                    ? 'Done!'
                                    : 'Next')
                              : 'Check my trace',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
