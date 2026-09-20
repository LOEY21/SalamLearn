import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// Allah's Creation Hunt — a hidden-object hunt across one illustrated
/// scene. Ported 1:1 from the supplied "Allah's Creation Hunt" design
/// prototype: same four screens (title -> how to play -> hunt -> badge),
/// same artwork, copy, hitboxes, verdict cards, token tray and motion.
///
/// The prototype was authored against a fixed 393x852 phone frame with every
/// hitbox expressed as a fraction of it, so the whole game is built inside
/// that same virtual frame and scaled to fit the device (see [build]) —
/// which keeps taps landing exactly where the artwork says they should on
/// any screen size.
///
/// One [CreationHuntStage] per session. The title and how-to screens are
/// identical for every stage, so a learner meets the same opening whichever
/// session they are on.
class CreationHuntGame extends StatefulWidget {
  const CreationHuntGame({
    super.key,
    required this.stage,
    required this.xp,
    required this.onComplete,
    this.onExit,
  });

  final CreationHuntStage stage;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Leaves the lesson — wired to the hunt HUD's ✕ chip, which is the only
  /// exit the prototype's layout has room for.
  final VoidCallback? onExit;

  @override
  State<CreationHuntGame> createState() => _CreationHuntGameState();
}

// ---------------------------------------------------------------------------
// Frame, assets, palette — all lifted from the prototype.
// ---------------------------------------------------------------------------

const double _kW = 393;
const double _kH = 852;
const String _kA = 'assets/images/creation_hunt';
const String _kFont = 'Baloo2';

const _cream = Color(0xFFFFF8E2);
const _creamBright = Color(0xFFFFFDF2);
const _inkPanel = Color(0x8C0A1A0E); // rgba(10,26,14,.55)
const _leafBrown = Color(0xFF4A2C12);
const _fireflyGold = Color(0xFFFFF3B0);

// Easing, straight from the prototype's `cubic-bezier(...)` calls.
const Curve _easeOut = Curves.easeOut;
const Curve _easeIn = Curves.easeIn;
const Curve _easeInOut = Curves.easeInOut;
const Curve _linear = Curves.linear;
const Curve _signDrop = Cubic(0.2, 1.22, 0.35, 1);
const Curve _boardIn = Cubic(0.2, 1.2, 0.35, 1);
const Curve _riseOut = Cubic(0.2, 1.4, 0.4, 1);
const Curve _popOut = Cubic(0.2, 1.3, 0.4, 1);
const Curve _cardOut = Cubic(0.4, 0, 0.8, 0.4);
const Curve _doneBgCurve = Cubic(0.22, 0.9, 0.3, 1);
const Curve _medalDrop = Cubic(0.22, 1.2, 0.36, 1);

double _c01(double v) => v.clamp(0.0, 1.0);

/// Interpolates a CSS `@keyframes` track: [stops] are the percentage marks
/// (0..1) and [vals] the value at each, with [curve] applied *within* each
/// segment the way a CSS timing function is.
double _kf(
  double t,
  List<double> stops,
  List<double> vals, [
  Curve curve = _linear,
]) {
  if (t <= stops.first) return vals.first;
  for (var i = 0; i < stops.length - 1; i++) {
    if (t <= stops[i + 1]) {
      final span = stops[i + 1] - stops[i];
      final u = span <= 0 ? 1.0 : curve.transform(_c01((t - stops[i]) / span));
      return vals[i] + (vals[i + 1] - vals[i]) * u;
    }
  }
  return vals.last;
}

/// `animation: <name> <dur>s <delay>s ... both` — progress 0..1, held at
/// both ends.
double _once(double t, double dur, [double delay = 0]) =>
    _c01((t - delay) / dur);

/// `animation: <name> <dur>s <delay>s infinite` — repeating phase 0..1.
/// A negative [delay] starts the loop part-way in, as the prototype does.
double _loop(double t, double dur, [double delay = 0]) {
  final x = (t - delay) % dur;
  return (x < 0 ? x + dur : x) / dur;
}

/// `infinite alternate` — ping-pongs instead of snapping back.
double _pingPong(double t, double dur, [double delay = 0]) {
  final p = _loop(t, dur * 2, delay);
  return p < 0.5 ? p * 2 : (1 - p) * 2;
}

enum _Screen { intro, howTo, play, done }

class _Mark {
  const _Mark(this.id, this.right);
  final String id;
  final bool right;
}

class _Reveal {
  const _Reveal(this.spot, this.right);
  final CreationHuntSpot spot;
  final bool right;
}

class _TapRipple {
  const _TapRipple(this.id, this.x, this.y, this.born);
  final int id;
  final double x;
  final double y;
  final double born;
}

class _CreationHuntGameState extends State<CreationHuntGame>
    with SingleTickerProviderStateMixin {
  // A single monotonic clock drives every animation in the game; each one
  // derives its own phase from the elapsed seconds. One hour is far longer
  // than any sitting, so it never wraps mid-play.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(hours: 1),
  )..forward();

  double get _now => _clock.value * 3600.0;

  // Per-screen and per-card clocks, so entrance animations restart when the
  // thing they belong to appears (the prototype gets this for free from
  // mounting and unmounting its markup).
  double _screenT0 = 0;
  double _revealT0 = 0;
  double _closeT0 = 0;
  double _markT0 = 0;
  double _hintT0 = 0;

  double get _st => _now - _screenT0;
  double get _rt => _now - _revealT0;
  double get _ct => _now - _closeT0;

  _Screen _screen = _Screen.intro;
  bool _loading = false;

  final List<String> _found = []; // grouped keys, one per token
  final List<String> _hit = []; // the exact spot ids tapped
  final Map<String, CreationHuntSpot> _hitBy = {};
  final List<String> _missed = [];
  final List<_TapRipple> _taps = [];
  _Mark? _mark;
  _Reveal? _reveal;
  String? _hinting;
  bool _closing = false;
  int _recapCount = 0; // found spots lit so far in the end-of-hunt recap
  bool _startPressed = false;
  bool _keepPressed = false;

  int _tapId = 0;
  int _wrongTaps = 0;

  Timer? _beginTimer;
  Timer? _markTimer;
  Timer? _closeTimer;
  Timer? _endTimer;
  Timer? _hintTimer;
  final Set<Timer> _rippleTimers = {};

  CreationHuntStage get _stage => widget.stage;
  List<CreationHuntSpot> get _creations => _stage.creations;
  int get _total => _creations.length;

  @override
  void dispose() {
    _beginTimer?.cancel();
    _markTimer?.cancel();
    _closeTimer?.cancel();
    _endTimer?.cancel();
    _hintTimer?.cancel();
    for (final t in _rippleTimers) {
      t.cancel();
    }
    _clock.dispose();
    super.dispose();
  }

  void _goto(_Screen s) => setState(() {
    _screen = s;
    _screenT0 = _now;
  });

  // -------------------------------------------------------------------------
  // Flow
  // -------------------------------------------------------------------------

  void _startHunt() {
    if (_loading) return;
    _goto(_Screen.howTo);
  }

  /// The prototype's `begin(i)` — a 1.1s "setting out on the hunt" beat
  /// before the scene appears, with every hunt-local bit of state reset.
  void _begin() {
    if (_loading) return;
    setState(() => _loading = true);
    _beginTimer?.cancel();
    _beginTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _screen = _Screen.play;
        _screenT0 = _now;
        _found.clear();
        _hit.clear();
        _hitBy.clear();
        _missed.clear();
        _taps.clear();
        _mark = null;
        _reveal = null;
        _hinting = null;
        _closing = false;
        _recapCount = 0;
      });
    });
  }

  void _showReveal(CreationHuntSpot spot, bool right) {
    setState(() {
      _reveal = _Reveal(spot, right);
      _revealT0 = _now;
    });
  }

  void _closeReveal() {
    if (_closing) return;
    setState(() {
      _closing = true;
      _closeT0 = _now;
    });
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 240), _finishClose);
  }

  void _finishClose() {
    if (!mounted) return;
    final done = _found.length == _total;
    setState(() {
      _reveal = null;
      _closing = false;
      _keepPressed = false;
    });
    if (done) _scheduleDone();
  }

  /// After the last find, light every found object in the order it was
  /// found, then move on to the badge screen.
  void _scheduleDone() {
    _endTimer?.cancel();
    _endTimer = Timer(const Duration(milliseconds: 1000), _recapStep);
  }

  void _recapStep() {
    if (!mounted) return;
    if (_recapCount < _hit.length) {
      setState(() => _recapCount++);
      _endTimer = Timer(const Duration(milliseconds: 800), _recapStep);
      return;
    }
    _endTimer = Timer(const Duration(milliseconds: 1600), _showDone);
  }

  void _showDone() {
    if (!mounted) return;
    setState(() {
      _mark = null;
      _reveal = null;
      _screen = _Screen.done;
      _screenT0 = _now;
    });
  }

  void _finish() {
    if (!mounted) return;
    final attempts = _total + _wrongTaps;
    final accuracy = attempts == 0 ? 100.0 : _total / attempts * 100;
    widget.onComplete(widget.xp, accuracy, _wrongTaps);
  }

  void _tapSpot(CreationHuntSpot spot) {
    if (_reveal != null || _found.length == _total) return;
    if (_found.contains(spot.key)) return;
    if (spot.isCreation) {
      setState(() {
        _found.add(spot.key);
        _hit.add(spot.id);
        _hitBy[spot.key] = spot;
        _mark = _Mark(spot.id, true);
        _markT0 = _st;
      });
      if (_found.length == _total) {
        _scheduleDone();
        return;
      }
      _showReveal(spot, true);
    } else {
      _wrongTaps++;
      setState(() {
        if (!_missed.contains(spot.id)) _missed.add(spot.id);
        _mark = _Mark(spot.id, false);
        _markT0 = _st;
      });
      _showReveal(spot, false);
    }
    _markTimer?.cancel();
    _markTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _mark = null);
    });
  }

  void _hint() {
    final left = _creations.where((c) => !_found.contains(c.key)).toList();
    if (left.isEmpty) return;
    final pick = left[math.Random().nextInt(left.length)];
    setState(() {
      _hinting = pick.id;
      _hintT0 = _st;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 2300), () {
      if (mounted) setState(() => _hinting = null);
    });
  }

  void _exit() {
    final out = widget.onExit;
    if (out != null) {
      out();
    } else {
      setState(() {
        _screen = _Screen.intro;
        _screenT0 = _now;
        _loading = false;
        _reveal = null;
      });
    }
  }

  void _addRipple(Offset local) {
    final ripple = _TapRipple(++_tapId, local.dx, local.dy, _now);
    setState(() => _taps.add(ripple));
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 650), () {
      _rippleTimers.remove(timer);
      if (mounted) setState(() => _taps.removeWhere((x) => x.id == ripple.id));
    });
    _rippleTimers.add(timer);
  }

  // -------------------------------------------------------------------------
  // Frame
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final backdrop = switch (_screen) {
      _Screen.intro || _Screen.howTo => '$_kA/intro_explorers.png',
      _ => _stage.background,
    };
    final isTitle = _screen == _Screen.intro || _screen == _Screen.howTo;
    final game = SizedBox(
      width: _kW,
      height: _kH,
      child: switch (_screen) {
        _Screen.intro => _buildIntro(),
        _Screen.howTo => _buildHowTo(),
        _Screen.play => _buildPlay(),
        _Screen.done => _buildDone(),
      },
    );
    return ColoredBox(
      color: const Color(0xFF0D1A12),
      child: LayoutBuilder(
        builder: (context, box) {
          // Near-phone screens fill edge to edge (art is cropped a hair);
          // very different shapes keep the whole canvas and get a backdrop.
          final diff = (box.maxWidth / box.maxHeight / (_kW / _kH) - 1).abs();
          if (diff < (isTitle ? 0.12 : 0.05)) {
            return ClipRect(
              child: SizedBox.expand(
                child: FittedBox(fit: BoxFit.cover, child: game),
              ),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              // Fills the letterbox space so the art reaches the screen edges.
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Image.asset(backdrop, fit: BoxFit.cover),
              ),
              const ColoredBox(color: Color(0x59000000)),
              Center(
                child: AspectRatio(
                  aspectRatio: _kW / _kH,
                  child: ClipRect(
                    child: FittedBox(fit: BoxFit.fill, child: game),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Rebuilds just the wrapped leaf on every clock tick, handing it the
  /// current screen-local time.
  Widget _fx(Widget Function(double t) builder) =>
      AnimatedBuilder(animation: _clock, builder: (_, _) => builder(_st));

  /// Same, but keeps [child] out of the rebuild — for the screen-sized
  /// entrance wrappers, which only need their opacity/transform recomputed.
  Widget _fxWrap(Widget child, Widget Function(double t, Widget c) builder) =>
      AnimatedBuilder(
        animation: _clock,
        builder: (_, c) => builder(_st, c!),
        child: child,
      );

  // =========================================================================
  // 01 — Title
  // =========================================================================

  Widget _buildIntro() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _startHunt,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _fx((t) {
            final p = _easeOut.transform(_once(t, 1.2));
            return Opacity(
              opacity: p,
              child: Transform.scale(
                scale: 1.1 + (1.06 - 1.1) * p,
                alignment: const Alignment(0, 0.1), // 50% 55%
                child: Image.asset(
                  '$_kA/intro_explorers.png',
                  width: _kW,
                  height: _kH,
                  fit: BoxFit.cover,
                ),
              ),
            );
          }),
          // Shafts of light through the canopy.
          const Positioned(
            left: -0.1 * _kW,
            top: -0.1 * _kH,
            width: 1.2 * _kW,
            height: 0.6 * _kH,
            child: IgnorePointer(child: _GodRays(opacityScale: 1)),
          ),
          _blurDot(left: .18 * _kW, top: .12 * _kH, w: 44, h: 16, o: .55, b: 6),
          _blurDot(left: .58 * _kW, top: .19 * _kH, w: 64, h: 20, o: .40, b: 8),
          _firefly(0.14, 0.64, 6, 9, 2.6, 0, true),
          _firefly(0.24, 0.71, 5, 11, 3.1, -1.4, false),
          _firefly(0.33, 0.58, 4, 12.5, 2.2, -3, true),
          _firefly(0.62, 0.67, 6, 10, 2.9, -2.2, false),
          _firefly(0.74, 0.60, 5, 13, 3.4, -4.1, true),
          _firefly(0.84, 0.73, 4, 9.5, 2.4, -5.3, false),
          _leaf(0.18, 13, 9, const Color(0xFF5FA03A), 15, 0, false),
          _leaf(0.46, 11, 8, const Color(0xFF7BB54A), 19, -6, true),
          _leaf(0.69, 14, 10, const Color(0xFF4D8C33), 22, -12, false),
          _leaf(0.88, 10, 7, const Color(0xFF86BF55), 17, -3, true),
          const IgnorePointer(child: _Vignette()),
          _buildTitleBlock(),
          _buildIntroFooter(),
          // Opening curtain — the scene fades up out of black.
          _fx((t) {
            final p = _easeOut.transform(_once(t, 1.1));
            return IgnorePointer(
              child: Opacity(
                opacity: 1 - p,
                child: const ColoredBox(
                  color: Color(0xFF0B1A10),
                  child: SizedBox.expand(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _blurDot({
    required double left,
    required double top,
    required double w,
    required double h,
    required double o,
    required double b,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: b, sigmaY: b),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: o),
              borderRadius: BorderRadius.circular(h),
            ),
          ),
        ),
      ),
    );
  }

  Widget _firefly(
    double fx,
    double fy,
    double size,
    double flyDur,
    double twinkleDur,
    double delay,
    bool pathA,
  ) {
    return Positioned(
      left: fx * _kW,
      top: fy * _kH,
      width: size,
      height: size,
      child: IgnorePointer(
        child: _fx((t) {
          final f = _loop(t, flyDur, delay);
          final dx = pathA
              ? _kf(f, [0, .25, .5, .75, 1], [0, 18, -10, 14, 0], _easeInOut)
              : _kf(f, [0, .33, .66, 1], [0, -22, 16, 0], _easeInOut);
          final dy = pathA
              ? _kf(f, [0, .25, .5, .75, 1], [0, -22, -38, -16, 0], _easeInOut)
              : _kf(f, [0, .33, .66, 1], [0, -18, -30, 0], _easeInOut);
          final k = _loop(t, twinkleDur, delay);
          final glow = _kf(k, [0, .5, 1], [0, 1, 0], _easeInOut);
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Opacity(
              opacity: 0.15 + 0.85 * glow,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _fireflyGold,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFFFEC96,
                      ).withValues(alpha: 0.35 + 0.5 * glow),
                      blurRadius: 6 + 8 * glow,
                      spreadRadius: 2 + 3 * glow,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _leaf(
    double fx,
    double w,
    double h,
    Color color,
    double dur,
    double delay,
    bool mirrored,
  ) {
    return Positioned(
      left: fx * _kW,
      top: 0,
      width: w,
      height: h,
      child: IgnorePointer(
        child: _fx((t) {
          final p = _loop(t, dur, delay);
          final dx = (mirrored ? -70.0 : 60.0) * p;
          final dy = -40 + 940 * p;
          final rot = (mirrored ? -380.0 : 420.0) * p * math.pi / 180;
          final op = mirrored
              ? _kf(p, [0, .12, .88, 1], [0, .9, .85, 0])
              : _kf(p, [0, .10, .90, 1], [0, .95, .9, 0]);
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: rot,
              child: Opacity(
                opacity: _c01(op),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.elliptical(w * .70, h * .70),
                      topRight: Radius.elliptical(w * .30, h * .30),
                      bottomRight: Radius.elliptical(w * .60, h * .60),
                      bottomLeft: Radius.elliptical(w * .40, h * .40),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTitleBlock() {
    const huntW = 0.56 * _kW;
    const signW = 0.82 * _kW;
    const signH = signW * 1024 / 1536;
    const ribbonW = 0.67 * _kW;
    return Positioned(
      left: 0,
      right: 0,
      top: 56,
      height: 480,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // "Hunt" swings down onto its hook and keeps swaying.
            Positioned(
              left: _kW / 2 - huntW / 2,
              top: 259,
              width: huntW,
              height: huntW / 2,
              child: _fx((t) {
                final p = _once(t, 1.05, 0.95);
                final op = _kf(p, [0, .58, 1], [0, 1, 1], _boardIn);
                final ty = _kf(p, [0, .58, 1], [-64, 0, 0], _boardIn);
                final sc = _kf(p, [0, .58, .8, 1], [.9, 1.01, 1, 1], _boardIn);
                final rot = _kf(
                  p,
                  [0, .58, .8, .92, 1],
                  [-8, 4, -2, .8, 0],
                  _boardIn,
                );
                final sway = t < 2.1
                    ? 0.0
                    : _kf(
                        _loop(t, 5, 2.1),
                        [0, .5, 1],
                        [-1.2, 1.2, -1.2],
                        _easeInOut,
                      );
                return Opacity(
                  opacity: _c01(op),
                  child: Transform.translate(
                    offset: Offset(0, ty),
                    child: Transform.rotate(
                      angle: rot * math.pi / 180,
                      child: Transform.scale(
                        scale: sc,
                        child: Transform.rotate(
                          angle: sway * math.pi / 180,
                          alignment: const Alignment(0, -0.72), // 50% 14%
                          child: Image.asset(
                            '$_kA/title_hunt.png',
                            width: huntW,
                            height: huntW / 2,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            // "Allah's Creation" signboard drops in first.
            Positioned(
              left: 0.09 * _kW,
              top: 123,
              width: signW,
              height: signH,
              child: _fx((t) {
                final p = _once(t, 1.15, 0.3);
                final op = _kf(p, [0, .55, 1], [0, 1, 1], _signDrop);
                final ty = _kf(
                  p,
                  [0, .55, .78, 1],
                  [-130, 10, -5, 0],
                  _signDrop,
                );
                final sc = _kf(
                  p,
                  [0, .55, .78, 1],
                  [.84, 1.035, .995, 1],
                  _signDrop,
                );
                final rot = _kf(
                  p,
                  [0, .55, .78, 1],
                  [-3, 1.2, -.6, 0],
                  _signDrop,
                );
                return Opacity(
                  opacity: _c01(op),
                  child: Transform.translate(
                    offset: Offset(0, ty),
                    child: Transform.rotate(
                      angle: rot * math.pi / 180,
                      child: Transform.scale(
                        scale: sc,
                        child: Stack(
                          children: [
                            Image.asset(
                              '$_kA/title_allahs_creation.png',
                              width: signW,
                              height: signH,
                              fit: BoxFit.fill,
                            ),
                            Positioned(
                              left: signW * .10,
                              top: signH * .16,
                              width: signW * .80,
                              height: signH * .62,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _sheen(signW * .80),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            // "Discover · Learn · Appreciate" ribbon.
            Positioned(
              left: 0.165 * _kW,
              top: 360,
              width: ribbonW,
              height: ribbonW / 3,
              child: _fx((t) {
                final p = _once(t, 0.95, 1.65);
                final op = _kf(p, [0, .62, 1], [0, 1, 1], _popOut);
                final ty = _kf(p, [0, .62, 1], [30, -4, 0], _popOut);
                final sc = _kf(p, [0, .62, 1], [.88, 1.025, 1], _popOut);
                return Opacity(
                  opacity: _c01(op),
                  child: Transform.translate(
                    offset: Offset(0, ty),
                    child: Transform.scale(
                      scale: sc,
                      child: Image.asset(
                        '$_kA/ribbon_dla.png',
                        width: ribbonW,
                        height: ribbonW / 3,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// The slow highlight that travels across the signboard.
  Widget _sheen(double width) {
    return _fx((t) {
      final p = _loop(t, 8, 2.4);
      final tx =
          _kf(p, [0, .72, 1], [-140, -140, 150], _easeInOut) / 100 * width;
      final op = _kf(p, [0, .72, .76, 1], [0, 0, .85, 0], _easeInOut);
      return Transform.translate(
        offset: Offset(tx, 0),
        child: Transform.rotate(
          angle: -14 * math.pi / 180,
          child: Opacity(
            opacity: _c01(op),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: const FractionallySizedBox(
                widthFactor: 0.42,
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0x8CFFFFFF),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildIntroFooter() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_loading)
                _fx((t) {
                  final p = _riseOut.transform(_once(t, 0.8, 2.15));
                  final bob = t < 3
                      ? 0.0
                      : _kf(
                          _loop(t, 2.8, 3),
                          [0, .5, 1],
                          [0, -6, 0],
                          _easeInOut,
                        );
                  return Opacity(
                    opacity: _c01(p),
                    child: Transform.translate(
                      offset: Offset(0, 26 * (1 - p) + bob),
                      child: Transform.scale(
                        scale: 0.94 + 0.06 * p,
                        child: _tapPill(),
                      ),
                    ),
                  );
                }),
              if (_loading) _loadingRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tapPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0x6B0C1C10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x47FFF8E2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👆', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              'Tap anywhere to begin',
              maxLines: 1,
              style: _t(16, FontWeight.w700, _cream),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _fx(
          (t) => Transform.rotate(
            angle: _loop(t, 0.9) * 2 * math.pi,
            child: const SizedBox(width: 16, height: 16, child: _SpinnerRing()),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'Setting out on the hunt',
            maxLines: 1,
            style: _t(15, FontWeight.w600, _cream),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 02 — How to play
  // =========================================================================

  Widget _buildHowTo() {
    return _fxWrap(_howToBody(), (t, child) {
      final p = _once(t, 0.45);
      final op = _easeOut.transform(p);
      final sc = _kf(p, [0, .6, 1], [.6, 1.08, 1], _easeOut);
      return Opacity(
        opacity: op,
        child: Transform.scale(scale: sc, child: child),
      );
    });
  }

  Widget _howToBody() {
    const panelW = 1.02 * _kW;
    const panelH = panelW * 1267 / 1241;
    const huntW = 0.50 * _kW;
    const huntH = huntW / 2;
    const btnW = panelW * 0.63;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Transform.scale(
                scale: 1.08,
                child: Image.asset(
                  '$_kA/intro_explorers.png',
                  width: _kW,
                  height: _kH,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xC7081E0E), Color(0xE6081E0E)],
              ),
            ),
          ),
        ),
        // Cropped "Hunt" wordmark riding the top of the board.
        Positioned(
          left: 0.25 * _kW,
          top: 0.17 * _kH,
          width: huntW,
          height: huntH - huntW * 0.16,
          child: _entrance(
            dur: 0.6,
            delay: 0.05,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: huntH,
                child: Transform.translate(
                  offset: const Offset(0, -huntW * 0.16),
                  child: Image.asset(
                    '$_kA/title_hunt.png',
                    width: huntW,
                    height: huntH,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: -0.01 * _kW,
          top: 0.23 * _kH,
          width: panelW,
          height: panelH,
          child: _fx((t) {
            final q = _once(t, 0.7, 0.16);
            final o = _kf(q, [0, .6, 1], [0, 1, 1], _boardIn);
            final ty = _kf(q, [0, .6, 1], [34, -6, 0], _boardIn);
            final sc = _kf(q, [0, .6, 1], [.9, 1.015, 1], _boardIn);
            return Opacity(
              opacity: _c01(o),
              child: Transform.translate(
                offset: Offset(0, ty),
                child: Transform.scale(
                  scale: sc,
                  alignment: const Alignment(0, -0.2), // 50% 40%
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Image.asset(
                        '$_kA/howto_panel.png',
                        width: panelW,
                        height: panelH,
                        fit: BoxFit.fill,
                      ),
                      Positioned(
                        left: panelW / 2 - btnW / 2,
                        top: panelH * 0.815,
                        width: btnW,
                        height: btnW / 3,
                        child: _entrance(
                          dur: 0.5,
                          delay: 0.62,
                          child: _pressImage(
                            pressed: _startPressed,
                            up: '$_kA/btn_start_up.png',
                            down: '$_kA/btn_start_down.png',
                            width: btnW,
                            height: btnW / 3,
                            pressedScale: 0.94,
                            onDown: () => setState(() => _startPressed = true),
                            onUp: () => setState(() => _startPressed = false),
                            onTap: _begin,
                            semantics: 'Start the hunt',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        if (_loading)
          Positioned(
            left: 0,
            right: 0,
            top: 0.83 * _kH,
            child: Center(child: _loadingRow()),
          ),
      ],
    );
  }

  /// The prototype's `acRise` — the entrance nearly every small chip uses.
  Widget _entrance({
    required double dur,
    required double delay,
    required Widget child,
  }) {
    return _fxWrap(child, (t, c) {
      final p = _riseOut.transform(_once(t, dur, delay));
      return Opacity(
        opacity: _c01(p),
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - p)),
          child: Transform.scale(scale: 0.94 + 0.06 * p, child: c),
        ),
      );
    });
  }

  Widget _pressImage({
    required bool pressed,
    required String up,
    required String down,
    required double width,
    required double height,
    required double pressedScale,
    required VoidCallback onDown,
    required VoidCallback onUp,
    required VoidCallback onTap,
    required String semantics,
  }) {
    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onDown(),
        onTapUp: (_) => onUp(),
        onTapCancel: onUp,
        onTap: onTap,
        child: AnimatedScale(
          scale: pressed ? pressedScale : 1,
          duration: const Duration(milliseconds: 80),
          curve: _easeOut,
          child: Image.asset(
            pressed ? down : up,
            width: width,
            height: height,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 03 — The hunt
  // =========================================================================

  Widget _buildPlay() {
    return _fxWrap(_playBody(), (t, child) {
      final p = _once(t, 0.5);
      final op = _easeOut.transform(p);
      final sc = _kf(p, [0, .6, 1], [.6, 1.08, 1], _easeOut);
      return Opacity(
        opacity: op,
        child: Transform.scale(scale: sc, child: child),
      );
    });
  }

  Widget _playBody() {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _addRipple(e.localPosition),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              _stage.background,
              width: _kW,
              height: _kH,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            left: -0.1 * _kW,
            top: -0.08 * _kH,
            width: 1.2 * _kW,
            height: 0.55 * _kH,
            child: IgnorePointer(
              child: _fx((t) {
                final e = _easeInOut.transform(_pingPong(t, 16));
                return Transform.translate(
                  offset: Offset(
                    (-6 + 12 * e) / 100 * 1.2 * _kW,
                    (-10 + 6 * e) / 100 * 0.55 * _kH,
                  ),
                  child: Transform.rotate(
                    angle: (-6 + 12 * e) * math.pi / 180,
                    child: const _GodRays(opacityScale: 0.62),
                  ),
                );
              }),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x80061A0C),
                      Color(0x00061A0C),
                      Color(0x00061A0C),
                      Color(0x8C061A0C),
                    ],
                    stops: [0, 0.22, 0.74, 1],
                  ),
                ),
              ),
            ),
          ),
          for (final spot in _stage.spots) _buildSpot(spot),
          // One fixed slot, not one child per ripple: adding a child here
          // would shift every later child's index, and an unkeyed Stack
          // matches children by index — which tears down and rebuilds the
          // verdict card's buttons mid-tap, so the tap never lands.
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [for (final tap in _taps) ..._buildRipple(tap)],
              ),
            ),
          ),
          _buildHud(),
          _buildInstruction(),
          if (_reveal != null) _buildReveal(_reveal!),
          _buildTokenTray(),
        ],
      ),
    );
  }

  Widget _buildSpot(CreationHuntSpot spot) {
    final left = (spot.x - spot.w / 2) * _kW;
    final top = (spot.y - spot.h / 2) * _kH;
    final w = spot.w * _kW;
    final h = spot.h * _kH;
    final radius = _radiusFor(spot.radius, w, h);
    final isFound = _hit.contains(spot.id);
    final recapIdx = _hit.indexOf(spot.id);
    final isLit = recapIdx >= 0 && recapIdx < _recapCount;
    final isMissed = _missed.contains(spot.id);
    final m = _mark;
    // null = not marked, true = a find, false = a decoy.
    final bool? markRight = (m != null && m.id == spot.id) ? m.right : null;
    final hinting = _hinting == spot.id;

    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: Semantics(
        button: true,
        label: spot.name,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tapSpot(spot),
          child: _fx((t) {
            // The whole hitbox reacts: a find pops, a decoy shakes.
            var sc = 1.0;
            var tx = 0.0;
            var rot = 0.0;
            if (markRight == true) {
              final p = _once(t - _markT0, 0.8);
              sc = _kf(
                p,
                [0, .3, .55, .75, 1],
                [1, 1.28, .94, 1.08, 1],
                _popOut,
              );
            } else if (markRight == false) {
              final p = _once(t - _markT0, 0.55);
              tx = _kf(
                p,
                [0, .12, .30, .50, .70, .86, 1],
                [0, -10, 10, -8, 7, -4, 0],
                _easeInOut,
              );
              rot = _kf(
                p,
                [0, .12, .30, .50, .70, .86, 1],
                [0, -4, 4, -3, 2, -1, 0],
                _easeInOut,
              );
            }
            return Transform.translate(
              offset: Offset(tx, 0),
              child: Transform.rotate(
                angle: rot * math.pi / 180,
                child: Transform.scale(
                  scale: sc,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Gold ring left behind on everything already found.
                      AnimatedOpacity(
                        opacity: isFound ? 1 : 0,
                        duration: const Duration(milliseconds: 350),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            border: Border.all(
                              color: const Color(0xCCFFEC96),
                              width: 3,
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      // Recap: the yellow glow, lit in the order found.
                      AnimatedOpacity(
                        opacity: isLit ? 1 : 0,
                        duration: const Duration(milliseconds: 400),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            color: const Color(0x29FFEC96),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x80FFD666),
                                blurRadius: 22,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      if (markRight == true)
                        _fx((tt) {
                          final p = _once(tt - _markT0, 0.8);
                          final o = _kf(p, [0, .35, 1], [0, 1, 0], _easeOut);
                          final s = 0.5 + 1.6 * _easeOut.transform(p);
                          return Opacity(
                            opacity: _c01(o),
                            child: Transform.scale(
                              scale: s,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: radius,
                                  border: Border.all(
                                    color: const Color(0xD9FFFFFF),
                                    width: 3,
                                  ),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          );
                        }),
                      // A decoy keeps its ✕ badge for the rest of the hunt.
                      Positioned(
                        left: w / 2 - 14,
                        top: -14.56,
                        width: 28,
                        height: 28,
                        child: AnimatedOpacity(
                          opacity: isMissed ? 1 : 0,
                          duration: const Duration(milliseconds: 350),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFE07A4A), Color(0xFFB6401F)],
                              ),
                              border: Border.all(
                                color: const Color(0xFF7A3C14),
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x73000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              '✕',
                              style: _t(16, FontWeight.w800, Colors.white),
                            ),
                          ),
                        ),
                      ),
                      if (hinting)
                        _fx((tt) {
                          final local = tt - _hintT0;
                          if (local > 2.2) return const SizedBox.shrink();
                          final p = _loop(local, 1.1);
                          final o = _kf(p, [0, .5, 1], [0, .85, 0], _easeInOut);
                          final s = _kf(
                            p,
                            [0, .5, 1],
                            [.9, 1.05, .9],
                            _easeInOut,
                          );
                          return Opacity(
                            opacity: _c01(o),
                            child: Transform.scale(
                              scale: s,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: radius,
                                  gradient: const RadialGradient(
                                    colors: [
                                      Color(0x59FFEC96),
                                      Color(0x00FFEC96),
                                    ],
                                    stops: [0, 0.7],
                                  ),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  List<Widget> _buildRipple(_TapRipple tap) {
    return [
      Positioned(
        left: tap.x - 48,
        top: tap.y - 48,
        width: 96,
        height: 96,
        child: IgnorePointer(
          child: _fx((_) {
            final p = _once(_now - tap.born, 0.62);
            final e = _easeOut.transform(p);
            final o = _kf(p, [0, .7, 1], [.95, .5, 0], _easeOut);
            return Opacity(
              opacity: _c01(o),
              child: Transform.scale(
                scale: 0.25 + 0.75 * e,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xE6FFF3B0),
                      width: 3,
                    ),
                    gradient: const RadialGradient(
                      colors: [Color(0x59FFEC96), Color(0x00FFEC96)],
                      stops: [0, 0.68],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            );
          }),
        ),
      ),
      Positioned(
        left: tap.x - 11,
        top: tap.y - 11,
        width: 22,
        height: 22,
        child: IgnorePointer(
          child: _fx((_) {
            final p = _easeOut.transform(_once(_now - tap.born, 0.45));
            return Opacity(
              opacity: 1 - p,
              child: Transform.scale(
                scale: 0.6 + 0.9 * p,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xD9FFFFFF),
                  ),
                  child: SizedBox.expand(),
                ),
              ),
            );
          }),
        ),
      ),
    ];
  }

  Widget _buildHud() {
    const plateW = 218.0;
    const plateH = plateW * 717 / 2159;

    final plate = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(-25, 0),
          child: SizedBox(
            width: plateW,
            height: plateH,
            child: Stack(
              children: [
                Image.asset(
                  '$_kA/hud_found_plate.png',
                  width: plateW,
                  height: plateH,
                  fit: BoxFit.fill,
                ),
                Positioned(
                  left: plateW * 0.31,
                  right: plateW * 0.11,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      'Found: ${_found.length}/$_total',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: _t(
                        20,
                        FontWeight.w800,
                        _creamBright,
                        shadow: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: 150,
          height: 11,
          decoration: BoxDecoration(
            color: _inkPanel,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xE64A2C12), width: 2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 550),
              curve: const Cubic(0.2, 1, 0.3, 1),
              widthFactor: _total == 0 ? 0 : _found.length / _total,
              heightFactor: 1,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD166), Color(0xFF8FC73F)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    final buttons = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _hudButton('$_kA/btn_hint.png', 'Exit', _exit),
        const SizedBox(height: 8),
        _hudButton('$_kA/btn_close.png', 'Hint', _hint),
      ],
    );

    return Positioned(
      left: 14,
      right: 14,
      top: _stage.hudAtBottom ? null : 60,
      bottom: _stage.hudAtBottom ? 86 : null,
      // Only the two chips are tappable; the counter plate and progress bar
      // sit over the scene and must let hunt taps through to the spots
      // underneath (the prototype's `pointer-events:none` on this row).
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IgnorePointer(child: plate),
          const Spacer(),
          buttons,
        ],
      ),
    );
  }

  Widget _hudButton(String asset, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: _PressDown(
        onTap: onTap,
        child: Image.asset(asset, width: 52, height: 52, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildInstruction() {
    return Positioned(
      left: 0,
      right: 0,
      top: _stage.instructionAtTop ? 186 : null,
      bottom: _stage.instructionAtTop ? null : (_stage.hudAtBottom ? 200 : 132),
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: _inkPanel,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _stage.instruction,
                textAlign: TextAlign.center,
                style: _t(16, FontWeight.w700, _cream, shadow: true),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenTray() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _creations.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                _trayToken(_creations[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _trayToken(CreationHuntSpot base) {
    final got = _found.contains(base.key);
    final crop = _hitBy[base.key] ?? base;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: got ? const Color(0x800A1A0E) : const Color(0x99142818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _leafBrown, width: 3),
        boxShadow: const [BoxShadow(color: _leafBrown, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: got ? 1 : 0,
              duration: const Duration(milliseconds: 350),
              child: Center(child: _spotCrop(crop, 44)),
            ),
            if (!got) Text('❔', style: _t(22, FontWeight.w700, _cream)),
          ],
        ),
      ),
    );
  }

  /// Cuts a [box]-sized square out of the stage artwork, centred on the
  /// spot — the token tray's little "photo" of what was found.
  Widget _spotCrop(CreationHuntSpot c, double box) {
    final k = math.max(box / (c.w * _kW), box / (c.h * _kH));
    final iw = _kW * k;
    final ih = _kH * k;
    return ClipRect(
      child: SizedBox(
        width: box,
        height: box,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -(c.x * _kW * k - box / 2),
              top: -(c.y * _kH * k - box / 2),
              width: iw,
              height: ih,
              child: Image.asset(_stage.background, fit: BoxFit.fill),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Verdict card
  // -------------------------------------------------------------------------

  Widget _buildReveal(_Reveal r) {
    final spot = r.spot;
    final right = r.right;
    final lower = spot.y > 0.5;
    final panelW = _kW - 44.0;
    final panelH = right ? panelW * 948 / 1659 : panelW * 1122 / 1402;
    final allFound = _found.length == _total;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: _fx((_) {
          final overlayOpacity = _closing
              ? 1 - _easeIn.transform(_once(_ct, 0.24))
              : _easeOut.transform(_once(_rt, 0.3));
          final overlayScale = _closing
              ? 1.0
              : _kf(_once(_rt, 0.3), [0, .6, 1], [.6, 1.08, 1], _easeOut);
          return Opacity(
            opacity: _c01(overlayOpacity),
            child: Transform.scale(
              scale: overlayScale,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: _spotlight(spot, right)),
                    Positioned(
                      left: 22,
                      right: 22,
                      top: lower ? 120 : null,
                      bottom: lower ? null : 120,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xB30A1A0E),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  spot.icon,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  right ? 'Created by Allah' : 'Made by people',
                                  style: _t(15, FontWeight.w700, _cream),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _revealCard(spot, right, panelW, panelH, allFound),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _spotlight(CreationHuntSpot spot, bool right) {
    return _fx((_) {
      var sc = 1.0;
      var tx = 0.0;
      var rot = 0.0;
      final p = _once(_rt, right ? 0.9 : 0.6);
      if (right) {
        sc = _kf(p, [0, .3, .55, .75, 1], [1, 1.28, .94, 1.08, 1], _popOut);
      } else {
        tx = _kf(
          p,
          [0, .12, .30, .50, .70, .86, 1],
          [0, -10, 10, -8, 7, -4, 0],
          _easeInOut,
        );
        rot = _kf(
          p,
          [0, .12, .30, .50, .70, .86, 1],
          [0, -4, 4, -3, 2, -1, 0],
          _easeInOut,
        );
      }
      return CustomPaint(
        painter: _SpotlightPainter(
          rect: Rect.fromLTWH(
            (spot.x - spot.w / 2) * _kW,
            (spot.y - spot.h / 2) * _kH,
            spot.w * _kW,
            spot.h * _kH,
          ),
          radius: spot.radius,
          right: right,
          scale: sc,
          dx: tx,
          rotation: rot * math.pi / 180,
        ),
        child: const SizedBox.expand(),
      );
    });
  }

  Widget _revealCard(
    CreationHuntSpot spot,
    bool right,
    double panelW,
    double panelH,
    bool allFound,
  ) {
    final keepW = panelW * 0.72;
    final tryW = panelW * 0.66;

    return _fx((_) {
      double op;
      double ty;
      double sc;
      if (_closing) {
        final p = _cardOut.transform(_once(_ct, 0.24));
        op = 1 - p;
        ty = 14 * p;
        sc = 1 - 0.18 * p;
      } else {
        final p = _riseOut.transform(_once(_rt, 0.45, 0.08));
        op = p;
        ty = 26 * (1 - p);
        sc = 0.94 + 0.06 * p;
      }
      return Opacity(
        opacity: _c01(op),
        child: Transform.translate(
          offset: Offset(0, ty),
          child: Transform.scale(
            scale: sc,
            child: SizedBox(
              width: panelW,
              height: panelH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    right
                        ? '$_kA/reveal_panel_blank.png'
                        : '$_kA/wrong_panel_blank.png',
                    width: panelW,
                    height: panelH,
                    fit: BoxFit.fill,
                  ),
                  // Each panel's artwork has its own well: the green one
                  // runs nearly edge to edge, the brown one carries ~16%
                  // transparent margin top and bottom. Inset to the well and
                  // stop above wherever that panel's button sits, so the copy
                  // never floats outside the board.
                  Positioned(
                    left: panelW * 0.11,
                    right: panelW * 0.11,
                    top: panelH * (right ? 0.10 : 0.17),
                    bottom: panelH * (right ? 0.49 : 0.50),
                    child: _PanelCopy(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            right ? 'SubhanAllah!' : 'Not this one',
                            textAlign: TextAlign.center,
                            style: _t(
                              29,
                              FontWeight.w800,
                              _creamBright,
                              height: 1.05,
                              shadow: true,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            right
                                ? 'Allah created the ${spot.name}.'
                                : 'People made the ${spot.name}. Keep looking '
                                      'for Allah’s creations.',
                            textAlign: TextAlign.center,
                            style: _t(
                              17,
                              FontWeight.w700,
                              _creamBright,
                              height: 1.3,
                              shadow: true,
                            ),
                          ),
                          if (right && allFound) ...[
                            const SizedBox(height: 12),
                            _textCloseButton('See your badge'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (right && !allFound)
                    Positioned(
                      left: panelW / 2 - keepW / 2,
                      bottom: panelH * 0.07,
                      width: keepW,
                      height: keepW / 3,
                      child: _pressImage(
                        pressed: _keepPressed,
                        up: '$_kA/btn_keephunt_up.png',
                        down: '$_kA/btn_keephunt_down.png',
                        width: keepW,
                        height: keepW / 3,
                        pressedScale: 0.95,
                        onDown: () => setState(() => _keepPressed = true),
                        onUp: () => setState(() => _keepPressed = false),
                        onTap: _closeReveal,
                        semantics: 'Keep hunting',
                      ),
                    ),
                  if (!right)
                    Positioned(
                      left: panelW / 2 - tryW / 2,
                      bottom: panelH * 0.22,
                      width: tryW,
                      height: tryW / 3,
                      child: _pressImage(
                        pressed: _keepPressed,
                        up: '$_kA/btn_tryagain_up.png',
                        down: '$_kA/btn_tryagain_down.png',
                        width: tryW,
                        height: tryW / 3,
                        pressedScale: 0.95,
                        onDown: () => setState(() => _keepPressed = true),
                        onUp: () => setState(() => _keepPressed = false),
                        onTap: _closeReveal,
                        semantics: 'Try again',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _textCloseButton(String label) {
    return GestureDetector(
      onTap: _closeReveal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0x24000000),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xCCFFFDF2), width: 3),
        ),
        child: Text(label, style: _t(16, FontWeight.w800, _creamBright)),
      ),
    );
  }

  // =========================================================================
  // 04 — Badge
  // =========================================================================

  Widget _buildDone() {
    const signW = 310.0;
    const signH = signW * 724 / 2172;
    const cheerW = 216.0;
    const cheerH = cheerW * 1536 / 1024;
    const gridW = 252.0;
    const cell = (gridW - 18) / 3;
    const gridH = cell * 2 + 9;
    const groupH = cheerH - 62 + 10 + gridH;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _fx((t) {
              final p = _doneBgCurve.transform(_once(t, 2.4));
              return Transform.scale(
                scale: 1.12 + (1.02 - 1.12) * p,
                child: Image.asset(
                  _stage.background,
                  width: _kW,
                  height: _kH,
                  fit: BoxFit.cover,
                ),
              );
            }),
          ),
          Positioned.fill(
            child: _fx((t) {
              final p = _easeOut.transform(_once(t, 0.8, 0.1));
              return Opacity(
                opacity: p,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.4),
                      radius: 0.9,
                      colors: [
                        Color(0x2EFFF0BE),
                        Color(0x8C061A0C),
                        Color(0xD1061A0C),
                      ],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
              );
            }),
          ),
          Positioned(
            left: _kW / 2 - 220,
            top: 0.15 * _kH - 220,
            width: 440,
            height: 440,
            child: IgnorePointer(
              child: _fx((t) {
                final p = _easeOut.transform(_once(t, 1.0, 0.1));
                return Opacity(
                  opacity: p,
                  child: Transform.scale(
                    scale: 0.5 + 0.5 * p,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x8CFFE896),
                            Color(0x8CFFE896),
                            Color(0x38FFE282),
                            Color(0x00FFE282),
                          ],
                          stops: [0, 0.12, 0.26, 0.60],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          _confetti(0.06, 9, 14, const Color(0xFFFFD166), 3.2, 0.6),
          _confetti(0.26, 8, 12, const Color(0xFF8FC73F), 3.8, 0.85),
          _confetti(0.48, 10, 14, const Color(0xFF7EC2FF), 3.4, 0.45),
          _confetti(0.68, 8, 13, const Color(0xFFFF9F68), 4.2, 1.05),
          _confetti(0.86, 9, 12, const Color(0xFFFFE9A8), 3.6, 0.7),
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _doneMedal(),
                    const SizedBox(height: 10),
                    _fx((t) {
                      final p = _once(t, 0.8, 0.45);
                      final op = _kf(p, [0, .55, 1], [0, 1, 1], _medalDrop);
                      final ty = _kf(
                        p,
                        [0, .55, .78, 1],
                        [-130, 10, -5, 0],
                        _medalDrop,
                      );
                      final sc = _kf(
                        p,
                        [0, .55, .78, 1],
                        [.84, 1.035, .995, 1],
                        _medalDrop,
                      );
                      return Opacity(
                        opacity: _c01(op),
                        child: Transform.translate(
                          offset: Offset(0, ty),
                          child: Transform.scale(
                            scale: sc,
                            child: Image.asset(
                              '$_kA/done_sign.png',
                              width: signW,
                              height: signH,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    _fx((t) {
                      final p = _popOut.transform(_once(t, 0.5, 0.8));
                      return Opacity(
                        opacity: _c01(p),
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - p)),
                          child: Text(
                            'SubhanAllah — every one of them was created by '
                            'Allah in ${_stage.name.toLowerCase()}.',
                            textAlign: TextAlign.center,
                            style: _t(
                              15,
                              FontWeight.w700,
                              _cream,
                              height: 1.35,
                              shadow: true,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: _kW - 40,
                      height: groupH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: cheerH,
                            child: _cheerRow(cheerW, cheerH),
                          ),
                          Positioned(
                            left: (_kW - 40 - gridW) / 2,
                            top: cheerH - 62 + 10,
                            width: gridW,
                            height: gridH,
                            child: _doneGrid(cell),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: IgnorePointer(
              child: _cheerIn(
                2.2,
                Center(
                  child: Text(
                    'Tap anywhere to continue to next lesson',
                    maxLines: 1,
                    style: _t(14, FontWeight.w700, _cream),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doneMedal() {
    return _fx((t) {
      final p = _once(t, 0.95, 0.1);
      final op = _kf(p, [0, .55, 1], [0, 1, 1], _medalDrop);
      final ty = _kf(p, [0, .55, .75, 1], [-110, 8, 0, 0], _medalDrop);
      final sc = _kf(p, [0, .55, .75, 1], [.5, 1.14, .96, 1], _medalDrop);
      final rot = _kf(p, [0, .55, .75, 1], [-16, 4, 0, 0], _medalDrop);
      final glow = t < 1.1
          ? 0.0
          : _kf(_loop(t, 2.6, 1.1), [0, .5, 1], [0, 1, 0], _easeInOut);
      return Opacity(
        opacity: _c01(op),
        child: Transform.translate(
          offset: Offset(0, ty),
          child: Transform.rotate(
            angle: rot * math.pi / 180,
            child: Transform.scale(
              scale: sc,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFFFD646,
                      ).withValues(alpha: 0.55 + 0.4 * glow),
                      blurRadius: 10 + 16 * glow,
                      spreadRadius: 2 + 4 * glow,
                    ),
                  ],
                ),
                child: Image.asset(
                  '$_kA/medal.png',
                  width: 132,
                  height: 132,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _cheerRow(double cheerW, double cheerH) {
    const rowW = _kW - 40;
    final girlLeft = (rowW - (cheerW * 2 - 56)) / 2;
    final boyLeft = girlLeft + cheerW - 56;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -26,
          top: cheerH * 0.06 - 20,
          width: 56,
          height: 56,
          child: _sparkle('$_kA/spark_right.png', 1.15, 1.55),
        ),
        Positioned(
          right: -26,
          top: cheerH * 0.06 - 20,
          width: 56,
          height: 56,
          child: _sparkle('$_kA/spark_left.png', 1.25, 1.75),
        ),
        Positioned(
          left: girlLeft,
          top: 0,
          width: cheerW,
          height: cheerH,
          child: _cheerIn(
            0.9,
            Image.asset(
              '$_kA/explorer_girl_cheer.png',
              width: cheerW,
              height: cheerH,
              fit: BoxFit.fill,
            ),
          ),
        ),
        Positioned(
          left: boyLeft,
          top: 0,
          width: cheerW,
          height: cheerH,
          child: _cheerIn(
            1.02,
            Image.asset(
              '$_kA/explorer_boy_cheer.png',
              width: cheerW,
              height: cheerH,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cheerIn(double delay, Widget child) {
    return _fxWrap(child, (t, c) {
      final p = _once(t, 0.6, delay);
      final op = _kf(p, [0, .6, 1], [0, 1, 1], _popOut);
      final ty = _kf(p, [0, .6, 1], [34, -6, 0], _popOut);
      final sc = _kf(p, [0, .6, 1], [.82, 1.04, 1], _popOut);
      return Opacity(
        opacity: _c01(op),
        child: Transform.translate(
          offset: Offset(0, ty),
          child: Transform.scale(scale: sc, child: c),
        ),
      );
    });
  }

  Widget _sparkle(String asset, double delay, double glowDelay) {
    return _fx((t) {
      final p = _easeOut.transform(_once(t, 0.4, delay));
      final glow = t < glowDelay
          ? 0.0
          : _kf(_loop(t, 2.2, glowDelay), [0, .5, 1], [0, 1, 0], _easeInOut);
      return Opacity(
        opacity: p * 0.95,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - p)),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFFFD646,
                  ).withValues(alpha: 0.45 + 0.4 * glow),
                  blurRadius: 6 + 12 * glow,
                ),
              ],
            ),
            child: Image.asset(asset, width: 56, height: 56),
          ),
        ),
      );
    });
  }

  Widget _doneGrid(double cell) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (var i = 0; i < _creations.length; i++)
          _doneTile(_creations[i], cell, i),
      ],
    );
  }

  Widget _doneTile(CreationHuntSpot base, double cell, int index) {
    final got = _found.contains(base.key);
    final crop = _hitBy[base.key] ?? base;
    return _fx((t) {
      final p = _once(t, 0.5, 0.95 + index * 0.09);
      final op = _kf(p, [0, .65, 1], [0, 1, 1], _popOut);
      final sc = _kf(p, [0, .65, 1], [.4, 1.14, 1], _popOut);
      final rot = _kf(p, [0, .65, 1], [-10, 3, 0], _popOut);
      final glow = t < 1.7
          ? 0.0
          : _kf(_loop(t, 2.6, 1.7), [0, .5, 1], [0, 1, 0], _easeInOut);
      return Opacity(
        opacity: _c01(op),
        child: Transform.rotate(
          angle: rot * math.pi / 180,
          child: Transform.scale(
            scale: sc,
            child: Container(
              width: cell,
              height: cell,
              decoration: BoxDecoration(
                color: const Color(0x800A1A0E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD76A), width: 3),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0xE64A2C12),
                    offset: Offset(0, 5),
                  ),
                  BoxShadow(
                    color: const Color(
                      0xFFFFD666,
                    ).withValues(alpha: 0.35 + 0.45 * glow),
                    blurRadius: 16 + 10 * glow,
                    spreadRadius: 6 * glow,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Transform.scale(
                        scale: 2.1,
                        child: _spotCrop(crop, 44),
                      ),
                    ),
                    Positioned(
                      right: -5,
                      top: -5,
                      width: 24,
                      height: 24,
                      child: Opacity(
                        opacity: got ? 1 : 0,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF5FD35F), Color(0xFF2FA02F)],
                            ),
                            border: Border.all(color: _creamBright, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '✓',
                            style: _t(13, FontWeight.w800, Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _confetti(
    double fx,
    double w,
    double h,
    Color color,
    double dur,
    double delay,
  ) {
    return Positioned(
      left: fx * _kW,
      top: 0,
      width: w,
      height: h,
      child: IgnorePointer(
        child: _fx((t) {
          if (t < delay) return const SizedBox.shrink();
          final p = _loop(t, dur, delay);
          return Transform.translate(
            offset: Offset(0, -20 + 900 * p),
            child: Transform.rotate(
              angle: 540 * p * math.pi / 180,
              child: Opacity(
                opacity: _c01(1 - p),
                child: ColoredBox(color: color, child: const SizedBox.expand()),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

TextStyle _t(
  double size,
  FontWeight weight,
  Color color, {
  double? height,
  bool shadow = false,
}) {
  return TextStyle(
    fontFamily: _kFont,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    shadows: shadow
        ? const [
            Shadow(
              color: Color(0x99000000),
              offset: Offset(0, 1),
              blurRadius: 3,
            ),
          ]
        : null,
  );
}

BorderRadius _radiusFor(CreationHuntRadius r, double w, double h) {
  switch (r) {
    case CreationHuntRadius.circle:
      return BorderRadius.all(Radius.elliptical(w / 2, h / 2));
    case CreationHuntRadius.blob:
      return BorderRadius.only(
        topLeft: Radius.elliptical(w * .46, h * .46),
        topRight: Radius.elliptical(w * .46, h * .46),
        bottomLeft: Radius.elliptical(w * .42, h * .42),
        bottomRight: Radius.elliptical(w * .42, h * .42),
      );
    case CreationHuntRadius.domed:
      return BorderRadius.only(
        topLeft: Radius.elliptical(w * .48, h * .48),
        topRight: Radius.elliptical(w * .48, h * .48),
        bottomLeft: Radius.elliptical(w * .18, h * .18),
        bottomRight: Radius.elliptical(w * .18, h * .18),
      );
    case CreationHuntRadius.soft:
      return BorderRadius.circular(20);
    case CreationHuntRadius.diamond:
      return BorderRadius.only(
        topLeft: Radius.elliptical(w * .5, h * .5),
        bottomRight: Radius.elliptical(w * .5, h * .5),
        topRight: const Radius.circular(8),
        bottomLeft: const Radius.circular(8),
      );
  }
}

/// Lays the verdict copy out at the well's own width -- so the lines wrap
/// where the board is wide -- then shrinks the block if a long translation
/// or a wide-set font would push it past the bottom of the well.
///
/// A bare `FittedBox` can't do this on its own: it measures its child
/// unbounded, so every line would run out to one unwrappable strip and be
/// scaled down to a whisper.
class _PanelCopy extends StatelessWidget {
  const _PanelCopy({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: constraints.maxWidth, child: child),
      ),
    );
  }
}

/// The soft shafts of light raking across the top of every scene.
class _GodRays extends StatelessWidget {
  const _GodRays({required this.opacityScale});

  final double opacityScale;

  @override
  Widget build(BuildContext context) {
    double a(double v) => v * opacityScale;
    // The rays drift and rotate every frame. Without this the blurred layer
    // is re-rasterised on each one; with it the blur is cached and only the
    // transform is re-composited.
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              center: const Alignment(0.2, -1),
              startAngle: 110 * math.pi / 180,
              endAngle: (110 + 360) * math.pi / 180,
              colors: [
                const Color(0xFFFFF7D6).withValues(alpha: 0),
                const Color(0xFFFFF7D6).withValues(alpha: a(0.32)),
                const Color(0xFFFFF7D6).withValues(alpha: 0),
                const Color(0xFFFFF7D6).withValues(alpha: 0),
                const Color(0xFFFFF7D6).withValues(alpha: a(0.22)),
                const Color(0xFFFFF7D6).withValues(alpha: 0),
                const Color(0xFFFFF7D6).withValues(alpha: 0),
              ],
              stops: const [
                0,
                16 / 360,
                30 / 360,
                50 / 360,
                62 / 360,
                76 / 360,
                1,
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.16),
          radius: 0.95,
          colors: [Color(0x00061400), Color(0x00061400), Color(0x73061400)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _SpinnerRing extends StatelessWidget {
  const _SpinnerRing();

  @override
  Widget build(BuildContext context) {
    final faint = _cream.withValues(alpha: 0.35);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border(
          top: const BorderSide(color: _cream, width: 3),
          left: BorderSide(color: faint, width: 3),
          right: BorderSide(color: faint, width: 3),
          bottom: BorderSide(color: faint, width: 3),
        ),
      ),
    );
  }
}

/// A button that sinks 3px while held, like the prototype's `:active` rule.
class _PressDown extends StatefulWidget {
  const _PressDown({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressDown> createState() => _PressDownState();
}

class _PressDownState extends State<_PressDown> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: Transform.translate(
        offset: Offset(0, _down ? 3 : 0),
        child: widget.child,
      ),
    );
  }
}

/// Dims the whole scene except the tapped spot, which keeps a bright rim and
/// a halo — the prototype's giant `0 0 0 9999px` box-shadow, drawn as a
/// punched-out path so it stays cheap.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.rect,
    required this.radius,
    required this.right,
    required this.scale,
    required this.dx,
    required this.rotation,
  });

  final Rect rect;
  final CreationHuntRadius radius;
  final bool right;
  final double scale;
  final double dx;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = rect.center;
    canvas.save();
    canvas.translate(centre.dx + dx, centre.dy);
    canvas.rotate(rotation);
    canvas.scale(scale);
    canvas.translate(-centre.dx, -centre.dy);

    final rr = _radiusFor(radius, rect.width, rect.height).toRRect(rect);
    final hole = Path()..addRRect(rr);
    final everything = Path()
      ..addRect(const Rect.fromLTWH(-9999, -9999, 20000, 20000));

    canvas.drawPath(
      Path.combine(PathOperation.difference, everything, hole),
      Paint()..color = const Color(0xC7051A0A),
    );

    final rim = right ? const Color(0xF2FFEC96) : const Color(0xE6FFC48C);
    final glow = right ? const Color(0xBFFFD666) : const Color(0x99C98A4A);
    canvas.drawRRect(
      rr,
      Paint()
        ..color = glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = right ? 20 : 16
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, right ? 15 : 13),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.rect != rect ||
      old.scale != scale ||
      old.dx != dx ||
      old.rotation != rotation ||
      old.right != right ||
      old.radius != radius;
}
