import 'dart:math';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/progress_repository.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/letter_trace_canvas.dart';

/// FR-6.6 — the Hot Seat panel's content, embedded directly in the Cast
/// screen's letter-display card (not a separate sheet/dialog — Hot Seat
/// only exists inside an active cast now). Step-driven: shows
/// [HotSeatStudentPicker] first (reading the active class's roster off
/// [teacherRosterProvider]), then swaps to [HotSeatDrawingCanvas] once a
/// student is picked, matching the design spec's "picker step → canvas
/// step" flow. [onStudentPicked]/[onAttemptSaved] let the cast screen
/// mirror who's on the hot seat and their real tracing accuracy onto its
/// own presentation chip/card instead of duplicating this logic.
class HotSeatSheet extends ConsumerStatefulWidget {
  const HotSeatSheet({
    super.key,
    this.onStudentPicked,
    this.onAttemptSaved,
    this.onLetterChanged,
  });

  final void Function(String name)? onStudentPicked;
  final void Function(String name, double accuracyPct)? onAttemptSaved;

  /// Mirrors [HotSeatDrawingCanvas.onLetterChanged] so the Cast screen can
  /// follow whichever letter Hot Seat is actively tracing.
  final void Function(String letter)? onLetterChanged;

  @override
  ConsumerState<HotSeatSheet> createState() => _HotSeatSheetState();
}

class _HotSeatSheetState extends ConsumerState<HotSeatSheet> {
  String? _pickedLearnerId;
  String? _pickedName;
  bool _showingExposure = false;

  // Result step, shown after Done and before returning to the picker — the
  // teacher gets to see the accuracy score before putting the next student
  // up, instead of it flashing straight back to the picker.
  String? _resultName;
  double? _resultAccuracy;

  void _pick(String learnerId, String name) {
    widget.onStudentPicked?.call(name);
    setState(() {
      _pickedLearnerId = learnerId;
      _pickedName = name;
      _showingExposure = true;
    });
  }

  void _onExposureFinished() {
    setState(() {
      _showingExposure = false;
    });
  }

  void _onSaved(String name, double accuracyPct) {
    widget.onAttemptSaved?.call(name, accuracyPct);
    setState(() {
      _pickedLearnerId = null;
      _pickedName = null;
      _resultName = name;
      _resultAccuracy = accuracyPct;
    });
  }

  void _nextStudent() {
    setState(() {
      _resultName = null;
      _resultAccuracy = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(teacherRosterProvider);
    final pickedName = _pickedName;
    final resultName = _resultName;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (resultName != null)
            _HotSeatResult(
              name: resultName,
              accuracyPct: _resultAccuracy!,
              onNextStudent: _nextStudent,
            )
          else ...[
            Text(
              pickedName == null ? 'Hot Seat Tracing Mode' : 'Hot Seat: $pickedName',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            // Subtitle only shown for the picker step — once a student's
            // picked, the canvas below needs the vertical space more (this
            // panel is embedded in a fixed-height card now, not a
            // scrollable sheet).
            if (pickedName == null) ...[
              const SizedBox(height: 4),
              const Text(
                'Pick which student is up before launching the tracing canvas.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 10),
            if (pickedName == null)
              HotSeatStudentPicker(roster: roster, onPicked: _pick)
            else if (_showingExposure)
              _HotSeatExposureScreen(
                studentName: pickedName,
                onFinish: _onExposureFinished,
              )
            else
              HotSeatDrawingCanvas(
                learnerId: _pickedLearnerId!,
                studentName: pickedName,
                onSaved: _onSaved,
                onLetterChanged: widget.onLetterChanged,
              ),
          ],
        ],
      ),
    );
  }
}

class _HotSeatExposureScreen extends StatefulWidget {
  const _HotSeatExposureScreen({
    required this.studentName,
    required this.onFinish,
  });

  final String studentName;
  final VoidCallback onFinish;

  @override
  State<_HotSeatExposureScreen> createState() => _HotSeatExposureScreenState();
}

class _HotSeatExposureScreenState extends State<_HotSeatExposureScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      widget.onFinish();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.neutralTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.gold,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'UP NEXT ON THE HOT SEAT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          // Large student avatar/initial
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.studentName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 24),
          // Animated countdown line/bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _controller.value,
                  minHeight: 4,
                  backgroundColor: AppColors.creamDark,
                  color: AppColors.teal,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onFinish,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Skip countdown',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown after Done, before the picker reappears — the accuracy score the
/// teacher was drawing for, plus an explicit "Next student" action rather
/// than auto-advancing (so it doesn't flash past before anyone reads it).
class _HotSeatResult extends StatelessWidget {
  const _HotSeatResult({
    required this.name,
    required this.accuracyPct,
    required this.onNextStudent,
  });

  final String name;
  final double accuracyPct;
  final VoidCallback onNextStudent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$name — ${accuracyPct.round()}% match',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Saved to their progress.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (accuracyPct / 100).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: AppColors.neutralTint,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onNextStudent,
          icon: const Icon(Icons.airline_seat_recline_normal_rounded),
          label: const Text('Next student'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
        ),
      ],
    );
  }
}

/// FR-6.6 student selection — either tap a name (manual) or spin
/// [HotSeatWheel] (randomized "draw lots"); both resolve to the same
/// (learnerId, name) handoff via [onPicked].
class HotSeatStudentPicker extends StatefulWidget {
  const HotSeatStudentPicker({super.key, required this.roster, required this.onPicked});

  final List<Map<String, dynamic>> roster;
  final void Function(String learnerId, String name) onPicked;

  @override
  State<HotSeatStudentPicker> createState() => _HotSeatStudentPickerState();
}

class _HotSeatStudentPickerState extends State<HotSeatStudentPicker> {
  bool _drawLots = false;
  bool _wheelSpinning = false;

  @override
  Widget build(BuildContext context) {
    if (widget.roster.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No students enrolled yet — enroll students first.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                // Disabled mid-spin — switching away would unmount the
                // wheel and silently drop the in-flight pick.
                onPressed: _wheelSpinning
                    ? null
                    : () => setState(() => _drawLots = false),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _drawLots ? null : AppColors.mint,
                  foregroundColor: AppColors.teal,
                ),
                child: const Text('Pick manually'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _wheelSpinning
                    ? null
                    : () => setState(() => _drawLots = true),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _drawLots ? AppColors.mint : null,
                  foregroundColor: AppColors.teal,
                ),
                child: const Text('Draw lots'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_drawLots)
          HotSeatWheel(
            roster: widget.roster,
            onPicked: widget.onPicked,
            onSpinningChanged: (spinning) =>
                setState(() => _wheelSpinning = spinning),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final student in widget.roster)
                InkWell(
                  onTap: () => widget.onPicked(
                    student['learnerId'] as String,
                    student['name'] as String,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.neutralTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.creamBorder),
                    ),
                    child: Text(
                      student['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// FR-6.6 randomized selection — a segmented spinning wheel (one segment
/// per roster student) matching the approved `dumps/hot_seat_wheel_mock.html`
/// mock: a fixed AnimationController spin with a decelerating curve,
/// landing on a random student.
class HotSeatWheel extends StatefulWidget {
  const HotSeatWheel({
    super.key,
    required this.roster,
    required this.onPicked,
    required this.onSpinningChanged,
  });

  final List<Map<String, dynamic>> roster;
  final void Function(String learnerId, String name) onPicked;
  final ValueChanged<bool> onSpinningChanged;

  @override
  State<HotSeatWheel> createState() => _HotSeatWheelState();
}

class _HotSeatWheelState extends State<HotSeatWheel>
    with SingleTickerProviderStateMixin {
  static const _segmentColors = [
    AppColors.teal,
    AppColors.gold,
    AppColors.coral,
    AppColors.mintGreen,
    AppColors.adventureBlue,
    AppColors.adventurePurple,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );
  late final Animation<double> _spin = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  bool _spinning = false;
  double _restingTurns = 0;
  Tween<double> _spinTween = Tween<double>(begin: 0, end: 0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_spinning || widget.roster.isEmpty) return;
    // Captured once at spin start — the parent disables the manual/wheel
    // toggle while spinning, but the roster itself could still change
    // (a student unenrolled mid-spin); indexing this captured copy instead
    // of re-reading `widget.roster` in `whenComplete` keeps `winnerIndex`
    // valid regardless.
    final roster = widget.roster;
    final winnerIndex = Random().nextInt(roster.length);
    final segmentTurns = 1 / roster.length;
    // Land the pointer (fixed at the top) on the middle of the winning
    // segment, plus a few extra full turns for visual flourish.
    final targetTurns =
        4 + 1 - (segmentTurns * winnerIndex + segmentTurns / 2);

    setState(() => _spinning = true);
    widget.onSpinningChanged(true);
    _controller.reset();
    _spinTween = Tween<double>(
      begin: _restingTurns,
      end: _restingTurns + targetTurns,
    );
    _controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _restingTurns = (_restingTurns + targetTurns) % 1;
      });
      widget.onSpinningChanged(false);
      final winner = roster[winnerIndex];
      widget.onPicked(winner['learnerId'] as String, winner['name'] as String);
    });
  }

  @override
  Widget build(BuildContext context) {
    final roster = widget.roster;

    return Column(
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _spin,
                builder: (context, child) {
                  final turns = _spinTween.evaluate(_spin);
                  return Transform.rotate(
                    angle: turns * 2 * pi,
                    child: child,
                  );
                },
                child: CustomPaint(
                  size: const Size(240, 240),
                  painter: _WheelPainter(
                    labels: roster.map((s) => s['name'] as String).toList(),
                    colors: _segmentColors,
                  ),
                ),
              ),
              // Fixed pointer at the top edge, matching the approved mock's
              // `.pointer` (positioned above the wheel, pointing down at
              // whichever segment lands under it) — not centered on the hub.
              const Positioned(
                top: -18,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 40,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _spinning ? null : _spinWheel,
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          child: Text(_spinning ? 'Spinning…' : 'Spin the wheel'),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.labels, required this.colors});

  final List<String> labels;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / labels.length;

    for (var i = 0; i < labels.length; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      final startAngle = -pi / 2 + segmentAngle * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      final labelAngle = startAngle + segmentAngle / 2;
      final labelOffset = Offset(
        center.dx + cos(labelAngle) * radius * 0.62,
        center.dy + sin(labelAngle) * radius * 0.62,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        labelOffset - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.labels != labels;
}

class HotSeatDrawingCanvas extends ConsumerStatefulWidget {
  const HotSeatDrawingCanvas({
    super.key,
    required this.learnerId,
    required this.studentName,
    required this.onSaved,
    this.onLetterChanged,
  });

  final String learnerId;
  final String studentName;

  /// Reports the real, just-computed accuracy % alongside the student name
  /// so callers (the Cast screen) can mirror it onto their own presentation
  /// UI without recomputing anything.
  final void Function(String name, double accuracyPct) onSaved;

  /// Fired on mount and whenever the teacher switches the tracing letter,
  /// so the Cast screen's vocab card can follow whichever letter Hot Seat
  /// is actively tracing instead of its own separate stepper.
  final void Function(String letter)? onLetterChanged;

  @override
  ConsumerState<HotSeatDrawingCanvas> createState() => _HotSeatDrawingCanvasState();
}

class _HotSeatDrawingCanvasState extends ConsumerState<HotSeatDrawingCanvas>
    with SingleTickerProviderStateMixin {
  List<List<Offset>> _userStrokes = [];
  Size? _lastCanvasSize;
  String _selectedLetter = 'ج';
  final Stopwatch _stopwatch = Stopwatch()..start();

  // Remounts LetterTraceCanvas with fresh state (badges, ink, demo) on
  // every Clear tap or letter switch — same pattern as TraceActivity.
  int _clearCounter = 0;

  late final _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  static const _letterGlyphs = {'ا': 'ا', 'ب': 'ب', 'ت': 'ت', 'ج': 'ج'};

  @override
  void initState() {
    super.initState();
    // Deferred a frame: this fires during the Cast screen's build (Hot Seat
    // mounts this canvas as soon as a student is picked), and the callback
    // calls setState on that ancestor — doing it synchronously here throws
    // "setState() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLetterChanged?.call(_selectedLetter);
    });
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _breathe.dispose();
    super.dispose();
  }

  /// Heuristic telemetry — no real handwriting-recognition engine exists
  /// yet (matches this app's placeholder-module convention for core
  /// learning engines). `sequencingErrors` is the pen-lift count (more
  /// separate strokes than one continuous letter = more trouble);
  /// `strokeAccuracyPct` is the drawn strokes' bounding-box coverage of the
  /// canvas. Upgrade path: swap in a real stroke-scoring pass once a real
  /// tracing engine module exists.
  static const _paths = <String, List<List<double>>>{
    'ا': [[0.50,0.15, 0.50,0.85]],
    'ب': [[0.85,0.40, 0.80,0.65, 0.70,0.70, 0.30,0.70, 0.20,0.65, 0.15,0.40], [0.50,0.82]],
    // Ta shares Ba's base letterform (differs only by dot placement, which
    // this simplified tracer doesn't render), so it reuses Ba's stroke.
    'ت': [[0.85,0.40, 0.80,0.65, 0.70,0.70, 0.30,0.70, 0.20,0.65, 0.15,0.40], [0.50,0.30]],
    'ج': [[0.35,0.20, 0.55,0.15, 0.75,0.20, 0.50,0.35, 0.30,0.55, 0.40,0.80, 0.60,0.85, 0.75,0.75], [0.50,0.55]],
  };

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

  List<List<Offset>> _guideStrokes(Size size) {
    final raw = _paths[_selectedLetter];
    if (raw == null) return [];

    const double boxSize = 250.0;
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

  Future<void> _finishAttempt() async {
    final segments = _userStrokes;
    final sequencingErrors = segments.isEmpty ? 0 : segments.length - 1;

    var accuracy = 0.0;
    final allPoints = segments.expand((s) => s).toList();
    if (allPoints.isNotEmpty) {
      final canvasSize = _lastCanvasSize ?? const Size(350, 270);
      final guideStrokes = _guideStrokes(canvasSize);

      if (guideStrokes.isNotEmpty) {
        final tolerance = canvasSize.shortestSide * 0.16; // strict but fair tracing tolerance

        var totalCoveredPoints = 0;
        var totalGuidePoints = 0;

        for (final guide in guideStrokes) {
          totalGuidePoints += guide.length;
          for (final gp in guide) {
            var isCovered = false;
            for (final up in allPoints) {
              if ((up - gp).distance <= tolerance) {
                isCovered = true;
                break;
              }
            }
            if (isCovered) {
              totalCoveredPoints++;
            }
          }
        }

        var closeUserPoints = 0;
        for (final up in allPoints) {
          var isClose = false;
          for (final guide in guideStrokes) {
            for (final gp in guide) {
              if ((up - gp).distance <= tolerance * 1.5) {
                isClose = true;
                break;
              }
            }
            if (isClose) break;
          }
          if (isClose) closeUserPoints++;
        }

        final recall = totalGuidePoints == 0 ? 0.0 : (totalCoveredPoints / totalGuidePoints);
        final precision = allPoints.isEmpty ? 0.0 : (closeUserPoints / allPoints.length);

        if (recall + precision > 0) {
          accuracy = ((2 * recall * precision) / (recall + precision)) * 100;
        }
        accuracy = accuracy.clamp(0.0, 100.0);
      }
    }

    await ProgressRepository().writeProgress(
      learnerId: widget.learnerId,
      moduleId: 'hot_seat_$_selectedLetter',
      strokeAccuracyPct: accuracy,
      sequencingErrors: sequencingErrors,
      timeOnTaskSeconds: _stopwatch.elapsed.inSeconds,
      assignedByTeacher: true,
      isClassroomMode: true,
    );

    // Trigger Class Health Index and Class Roster updates in Riverpod
    ref.read(rosterRefreshProvider.notifier).bump();

    if (mounted) widget.onSaved(widget.studentName, accuracy);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DropdownButton<String>(
              value: _selectedLetter,
              items: _letterGlyphs.keys
                  .map(
                    (k) => DropdownMenuItem(value: k, child: Text('Letter $k')),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedLetter = v;
                    _userStrokes = [];
                    _clearCounter++;
                  });
                  widget.onLetterChanged?.call(v);
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Canvas'),
              onPressed: () => setState(() {
                _userStrokes = [];
                _clearCounter++;
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // The Cast screen wraps this panel in a scroll view, so the canvas
        // can stay generously sized without needing to squeeze the
        // shadow-letter guide (a shorter box was clipping it). Same
        // numbered-badge, shadow-demo tracing UI as the Learner Hub's
        // TraceActivity (LetterTraceCanvas is shared between both).
        AspectRatio(
          aspectRatio: 1.3,
          child: LetterTraceCanvas(
            key: ValueKey('$_selectedLetter-$_clearCounter'),
            passed: false,
            failed: false,
            breathe: _breathe,
            guidePointsBuilder: _guideStrokes,
            onStroke: (strokes, size) {
              _userStrokes = strokes;
              _lastCanvasSize = size;
            },
            onDirectionViolation: () {},
            showPassBurst: false,
            coverTolerance: 250.0 * 0.02,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _finishAttempt,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Done'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// FR-6.7 Choral Controller (Talqeen) — whole-class repetition audio,
/// triggered independently of the lesson stepper/progression locks. No
/// real audio engine exists yet (matches this app's placeholder-module
/// convention for core learning engines, e.g. TraceActivity's heuristic
/// scoring) — each track's play state is simulated locally, with only one
/// track "playing" at a time.
class ChoralPlayer extends StatefulWidget {
  const ChoralPlayer({super.key});

  @override
  State<ChoralPlayer> createState() => _ChoralPlayerState();
}

class _ChoralPlayerState extends State<ChoralPlayer> {
  static const _tracks = [
    {'name': 'Alif — Arnabun'},
    {'name': 'Ba — Baitun'},
    {'name': 'Ta — Tiffahun'},
    {'name': 'Jeem — Jamalun'},
  ];

  int? _playingIdx;

  void _toggle(int i) => setState(() {
    _playingIdx = _playingIdx == i ? null : i;
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _tracks.length; i++) ...[
          if (i != 0) const SizedBox(height: 8),
          _ChoralTrack(
            name: _tracks[i]['name']!,
            playing: _playingIdx == i,
            onTap: () => _toggle(i),
          ),
        ],
      ],
    );
  }
}

class _ChoralTrack extends StatelessWidget {
  const _ChoralTrack({
    required this.name,
    required this.playing,
    required this.onTap,
  });

  final String name;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: playing
          ? AppColors.mintGreen.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: playing
                  ? AppColors.mintGreen.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.mintGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  size: 15,
                  color: const Color(0xFF06251C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              _Waveform(active: playing),
            ],
          ),
        ),
      ),
    );
  }
}

/// A handful of static bars standing in for a real waveform (no audio
/// engine to derive amplitude from) — lit up in the brand mint when its
/// track is the one "playing", dim otherwise.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.active});

  final bool active;

  static const _heights = [6.0, 12.0, 8.0, 15.0, 9.0, 6.0];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _heights.length; i++) ...[
            if (i != 0) const SizedBox(width: 2.5),
            Container(
              width: 2.5,
              height: _heights[i],
              decoration: BoxDecoration(
                color: active
                    ? AppColors.mintGreen
                    : Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
