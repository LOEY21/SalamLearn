import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// The Qur'an Etiquette — pick the respectful choice in five scenes about
/// listening to and handling the Qur'an. Built from the supplied
/// "Qur'an Etiquette" (v2) prototype: curtain wipe, narration bar, Star
/// Meter, choice cards and Qur'an Hero card. Each question gets one pick:
/// the right one shows the feedback art with MUMTAZ! under a green mask,
/// the other keeps the scene under a red one; either way the Star Meter
/// marks it and the game moves on.
///
/// The prototype is authored against a fixed 1600x900 landscape stage, so
/// the UI is built inside that virtual frame and scaled to fit, while the
/// scene artwork (2400x1080) fills the whole screen behind it. The device is
/// held in landscape while the game is on.
///
/// Every session opens on the same painted start screen (logo, ribbon and
/// Start over the masjid art); Start plays this lesson's [session].
class QuranEtiquetteGame extends StatefulWidget {
  const QuranEtiquetteGame({
    super.key,
    required this.session,
    required this.xp,
    required this.onComplete,
    this.onExit,
  });

  final QuranEtiquetteSession session;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Leaves the lesson from the title screen's ✕.
  final VoidCallback? onExit;

  @override
  State<QuranEtiquetteGame> createState() => _QuranEtiquetteGameState();
}

// ---------------------------------------------------------------------------
// Frame, assets, palette — all lifted from the prototype.
// ---------------------------------------------------------------------------

const double _kW = 1600;
const double _kH = 900;
const String _kA = 'assets/images/quran_etiquette';

/// The ending panel's size in the 1600x900 frame.
const double _kPanelW = 780;
const double _kPanelH = 760;

/// Ending screen text ink — the deep teal of the title plaque.
const _endInk = Color(0xFF0B5A4B);

/// The start background art's own frame.
const double _kArtW = 1870;
const double _kArtH = 841;

/// A lantern cut out of the start art: its sprite's box in the art's frame
/// and the x of the hook it hangs from, on the sprite's top edge.
class _Lantern {
  const _Lantern(this.asset, this.left, this.top, this.w, this.h, this.pivotX);

  final String asset;
  final double left;
  final double top;
  final double w;
  final double h;
  final double pivotX;
}

const List<_Lantern> _kLanterns = [
  _Lantern('lantern_0', 675, 28, 49, 112, 699),
  _Lantern('lantern_1', 330, 105, 52, 129, 357.5),
  _Lantern('lantern_2', 840, 209, 43, 92, 862),
  _Lantern('lantern_3', 1250, 80, 57, 141, 1278),
  _Lantern('lantern_4', 1710, 30, 73, 139, 1747),
];

/// Centres of the Star Meter tile's five sockets, as fractions of its width.
const List<double> _kSockets = [0.185, 0.343, 0.5, 0.657, 0.815];

/// The question and feedback art's own frame.
const double _kSceneW = 2400;
const double _kSceneH = 1080;

/// Left edges of the sunbeams through the left windows, in art pixels.
const List<double> _kRays = [120, 420, 700];
const String _kBaloo = 'Baloo2';
const String _kNunito = 'Nunito';

const _creamPanel = Color(0xF5FDF8EA); // rgba(253,248,234,.96)
const _creamEdge = Color(0xFFCBB98D);
const _promptInk = Color(0xFF2C2418);
const _gold = Color(0xFFF2C34A);
const _goldInk = Color(0xFF7A4A17);
const _goldDrop = Color(0xFFDCA42F);
const _goldDropShade = Color(0xFFA97A1D);
const _leafGreenDeep = Color(0xFF2F8B45);
const _meterFill = Color(0xFF5FC06F);
const _barTrack = Color(0xFFDED6BF);
const _barTrackEdge = Color(0xFFBDB29A);
const _decoyRed = Color(0xFFD9544C);
const _decoyEdge = Color(0xFF8F2521);
// Curtain and question tile: the title plaque's teal and gold.
const _curtainLit = Color(0xFF0B5F5B);
const _curtainDim = Color(0xFF07433F);
const _curtainShade = Color(0xFF042F2C);
const _tileTop = Color(0xFF0A8A80);
const _tileBottom = Color(0xFF016B69);
const _tileEdge = Color(0xFFE8B83A);
const _tileInk = Color(0xFFFFF6DC);
const _sunYellow = Color(0xFFFFD94A);
const _ringYellow = Color(0xFFFFD75E);
const _twinkleInk = Color(0xFFFFF6C9);
const _sceneBase = Color(0xFFF6EFDD);
const _stageBack = Color(0xFF10140F);

const Curve _easeOut = Curves.easeOut;
const Curve _easeInOut = Curves.easeInOut;
const Curve _linear = Curves.linear;
const Curve _popOut = Cubic(0.3, 1.5, 0.5, 1);
const Curve _curtainCurve = Cubic(0.65, 0, 0.35, 1);
const Curve _sceneCurve = Cubic(0.22, 0.7, 0.2, 1);
const Curve _logoIn = Cubic(0.34, 1.4, 0.5, 1);
const Curve _btnIn = Cubic(0.34, 1.56, 0.64, 1);

double _c01(double v) => v.clamp(0.0, 1.0);

/// Interpolates a CSS `@keyframes` track with [curve] applied per segment.
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

double _once(double t, double dur, [double delay = 0]) =>
    _c01((t - delay) / dur);

double _loop(double t, double dur) {
  final x = t % dur;
  return (x < 0 ? x + dur : x) / dur;
}

const double _deg = math.pi / 180;

/// A seamless sine swell 0 -> 1 -> 0 over [dur] seconds, for ambient loops.
double _wave(double t, double dur) =>
    0.5 - 0.5 * math.cos(_loop(t, dur) * 2 * math.pi);

/// The prototype's own timings, in seconds.
const double _kCurtain = 3.0;
const double _kCurtainClose = 0.6;
const double _kRevealDelay = 2.6; // as the curtain opens
const double _kReveal = 4.0;
const double _kShowcase = 4.0; // feedback art alone, then on to the next
const double _kReplaySpin = 0.9;
const double _kPrevHold = 0.9;

enum _Screen { start, play }

class _QuranEtiquetteGameState extends State<QuranEtiquetteGame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  double get _now => _clock.value * 3600.0;

  double _screenT0 = 0;
  double _curtainT0 = 0;
  double _sceneT0 = 0;
  double _panelT0 = 0;
  double _successT0 = 0;
  double _replayT0 = 0;
  double _finishT0 = 0;
  double _revealT0 = 0;
  double _barT0 = 0;

  _Screen _screen = _Screen.start;
  int _index = 0;
  int _correct = 0;

  /// One entry per question answered, in order: true for the respectful
  /// choice, false for the other one. Drives the Star Meter's sockets.
  final List<bool> _results = [];

  /// The question was answered with the wrong choice — its scene is shown
  /// under a red mask instead of the feedback art.
  bool _missed = false;

  /// Which side the respectful choice sits on — reshuffled every question
  /// so the answer is never simply "always the left one".
  final math.Random _rng = math.Random();
  bool _correctFirst = true;
  bool _answered = false;
  bool _showcase = false;
  bool _replaying = false;
  bool _curtain = false;

  /// The curtain is sliding shut (Play Again) rather than opening.
  bool _curtainClosing = false;
  bool _narrating = false;
  bool _finished = false;
  String? _prevImage;

  int _errors = 0;

  Timer? _curtainTimer;
  Timer? _showcaseTimer;
  Timer? _replayTimer;
  Timer? _revealDelayTimer;
  Timer? _revealEndTimer;
  Timer? _prevTimer;

  QuranEtiquetteSession get _session => widget.session;
  List<QuranEtiquetteQuestion> get _items => _session.questions;
  QuranEtiquetteQuestion get _q => _items[_index];

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..forward();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The prototype preloads every scene so the cross-fades never flash.
    final config = createLocalImageConfiguration(context);
    for (final q in _items) {
      AssetImage(q.image).resolve(config);
      AssetImage(q.feedbackImage).resolve(config);
    }
  }

  @override
  void dispose() {
    for (final t in [_curtainTimer, _showcaseTimer, _replayTimer, _prevTimer]) {
      t?.cancel();
    }
    _stopReveal();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _clock.dispose();
    super.dispose();
  }

  static Duration _ms(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  // -------------------------------------------------------------------------
  // Flow
  // -------------------------------------------------------------------------

  void _wipe() {
    _curtainTimer?.cancel();
    setState(() {
      _curtain = true;
      _curtainClosing = false;
      _curtainT0 = _now;
    });
    _curtainTimer = Timer(_ms(_kCurtain), () {
      if (!mounted) return;
      setState(() => _curtain = false);
    });
  }

  /// Play Again: the curtain slides shut over the ending screen, then the
  /// session restarts behind it and the usual tile-and-open plays.
  void _playAgain() {
    if (_curtain) return;
    _curtainTimer?.cancel();
    setState(() {
      _curtain = true;
      _curtainClosing = true;
      _curtainT0 = _now;
    });
    _curtainTimer = Timer(_ms(_kCurtainClose), () {
      if (!mounted) return;
      _openSession();
    });
  }

  void _stopReveal() {
    _revealDelayTimer?.cancel();
    _revealEndTimer?.cancel();
  }

  /// The prototype's `reveal(delay)` — the prompt is shown in the narration
  /// bar while its progress fills over `revealSeconds`; the choices only
  /// appear once it is done (or skipped).
  void _reveal(double delay) {
    _stopReveal();
    setState(() {
      _narrating = true;
      _barT0 = _now;
      _revealT0 = _now + delay;
    });
    _revealDelayTimer = Timer(_ms(delay), () {
      if (!mounted) return;
      setState(() => _revealT0 = _now);
      _revealEndTimer = Timer(_ms(_kReveal), () {
        if (!mounted) return;
        setState(() {
          _narrating = false;
          _panelT0 = _now;
        });
      });
    });
  }

  void _beginQuestion() {
    _correctFirst = _rng.nextBool();
    _wipe();
    _reveal(_kRevealDelay);
  }

  void _openSession() {
    _showcaseTimer?.cancel();
    setState(() {
      _screen = _Screen.play;
      _screenT0 = _now;
      _sceneT0 = _now;
      _index = 0;
      _correct = 0;
      _results.clear();
      _missed = false;
      _answered = false;
      _showcase = false;
      _finished = false;
      _prevImage = null;
      _errors = 0;
    });
    _beginQuestion();
  }

  /// Either choice ends the question: the right one shows the feedback art
  /// under a green mask, the other keeps the scene under a red one. Both
  /// hold for [_kShowcase] with nothing else on screen, then move on, and
  /// the Star Meter marks the socket accordingly.
  void _pick(bool good) {
    if (_answered || _missed || _narrating) return;
    if (good) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _answered = good;
      _missed = !good;
      _showcase = true;
      _successT0 = _now;
      _results.add(good);
      if (good) {
        _correct = math.min(_correct + 1, _items.length);
      } else {
        _errors += 1;
      }
    });
    _showcaseTimer?.cancel();
    _showcaseTimer = Timer(_ms(_kShowcase), () {
      if (!mounted) return;
      _next();
    });
  }

  void _next() {
    if (_index + 1 >= _items.length) {
      setState(() {
        _finished = true;
        _showcase = false;
        _finishT0 = _now;
      });
      return;
    }
    final shown = _q.feedbackImage;
    _prevTimer?.cancel();
    _prevTimer = Timer(_ms(_kPrevHold), () {
      if (!mounted) return;
      setState(() => _prevImage = null);
    });
    setState(() {
      _index += 1;
      _answered = false;
      _missed = false;
      _showcase = false;
      _prevImage = shown;
      _sceneT0 = _now;
    });
    _beginQuestion();
  }

  void _home() {
    _stopReveal();
    _curtainTimer?.cancel();
    _showcaseTimer?.cancel();
    setState(() {
      _screen = _Screen.start;
      _screenT0 = _now;
      _index = 0;
      _correct = 0;
      _results.clear();
      _missed = false;
      _answered = false;
      _showcase = false;
      _curtain = false;
      _finished = false;
      _narrating = false;
      _prevImage = null;
    });
  }

  void _replay() {
    setState(() {
      _replaying = true;
      _replayT0 = _now;
    });
    _replayTimer?.cancel();
    _replayTimer = Timer(_ms(_kReplaySpin), () {
      if (!mounted) return;
      setState(() => _replaying = false);
    });
    _reveal(0);
  }

  void _skip() {
    _stopReveal();
    setState(() {
      _narrating = false;
      _panelT0 = _now;
    });
  }

  /// The Qur'an Hero card's home button — the session is done, so it reports
  /// the score up to the lesson player.
  void _finish() {
    final attempts = _items.length + _errors;
    final accuracy = attempts == 0 ? 100.0 : _items.length / attempts * 100.0;
    widget.onComplete(widget.xp, accuracy, _errors);
  }

  // -------------------------------------------------------------------------
  // Frame
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _stageBack,
      child: LayoutBuilder(
        builder: (context, box) {
          final k = math.min(box.maxWidth / _kW, box.maxHeight / _kH);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_screen == _Screen.start)
                _buildStartScene()
              else
                _buildSceneBackdrop(),
              Center(
                child: AspectRatio(
                  aspectRatio: _kW / _kH,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _kW,
                      height: _kH,
                      child: _screen == _Screen.start
                          ? const SizedBox.shrink()
                          : _buildPlay(),
                    ),
                  ),
                ),
              ),
              _buildBack(k),
              if (_curtain) _buildCurtain(box.maxHeight, k),
            ],
          );
        },
      ),
    );
  }

  /// The back button, pinned to the screen's own left edge (not the
  /// centred 1600x900 frame) and scaled with the frame. On the start screen
  /// it leaves the lesson; in play it returns to the start screen.
  Widget _buildBack(double k) {
    final onBack = _screen == _Screen.start ? widget.onExit : _home;
    if (onBack == null || _showcase || _finished) {
      return const SizedBox.shrink();
    }
    final pad = MediaQuery.paddingOf(context);
    return Positioned(
      left: pad.left + 16,
      top: pad.top + 20 * k,
      // Home on the start screen (leaves the lesson), back arrow in play.
      child: _screen == _Screen.start
          ? _artButton('home_btn', 88 * k, onBack, label: 'Home')
          : _artButton('back_btn', 88 * k, onBack, label: 'Back'),
    );
  }

  Widget _fx(Widget Function(double t) builder) => AnimatedBuilder(
    animation: _clock,
    builder: (_, _) => builder(_now - _screenT0),
  );

  Widget _cover(String asset) => SizedBox.expand(
    child: Image.asset(asset, fit: BoxFit.cover, gaplessPlayback: true),
  );

  // =========================================================================
  // Title screen
  // =========================================================================

  /// The start scene, laid out in the background art's own 1870x841 frame
  /// and cover-fitted, so the logo, ribbon and Start button stay exactly
  /// where the two children point on any screen shape.
  Widget _buildStartScene() {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _kArtW,
          height: _kArtH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: _startBackground()),
              for (var i = 0; i < _kRays.length; i++) _startRay(i),
              Positioned.fill(
                child: IgnorePointer(
                  child: _fx((t) => CustomPaint(painter: _MotesPainter(t))),
                ),
              ),
              _startLogo(),
              _startRibbon(),
              _startButton(),
              _startSpark(0.31, 0.12, 30, 1.5),
              _startSpark(0.67, 0.08, 24, 2.1),
              _startSpark(0.66, 0.52, 20, 2.6),
              // Fade up from the dark stage.
              Positioned.fill(
                child: IgnorePointer(
                  child: _fx((t) {
                    final o = 1 - _easeOut.transform(_once(t, 1.0));
                    return o <= 0
                        ? const SizedBox.shrink()
                        : ColoredBox(color: _stageBack.withValues(alpha: o));
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Focus-pull in (zoom out of a soft blur), then holds still. The
  /// lanterns and the two corner plants are cut out of the art, so they
  /// ride the same focus-pull while they swing and sway.
  Widget _startBackground() {
    final scene = Stack(
      clipBehavior: Clip.none,
      children: [
        Image.asset(
          '$_kA/start_bg.jpg',
          width: _kArtW,
          height: _kArtH,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
        for (var i = 0; i < _kLanterns.length; i++) _lantern(i),
        _plant(left: true),
        _plant(left: false),
      ],
    );
    return _fx((t) {
      final p = _sceneCurve.transform(_once(t, 1.1));
      if (p >= 1) return scene;
      final blur = 6 * (1 - p);
      return ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.clamp,
        ),
        child: Transform.scale(scale: 1.1 - 0.1 * p, child: scene),
      );
    });
  }

  /// A hanging lantern swinging on its hook like a pendulum, at the period
  /// its length gives it. The swing eases up from rest, with a slow draught
  /// and a faint overtone layered on so no two swings match.
  Widget _lantern(int i) {
    final l = _kLanterns[i];
    // T = 2*pi*sqrt(L/g), reading the art at ~100px to the metre.
    final period = 2 * math.pi * math.sqrt(l.h * 0.6 / 100 / 9.81);
    const amp = 2.6 * _deg;
    final phase = i * 1.9;
    final hangX = l.pivotX - l.left;
    final sprite = Image.asset(
      '$_kA/${l.asset}.png',
      width: l.w,
      height: l.h,
      fit: BoxFit.fill,
      gaplessPlayback: true,
    );
    return Positioned(
      left: l.left,
      top: l.top,
      width: l.w,
      height: l.h,
      child: IgnorePointer(
        child: _fx((t) {
          final w = 2 * math.pi / period;
          final draught = 1 + 0.25 * math.sin(t * 0.37 + phase);
          final swing =
              math.sin(w * t + phase) * draught +
              0.12 * math.sin(w * 2.7 * t + phase * 1.3);
          final ramp = _easeInOut.transform(_once(t, 2.5, 0.6));
          final flicker = _loop(t - (l.pivotX * 0.0039) % 1.4, 2.6);
          const stops = [0.0, 0.4, 0.7, 1.0];
          final o = _kf(flicker, stops, [0.55, 0.95, 0.7, 0.55], _easeInOut);
          final s = _kf(flicker, stops, [0.92, 1.05, 0.98, 0.92], _easeInOut);
          return Transform.rotate(
            angle: amp * ramp * swing,
            origin: Offset(hangX - l.w / 2, -l.h / 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: sprite),
                Positioned(
                  left: l.w / 2 - 75,
                  top: l.h * 0.5 - 75,
                  width: 150,
                  height: 150,
                  child: Opacity(
                    opacity: o * _once(t, 0.8, 0.3),
                    child: Transform.scale(scale: s, child: const _Glow()),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// A potted plant by the wall, rooted in its pot: an indoor draught sways
  /// it slowly with the odd stronger breath, the stems bending more toward
  /// the tips, and each leaf flutters a little out of step with the next.
  Widget _plant({required bool left}) {
    final phase = left ? 0.0 : 2.4;
    return Positioned(
      left: left ? 0 : 1574,
      top: left ? 337 : 316,
      width: left ? 123 : 131,
      height: left ? 177 : 185,
      child: IgnorePointer(
        child: _fx((t) {
          final gust = math.pow(_wave(t + phase * 3, 9.5), 3).toDouble();
          final sway =
              0.6 * math.sin(2 * math.pi * t / 4.6 + phase) +
              0.3 * math.sin(2 * math.pi * t / 2.1 + phase * 1.7);
          return _BendSprite(
            asset: left ? '$_kA/plant_left.png' : '$_kA/plant_right.png',
            bend: (sway * (1 + gust) + 0.7 * gust) * (left ? 1 : -1) * 0.035,
            flutter: 0.012 * (0.4 + gust),
            t: t + phase,
          );
        }),
      ),
    );
  }

  /// A soft sunbeam slanting in through the left windows, fading in and out.
  Widget _startRay(int i) {
    return Positioned(
      left: _kRays[i],
      top: -120,
      width: 150,
      height: 1100,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -32 * _deg,
          alignment: Alignment.topCenter,
          child: _fx((t) {
            final p = _loop(t - i * 2.3, 7);
            final o = _kf(p, [0, 0.5, 1], [0.15, 0.5, 0.15], _easeInOut);
            return Opacity(
              opacity: o * _easeOut.transform(_once(t, 1.2, 0.4)),
              child: const RepaintBoundary(
                child: CustomPaint(painter: _RayPainter()),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// The title plaque: drops in and settles, then holds still, with a
  /// shine sweeping across it every few seconds.
  Widget _startLogo() {
    final logo = Image.asset(
      '$_kA/start_logo.png',
      width: 660,
      height: 512,
      fit: BoxFit.fill,
    );
    return Positioned(
      left: (_kArtW - 660) / 2,
      top: 8,
      child: _fx((t) {
        final p = _once(t, 0.9, 0.35);
        final e = _logoIn.transform(p);
        final sweep = t > 1.6 ? _loop(t - 1.6, 5) / 0.3 : 2.0;
        final x = -0.3 + 1.6 * _easeInOut.transform(_c01(sweep));
        return Opacity(
          opacity: _easeOut.transform(_c01(p * 2.5)),
          child: Transform.translate(
            offset: Offset(0, -70 * (1 - e)),
            child: Transform.scale(
              scale: 0.6 + 0.4 * e,
              child: sweep >= 1
                  ? logo
                  : ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (b) => LinearGradient(
                        begin: const Alignment(-1, -0.2),
                        end: const Alignment(1, 0.2),
                        colors: const [
                          Color(0x00FFFFFF),
                          Color(0x8CFFFFFF),
                          Color(0x00FFFFFF),
                        ],
                        stops: [_c01(x - 0.11), _c01(x), _c01(x + 0.11)],
                      ).createShader(b),
                      child: logo,
                    ),
            ),
          ),
        );
      }),
    );
  }

  /// The subtitle ribbon unrolls outward from its centre once the logo
  /// lands, sitting across the plaque's lower rim just under "Etiquette".
  Widget _startRibbon() {
    final ribbon = Image.asset(
      '$_kA/start_ribbon.png',
      width: 546,
      height: 119,
      fit: BoxFit.fill,
    );
    return Positioned(
      left: 0,
      right: 0,
      top: 420,
      child: Center(
        child: _fx((t) {
          final p = _curtainCurve.transform(_once(t, 0.7, 0.95));
          return ClipRect(
            child: Align(
              alignment: Alignment.center,
              widthFactor: math.max(p, 0.001),
              child: ribbon,
            ),
          );
        }),
      ),
    );
  }

  /// Start rises in last, then breathes to invite the tap.
  Widget _startButton() {
    return Positioned(
      left: (_kArtW - 500) / 2,
      top: 616,
      child: _fx((t) {
        final p = _once(t, 0.6, 1.45);
        final e = _btnIn.transform(p);
        final b = t > 2.1 ? _wave(t - 2.1, 2.2) : 0.0;
        return Opacity(
          opacity: _easeOut.transform(_c01(p * 2)),
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - e)),
            child: Transform.scale(
              scale: (0.8 + 0.2 * e) * (1 + 0.04 * b),
              child: Semantics(
                button: true,
                label: 'Start',
                child: _Push(
                  key: ValueKey('qe-play-${_session.number}'),
                  onTap: _openSession,
                  dy: 5,
                  builder: (down) => Image.asset(
                    down ? '$_kA/start_btn_down.png' : '$_kA/start_btn.png',
                    width: 500,
                    height: 148,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _startSpark(double x, double y, double size, double delay) {
    return Positioned(
      left: x * _kArtW,
      top: y * _kArtH,
      child: IgnorePointer(
        child: _fx(
          (t) =>
              t < delay ? const SizedBox.shrink() : _sparkle(size, 1.6, delay),
        ),
      ),
    );
  }

  // =========================================================================
  // Play screen
  // =========================================================================

  /// Scene art, full-bleed: the outgoing feedback image held underneath, the
  /// new question sharpening in over it (ch-scene), and the feedback image
  /// cross-fading in once the right choice is picked.
  Widget _buildSceneBackdrop() {
    return ColoredBox(
      color: _sceneBase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_prevImage != null) _cover(_prevImage!),
          _fx((_) {
            final p = _sceneCurve.transform(_once(_now - _sceneT0, 0.6));
            final blur = 7 * (1 - p);
            Widget img = Transform.scale(
              scale: 1.05 - 0.05 * p,
              child: _cover(_q.image),
            );
            if (blur > 0.05) {
              img = ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: blur,
                  sigmaY: blur,
                  tileMode: TileMode.clamp,
                ),
                child: img,
              );
            }
            return Opacity(opacity: p, child: img);
          }),
          if (_answered)
            _fx((_) {
              final p = _easeOut.transform(_once(_now - _successT0, 0.7));
              return Opacity(opacity: p, child: _cover(_q.feedbackImage));
            }),
          if (_showcase) _buildMumtaz(),
          if (_showcase) _buildCorrectFrame(),
          if (_finished)
            _fx((_) {
              final p = _easeOut.transform(_once(_now - _finishT0, 0.45));
              return ColoredBox(color: Color.fromRGBO(14, 26, 17, 0.74 * p));
            }),
        ],
      ),
    );
  }

  /// MUMTAZ! over the characters' heads on the feedback art — laid out in
  /// the art's own 2400x1080 frame (cover-fitted like the art), so it lands
  /// on the same heads on any screen shape.
  ///
  /// A wrong pick shows the Try Again! badge in the same spot instead.
  Widget _buildMumtaz() {
    final w = _missed ? 480.0 : 540.0;
    final h = _missed ? w * 443 / 800 : w * 401 / 900;
    return IgnorePointer(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _kSceneW,
            height: _kSceneH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _q.badgeX * _kSceneW - w / 2,
                  top: _q.badgeY * _kSceneH - h / 2,
                  width: w,
                  height: h,
                  child: _fx((_) {
                    final t = _now - _successT0;
                    final pop = _once(t, 0.55, 0.25);
                    final bob = t > 0.8 ? _wave(t - 0.8, 1.8) : 0.0;
                    return Opacity(
                      opacity: _c01(pop * 2.5),
                      child: Transform.translate(
                        offset: Offset(0, -10 * bob),
                        child: Transform.scale(
                          scale: _kf(
                            pop,
                            [0, 0.6, 0.8, 1],
                            [0.3, 1.12, 0.96, 1],
                            _easeOut,
                          ),
                          child: _glowingMumtaz(t, w, h),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The MUMTAZ! art lit up: a breathing golden halo behind it, a blurred
  /// gold copy hugging its outline, the art itself brightened, a gloss
  /// sweeping across it and sparkles twinkling at its corners.
  Widget _glowingMumtaz(double t, double w, double h) {
    final glow = t > 0.5 ? _wave(t - 0.5, 1.2) : 0.0;
    final art = Image.asset(
      _missed ? '$_kA/try_again.png' : '$_kA/mumtaz_correct.png',
      width: w,
      height: h,
    );
    final sweep = _loop(math.max(0, t - 0.6), 1.8) / 0.45;
    final x = -0.3 + 1.6 * _easeInOut.transform(_c01(sweep));
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Soft golden halo.
        Transform.scale(
          scaleX: 1.35 + 0.08 * glow,
          scaleY: 2.1 + 0.12 * glow,
          child: Container(
            width: w,
            height: w * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.fromRGBO(255, 244, 170, 0.75 + 0.2 * glow),
                  Color.fromRGBO(255, 214, 80, 0.35 + 0.15 * glow),
                  const Color.fromRGBO(255, 214, 80, 0),
                ],
                stops: const [0, 0.38, 0.72],
              ),
            ),
          ),
        ),
        // Glow hugging the badge's own outline.
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: 16 + 8 * glow,
            sigmaY: 16 + 8 * glow,
          ),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Color.fromRGBO(255, 236, 120, 0.85 + 0.15 * glow),
              BlendMode.srcIn,
            ),
            child: Transform.scale(scale: 1.04, child: art),
          ),
        ),
        // The art, a touch brighter, with a gloss sweep.
        ColorFiltered(
          colorFilter: ColorFilter.matrix(_brighten(1.08 + 0.06 * glow)),
          child: sweep >= 1
              ? art
              : ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (b) => LinearGradient(
                    begin: const Alignment(-1, -0.4),
                    end: const Alignment(1, 0.4),
                    colors: const [
                      Color(0x00FFFFFF),
                      Color(0xB3FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                    stops: [_c01(x - 0.09), _c01(x), _c01(x + 0.09)],
                  ).createShader(b),
                  child: art,
                ),
        ),
        Positioned(left: -10, top: h * 0.1, child: _sparkle(48, 1.1, 0)),
        Positioned(right: -6, top: h * 0.05, child: _sparkle(40, 1.4, 0.3)),
        Positioned(left: w * 0.2, bottom: -14, child: _sparkle(30, 1.2, 0.6)),
        Positioned(right: w * 0.18, bottom: -8, child: _sparkle(34, 1.6, 0.2)),
      ],
    );
  }

  /// Scales RGB by [k] — a simple brightness lift for the MUMTAZ! art.
  static List<double> _brighten(double k) => [
    k, 0, 0, 0, 0, //
    0, k, 0, 0, 0, //
    0, 0, k, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// A vignette mask over the whole picture while the answer is shown —
  /// green for the respectful choice, red for the other.
  Widget _buildCorrectFrame() {
    return IgnorePointer(
      child: _fx((_) {
        final t = _now - _successT0;
        final inT = _easeOut.transform(_once(t, 0.4));
        final pulse = t > 0.4 ? _wave(t - 0.4, 1.4) : 0.0;
        return CustomPaint(
          painter: _CorrectFramePainter(
            opacity: inT,
            pulse: pulse,
            wrong: _missed,
          ),
          child: const SizedBox.expand(),
        );
      }),
    );
  }

  Widget _buildPlay() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The ending screen stands alone — no meter, prompt or choices.
        if (!_showcase && !_finished) _buildChrome(),
        if (_narrating && !_finished) _buildNarrationBar(),
        if (!_narrating && !_showcase && !_finished) _buildPanel(),
        if (_finished) _buildFinish(),
      ],
    );
  }

  Widget _buildChrome() {
    return Positioned(
      top: 20,
      left: 26,
      right: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: Center(child: _starMeter()))],
      ),
    );
  }

  /// The painted Star Meter tile — one socket per question; a gold star
  /// fills it for the respectful choice, a red star for the other.
  Widget _starMeter() {
    const w = 460.0;
    const h = w * 208 / 900;
    const star = h * 0.52;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('$_kA/star_meter.png', fit: BoxFit.fill),
          ),
          for (var i = 0; i < _results.length && i < _kSockets.length; i++)
            Positioned(
              left: _kSockets[i] * w - star / 2,
              top: 0.493 * h - star / 2,
              width: star,
              height: star,
              child: _meterStar(
                good: _results[i],
                animate: i == _results.length - 1,
                size: star,
              ),
            ),
        ],
      ),
    );
  }

  Widget _meterStar({
    required bool good,
    required bool animate,
    required double size,
  }) {
    final star = Center(child: _glowStar(good, size));
    if (!animate) return star;
    // ch-starwin — pops into its socket as the meter comes back after the
    // curtain opens on the next question.
    return _fx((_) {
      final p = _once(_now - _curtainT0 - 2.4, 0.55);
      return Transform.rotate(
        angle: _kf(p, [0, 0.6, 1], [-30, 10, 0], _popOut) * _deg,
        child: Transform.scale(
          scale: _kf(p, [0, 0.6, 1], [0.3, 1.35, 1], _popOut),
          child: star,
        ),
      );
    });
  }

  /// A meter star — gold for the respectful choice, red for the other —
  /// with a soft halo of its own colour breathing behind it.
  Widget _glowStar(bool good, double size, {double phase = 0}) {
    final img = Image.asset(
      good ? '$_kA/star_gold.png' : '$_kA/star_red.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    return _fx((_) {
      final g = _wave(_now + phase, 1.6);
      final c = good
          ? Color.fromRGBO(255, 214, 70, 0.55 + 0.35 * g)
          : Color.fromRGBO(255, 70, 60, 0.45 + 0.3 * g);
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.55,
            height: size * 0.55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c,
                  blurRadius: size * (0.45 + 0.2 * g),
                  spreadRadius: size * (0.1 + 0.08 * g),
                ),
              ],
            ),
          ),
          Transform.scale(scale: 1 + 0.05 * g, child: img),
        ],
      );
    });
  }

  /// The prompt, read over a filling bar, with its Skip.
  Widget _buildNarrationBar() {
    return Positioned(
      left: 26,
      right: 26,
      bottom: 34,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (_, _) {
          final inT = _easeOut.transform(_once(_now - _barT0, 0.3));
          final pct = _c01((_now - _revealT0) / _kReveal);
          return Opacity(
            opacity: inT,
            child: Transform.translate(
              offset: Offset(0, 26 - 26 * inT),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 26, 20),
                decoration: BoxDecoration(
                  color: _creamPanel,
                  border: Border.all(color: _creamEdge, width: 5),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: const [
                    BoxShadow(color: Color(0x29000000), offset: Offset(0, 8)),
                    BoxShadow(
                      color: Color(0x47000000),
                      offset: Offset(0, 16),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Image.asset('$_kA/speaker_btn.png', width: 86, height: 86),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _q.prompt,
                            style: const TextStyle(
                              fontFamily: _kBaloo,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              height: 1.24,
                              color: _promptInk,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: _barTrack,
                              border: Border.all(
                                color: _barTrackEdge,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: pct,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [_meterFill, _leafGreenDeep],
                                    ),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(999),
                                    ),
                                  ),
                                  child: SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    _Push(
                      onTap: _skip,
                      builder: (down) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [_gold, _goldDrop],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: _goldDropShade,
                              offset: Offset(0, down ? 3 : 7),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontFamily: _kBaloo,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _goldInk,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPanel() {
    return Positioned(
      left: 26,
      right: 26,
      bottom: 24,
      child: _fx((_) {
        final p = _easeOut.transform(_once(_now - _panelT0, 0.34));
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 26 - 26 * p),
            child: Container(
              padding: const EdgeInsets.fromLTRB(30, 22, 30, 26),
              decoration: BoxDecoration(
                color: _creamPanel,
                border: Border.all(color: _creamEdge, width: 5),
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x38000000),
                    offset: Offset(0, -6),
                    blurRadius: 26,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _promptRow(),
                  const SizedBox(height: 22),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < 2; i++) ...[
                          if (i > 0) const SizedBox(width: 26),
                          Expanded(
                            child: _choice(
                              label: i == 0 ? 'A' : 'B',
                              text: (i == 0) == _correctFirst
                                  ? _q.correct
                                  : _q.decoy,
                              onTap: () => _pick((i == 0) == _correctFirst),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _promptRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _q.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _kBaloo,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              height: 1.24,
              color: _promptInk,
            ),
          ),
        ),
        const SizedBox(width: 26),
        // Hear it again — the speaker gives a little bounce while replaying.
        _fx((_) {
          final p = _replaying ? _once(_now - _replayT0, _kReplaySpin) : 1.0;
          final s = _kf(p, [0, 0.35, 1], [1, 1.12, 1], _easeInOut);
          return Transform.scale(
            scale: s,
            child: _artButton(
              'speaker_btn',
              92,
              _replay,
              label: 'Hear it again',
            ),
          );
        }),
      ],
    );
  }

  /// One answer card — both look the same (cream and gold, lettered A/B),
  /// so neither colour nor icon gives the answer away.
  Widget _choice({
    required String label,
    required String text,
    required VoidCallback onTap,
  }) {
    return _Push(
      onTap: onTap,
      builder: (down) => Container(
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBEF), Color(0xFFF6E9C8)],
          ),
          border: Border.all(color: _tileEdge, width: 5),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC99A2E),
              offset: Offset(0, down ? 4 : 8),
            ),
            const BoxShadow(
              color: Color(0x29000000),
              offset: Offset(0, 12),
              blurRadius: 22,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 74,
              height: 74,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_tileTop, _tileBottom],
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: _kBaloo,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: _tileInk,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: _kBaloo,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: _endInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Overlays
  // =========================================================================

  /// ch-twinkle — a ✦ that pulses and rocks.
  Widget _sparkle(double size, double period, double delay) {
    final p = _loop(_now - delay, period);
    return Opacity(
      opacity: _kf(p, [0, 0.5, 1], [0.3, 1, 0.3], _easeInOut),
      child: Transform.rotate(
        angle: _kf(p, [0, 0.5, 1], [-10, 12, -10], _easeInOut) * _deg,
        child: Transform.scale(
          scale: _kf(p, [0, 0.5, 1], [0.7, 1.2, 0.7], _easeInOut),
          child: Text(
            '✦',
            style: TextStyle(
              fontSize: size,
              height: 1,
              color: _twinkleInk,
              shadows: [Shadow(color: _ringYellow, blurRadius: size * 0.36)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurtain(double h, double k) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: _fx((_) {
            // Play Again closes the curtain first, with no tile yet; the
            // normal 3s run then starts from shut.
            final t = _curtainClosing ? -1.0 : _now - _curtainT0;
            // 3s: the tile pops in, holds, bows out, then the curtain opens.
            final slide = _curtainClosing
                ? _kf(
                    _now - _curtainT0,
                    [0, _kCurtainClose],
                    [1.04, 0],
                    _curtainCurve,
                  )
                : _kf(t, [0, 2.4, 3.0], [0, 0, 1.04], _curtainCurve);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: -h * 0.502 * slide,
                  height: h * 0.502,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_curtainLit, _curtainDim],
                      ),
                      boxShadow: [
                        BoxShadow(color: _curtainShade, offset: Offset(0, 6)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -h * 0.502 * slide,
                  height: h * 0.502,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_curtainDim, _curtainLit],
                      ),
                      boxShadow: [
                        BoxShadow(color: _curtainShade, offset: Offset(0, -6)),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: _kf(
                        t,
                        [0, 0.35, 2.25, 2.55],
                        [0, 1, 1, 0],
                        _easeOut,
                      ),
                      child: Transform.scale(
                        scale:
                            k *
                            _kf(
                              t,
                              [0, 0.35, 0.6, 2.25, 2.55],
                              [0.6, 1.04, 1, 1, 0.9],
                              _easeOut,
                            ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 62,
                            vertical: 30,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_tileTop, _tileBottom],
                            ),
                            border: Border.all(color: _tileEdge, width: 7),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x38000000),
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _session.tag,
                                style: const TextStyle(
                                  fontFamily: _kNunito,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 26 * 0.14,
                                  color: _sunYellow,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Question ${_index + 1}',
                                style: const TextStyle(
                                  fontFamily: _kBaloo,
                                  fontSize: 62,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  color: _tileInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // =========================================================================
  // Ending screen
  // =========================================================================

  /// The session's ending screen over the dimmed last scene: the MUMTAZ!
  /// panel with the tally, one star per question and what was learned, the
  /// two children cheering either side, and Home / Play Again below.
  Widget _buildFinish() {
    return Positioned.fill(
      child: _fx((_) {
        final t = _now - _finishT0;
        final card = _once(t, 0.55);
        final kidsIn = _once(t, 0.7, 0.25);
        final btn = _once(t, 0.5, 0.85);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // A low score swaps in the encouraging poses (thumbs-up, hand
            // on heart) instead of the victory jumps.
            _endKid(
              _lowScore ? 'end_boy_cheer' : 'end_boy',
              left: 40,
              height: 600,
              aspect: _lowScore ? 600 / 1186 : 600 / 904,
              p: kidsIn,
              t: t,
              fromLeft: true,
            ),
            _endKid(
              _lowScore ? 'end_girl_cheer' : 'end_girl',
              right: 40,
              height: 560,
              aspect: _lowScore ? 600 / 1062 : 600 / 826,
              p: kidsIn,
              t: t + 1.2,
              fromLeft: false,
            ),
            Positioned(
              left: (_kW - _kPanelW) / 2,
              top: 12,
              width: _kPanelW,
              height: _kPanelH,
              child: Opacity(
                opacity: _kf(card, [0, 0.55, 1], [0, 1, 1]),
                child: Transform.scale(
                  scale: _kf(
                    card,
                    [0, 0.55, 0.75, 1],
                    [0.3, 1.08, 0.97, 1],
                    _popOut,
                  ),
                  child: FittedBox(child: _endPanel(t)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 12 + _kPanelH - 20,
              child: Opacity(
                opacity: _easeOut.transform(_c01(btn * 2)),
                child: Transform.translate(
                  offset: Offset(0, 40 * (1 - _btnIn.transform(btn))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      KeyedSubtree(
                        key: const ValueKey('qe-home'),
                        child: _artButton(
                          'home_btn',
                          104,
                          _finish,
                          label: 'Home',
                        ),
                      ),
                      const SizedBox(width: 18),
                      _playAgainButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// A cheering child sliding in from their side, then standing still.
  Widget _endKid(
    String name, {
    double? left,
    double? right,
    required double height,
    required double aspect,
    required double p,
    required double t,
    required bool fromLeft,
  }) {
    final e = _btnIn.transform(p);
    return Positioned(
      left: left,
      right: right,
      bottom: 6,
      child: Opacity(
        opacity: _c01(p * 2),
        child: Transform.translate(
          offset: Offset((fromLeft ? -260 : 260) * (1 - e), 0),
          child: Image.asset(
            '$_kA/$name.png',
            height: height,
            width: height * aspect,
          ),
        ),
      ),
    );
  }

  Widget _playAgainButton() {
    return Semantics(
      button: true,
      label: 'Play Again',
      child: _Push(
        onTap: _playAgain,
        dy: 3,
        builder: (down) => SizedBox(
          width: 440,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  down
                      ? '$_kA/play_again_btn_down.png'
                      : '$_kA/play_again_btn.png',
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 36),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 52,
                        color: Colors.white,
                      ),
                      SizedBox(width: 14),
                      Text(
                        'Play Again',
                        style: TextStyle(
                          fontFamily: _kBaloo,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Color(0x55062A6B),
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Under half the stars — the ending cheers the learner on to try again
  /// rather than celebrating.
  bool get _lowScore => _correct * 2 < _items.length;

  /// The MUMTAZ! panel, laid out at the art's own 1100px width and scaled
  /// down to fit. The art is nine-sliced so the banner keeps its shape while
  /// the cream card stretches to hold the summary.
  Widget _endPanel(double t) {
    final n = _items.length;
    return SizedBox(
      width: 1100,
      height: _kPanelH * 1100 / _kPanelW,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              '$_kA/end_panel.png',
              centerSlice: const Rect.fromLTRB(90, 440, 1010, 800),
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: 110,
            right: 110,
            top: 380,
            child: Column(
              children: [
                Text(
                  _lowScore
                      ? 'Nice try! You earned $_correct of $n stars.'
                      : 'You made $_correct of $n respectful choices '
                            '${_session.title.toLowerCase()}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _kBaloo,
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: _endInk,
                  ),
                ),
                if (_lowScore) ...[
                  const SizedBox(height: 6),
                  const Text(
                    "Keep practicing — you can do it, in shaa Allah!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _kBaloo,
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: Color(0xFFB8741A),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  width: 780,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0x66E9DAB4),
                    borderRadius: BorderRadius.circular(44),
                    border: Border.all(
                      color: const Color(0xFFE3CF9F),
                      width: 4,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < n; i++) ...[
                        if (i > 0) const SizedBox(width: 26),
                        _endStar(i, t),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                _learnedBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Each result star pops into the row one after another.
  Widget _endStar(int i, double t) {
    final p = _once(t, 0.45, 0.55 + i * 0.12);
    final good = i < _results.length && _results[i];
    return Opacity(
      opacity: _c01(p * 3),
      child: Transform.scale(
        scale: _kf(p, [0, 0.6, 1], [0.3, 1.25, 1], _popOut),
        child: _glowStar(good, 104, phase: i * 0.25),
      ),
    );
  }

  Widget _learnedBox() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: 880,
          margin: const EdgeInsets.only(top: 26),
          padding: const EdgeInsets.fromLTRB(56, 44, 40, 22),
          decoration: BoxDecoration(
            color: const Color(0x80F3E7C9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE6D3A6), width: 3),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _session.lessons.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _learnedRow(
                  _session.lessons[i],
                  i < _results.length && _results[i],
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFBF1D7), Color(0xFFEBD9AC)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD9BD7E), width: 3),
          ),
          child: const Text(
            'WHAT WE LEARNED',
            style: TextStyle(
              fontFamily: _kNunito,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 34 * 0.06,
              color: Color(0xFF8A5A1E),
            ),
          ),
        ),
      ],
    );
  }

  /// A lesson line — green tick when that question was answered the
  /// respectful way, red cross when it was missed.
  Widget _learnedRow(String lesson, bool good) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: good ? const Color(0xFF3FA34D) : _decoyRed,
            border: Border.all(
              color: good ? const Color(0xFF2B7A36) : _decoyEdge,
              width: 3,
            ),
          ),
          child: Icon(
            good ? Icons.check_rounded : Icons.close_rounded,
            size: 28,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            lesson,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: _kNunito,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: _endInk,
            ),
          ),
        ),
      ],
    );
  }

  /// A painted round button with its own pressed art ([name]_down.png).
  Widget _artButton(
    String name,
    double size,
    VoidCallback onTap, {
    required String label,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: _Push(
        onTap: onTap,
        dy: 3,
        builder: (down) => Image.asset(
          down ? '$_kA/${name}_down.png' : '$_kA/$name.png',
          width: size,
          height: size,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

class _Push extends StatefulWidget {
  const _Push({
    super.key,
    required this.builder,
    required this.onTap,
    this.dy = 4,
  });

  final Widget Function(bool down) builder;
  final VoidCallback onTap;
  final double dy;

  @override
  State<_Push> createState() => _PushState();
}

class _PushState extends State<_Push> {
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
        offset: Offset(0, _down ? widget.dy : 0),
        child: widget.builder(_down),
      ),
    );
  }
}

/// The correct-answer mask: a green vignette over the whole picture —
/// clear in the middle, deepening to green towards every edge and corner,
/// breathing gently while the answer is shown.
class _CorrectFramePainter extends CustomPainter {
  _CorrectFramePainter({
    required this.opacity,
    required this.pulse,
    this.wrong = false,
  });

  final double opacity;
  final double pulse;

  /// Red instead of green — the wrong choice was picked.
  final bool wrong;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final c = size.center(Offset.zero);
    // Stretch a circle into an ellipse matching the screen, so the mask
    // follows the screen's shape rather than a round spotlight.
    final r = size.height / 2 * math.sqrt2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(size.width / size.height, 1);
    final circle = Rect.fromCircle(center: Offset.zero, radius: r);
    final a = opacity * (0.9 + 0.1 * pulse);
    canvas.drawRect(
      circle,
      Paint()
        ..shader = RadialGradient(
          colors: wrong
              ? [
                  const Color.fromRGBO(215, 50, 45, 0),
                  Color.fromRGBO(215, 50, 45, 0.22 * a),
                  Color.fromRGBO(195, 35, 35, 0.55 * a),
                  Color.fromRGBO(150, 20, 25, 0.85 * a),
                ]
              : [
                  const Color.fromRGBO(40, 190, 90, 0),
                  Color.fromRGBO(40, 190, 90, 0.22 * a),
                  Color.fromRGBO(30, 170, 80, 0.55 * a),
                  Color.fromRGBO(20, 140, 65, 0.85 * a),
                ],
          stops: [0.52 - 0.04 * pulse, 0.68, 0.84, 1],
        ).createShader(circle),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CorrectFramePainter old) =>
      old.opacity != opacity || old.pulse != pulse || old.wrong != wrong;
}

/// One sunbeam: warm light fading down its length and soft at both sides.
class _RayPainter extends CustomPainter {
  const _RayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFF0BE), Color(0x8CFFF0BE), Color(0x00FFF0BE)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF000000), Color(0x00000000)],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RayPainter old) => false;
}

/// A sprite drawn on a mesh so it can bend like a plant rooted at its
/// bottom edge: each point shifts sideways by [bend] times the sprite's
/// height, weighted toward the tips, dipping a touch as it leans, with a
/// small per-column [flutter] out of phase across the width.
class _BendSprite extends StatefulWidget {
  const _BendSprite({
    required this.asset,
    required this.bend,
    required this.flutter,
    required this.t,
  });

  final String asset;
  final double bend;
  final double flutter;
  final double t;

  @override
  State<_BendSprite> createState() => _BendSpriteState();
}

class _BendSpriteState extends State<_BendSprite> {
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
      painter: _BendPainter(image, widget.bend, widget.flutter, widget.t),
    );
  }
}

class _BendPainter extends CustomPainter {
  _BendPainter(this.image, this.bend, this.flutter, this.t);

  final ui.Image image;
  final double bend;
  final double flutter;
  final double t;

  static const int _cols = 6;
  static const int _rows = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final pos = <Offset>[];
    final tex = <Offset>[];
    Offset at(int c, int r) {
      final u = c / _cols;
      final v = r / _rows;
      final lift = math.pow(1 - v, 1.7).toDouble();
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
      old.t != t;
}

/// A lantern's warm halo.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          Color.fromRGBO(255, 214, 110, 0.75),
          Color.fromRGBO(255, 190, 60, 0.25),
          Color.fromRGBO(255, 190, 60, 0),
        ],
        stops: [0, 0.4, 0.7],
      ),
    ),
    child: SizedBox.expand(),
  );
}

/// Glowing dust drifting up through the sunlight. Deterministic per mote,
/// so it is stable between frames.
class _MotesPainter extends CustomPainter {
  _MotesPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 22; i++) {
      final p = _loop(t + i * 1.37, 9 + (i % 5) * 2.3);
      final o = _kf(p, [0, 0.15, 0.85, 1], [0, 0.9, 0.7, 0]);
      if (o <= 0) continue;
      final r = (2.0 + (i % 4)) * 1.6;
      final c = Offset(
        (i * 0.618 % 1.0) * size.width + 40 * p,
        size.height + 20 - 700 * p,
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromRGBO(255, 248, 214, o),
              const Color.fromRGBO(255, 230, 150, 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_MotesPainter old) => old.t != t;
}
