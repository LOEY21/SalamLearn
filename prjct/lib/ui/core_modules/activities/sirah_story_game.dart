import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// Sirah Story — listen to the scene, tap the thing that lights up, answer
/// the question it asks. Ported 1:1 from the supplied "Sirah Story" design
/// prototype: same start screen and loading beat, narration bar, glow-and-tap,
/// question card with its "?" medallion, MUMTAZ! badge, confetti, page dots,
/// leave-the-story confirm and Session Complete screen, with the same copy and
/// motion.
///
/// Each scene is the prototype's own cut-out layers over a new painted
/// backdrop sized to the screen (see [SirahStoryLayer] for how the
/// prototype's CSS placement was carried across to the wider frame).
///
/// One [SirahStorySession] per session, distributed one per stage
/// (Destinations 4-7). The start screen is identical for every session, so a
/// learner meets the same opening whichever one they are on.
class SirahStoryGame extends StatefulWidget {
  const SirahStoryGame({
    super.key,
    required this.session,
    required this.xp,
    required this.onComplete,
    this.onExit,
  });

  final SirahStorySession session;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Leaves the lesson — wired to the start screen's ✕, the one place the
  /// prototype's layout has room for an exit.
  final VoidCallback? onExit;

  @override
  State<SirahStoryGame> createState() => _SirahStoryGameState();
}

// ---------------------------------------------------------------------------
// Frame, palette, timings — all lifted from the prototype.
// ---------------------------------------------------------------------------

/// The scene art's own frame. The prototype drew into a 16/9 box; these
/// backdrops are painted 1870x841, so the stage is that, and every layer's
/// fractional placement lands exactly where it was authored.
const double _kW = 1870;
const double _kH = 841;

const String _kBaloo = 'Baloo2';

// Title-screen art, sized off the reference composition. Aspects are the
// cropped assets' own, so nothing stretches.
const double _kLogoW = 0.50 * _kW;
const double _kLogoAspect = 1773 / 869;
const double _kRibbonW = 0.36 * _kW;
const double _kRibbonAspect = 2105 / 683;
const double _kPlayW = 0.30 * _kW;
const double _kPlayAspect = 2066 / 696;

// Ending screen, laid out to the supplied reference. The cheering cut-outs
// stand exactly where the backdrop's own two children are, covering them.
const double _kEndKidW = 0.24 * _kW;
const double _kEndBoyAspect = 1008 / 1371;
const double _kEndGirlAspect = 1034 / 1353;
const double _kEndPlaqueW = 0.33 * _kW;
const double _kEndPlaqueAspect = 1269 / 955;
const double _kRibbonArtAspect = 1842 / 539;
const double _kBadgeW = 560.0; // the MUMTAZ ribbon, as the in-game badge
const double _kEndPanelW = 0.34 * _kW;
const double _kEndPanelAspect = 1378 / 427;
const double _kEndBtnW = 0.22 * _kW;
const double _kEndBtnAspect = 1874 / 620;

// Chrome buttons, each with its own pressed frame. Both states share one
// crop, so a press sinks the art instead of resizing the button.
const double _kBackW = 124.0;
const double _kBackAspect = 987 / 962;
const double _kReplayW = 360.0;
const double _kReplayAspect = 1709 / 532;

// The painted boards. Each is drawn behind its content; the long ones use a
// centre slice so they stretch to fit without pulling their corner ornament
// out of shape.
// Each board is drawn at its own aspect and its content padded inside, so
// nothing about the painted frame is stretched.
const double _kNarrationW = 1300.0;
const double _kBarH = 8.0;
// The answer tiles are the painted pill, drawn at its own aspect.
const double _kTileAspect = 1967 / 336;
// The question board is the painted frame; its "?" medallion is part of the
// art, so the content starts below it.
const double _kBoardW = 1000.0;
const double _kBoardAspect = 1347 / 1002;
const _kBoardPad = EdgeInsets.fromLTRB(90, 208, 90, 60);
const double _kSpeakerD = 84.0;
const double _kPlateW = 960.0; // the curtain's announcement plate
const double _kPlateAspect = 1906 / 729;

const _stageBack = Color(0xFF1C1710);
const _panelTop = Color(0xFFFAF0D8);
const _panelBottom = Color(0xFFEFDFBA);
const _panelEdge = Color(0xFFC9A45E);
const _ink = Color(0xFF4A3418);
const _inkSoft = Color(0xFF5A4423);
const _cream = Color(0xFFF6E9C9);
const _optionTop = Color(0xFFF7ECD2);
const _optionBottom = Color(0xFFE9D8B0);
const _optionShade = Color(0xFFBFA06A);
const _woodTop = Color(0xFF6B4A1E);
const _woodBottom = Color(0xFF4A3113);
const _woodEdge = Color(0xFFD9A441);
const _green = Color(0xFF2F7A45);
const _greenDeep = Color(0xFF1D5730);
const _greenMid = Color(0xFF3D9159);
const _greenBtnShade = Color(0xFF14472A);
const _gold = Color(0xFFFFD75E);
const _plateEyebrow = Color(0xFF8A5A17);

const _endVeil = Color(0x3DFFE9B8); // warm daylight wash over the last scene
const _scrim = Color(0x9E181006); // rgba(24,16,6,.62)
const _scrimDeep = Color(0xC7181006); // rgba(24,16,6,.78)

const List<Color> _confettiColors = [
  Color(0xFFF0A92C),
  Color(0xFF3D9159),
  Color(0xFFE15B64),
  Color(0xFF4A90D9),
  Color(0xFFFFD75E),
  Color(0xFFF6E9C9),
];

/// The prototype's own timings, in seconds.
const double _kAdvance = 2.0; // MUMTAZ! beat before the next page
/// The beat between tapping the glowing layer and its question: the scene
/// darkens and the layer eases forward, then the card assembles itself. No
/// curtain here — the learner is still looking at the thing they tapped.
const double _kOpenQuestion = 1.5;

/// The curtain wipe, which plays where the *scene* changes: into the first
/// page from the start screen, and between one page and the next. Laid out in
/// seconds: the curtain shuts, the plate comes up and **holds for 4 seconds**
/// so it can actually be read, then goes, and the curtain opens.
const double _kWipeShut = 0.9; // curtain closed by here
const double _kPlateIn = 0.6; // plate starts to swell in
const double _kPlateUp = 1.1; // plate fully up
const double _kPlateHold = 4.0; // time it sits there, readable
const double _kPlateGone = _kPlateUp + _kPlateHold + 0.5;
const double _kWipe = _kPlateGone + 0.9; // curtain drawn back by here

/// Fraction of a wipe at which what is behind the curtain changes. Kept at
/// the very end of the hold, so the next page's narration starts as the
/// curtain opens rather than playing unseen behind it.
const double _kWipeMid = (_kPlateGone - 0.1) / _kWipe;
const double _kShake = 0.42;
const double _kBadgePop = 0.45;

const Curve _curtainCurve = Cubic(0.65, 0, 0.35, 1);
const Curve _badgeOut = Cubic(0.2, 1.4, 0.5, 1); // sirah-badge

double _c01(double v) => v.clamp(0.0, 1.0);

/// Interpolates a CSS `@keyframes` track: [stops] are the percentage marks
/// (0..1) and [vals] the value at each, with [curve] applied *within* each
/// segment the way a CSS timing function is.
double _kf(double t, List<double> stops, List<double> vals, [Curve? curve]) {
  final c = curve ?? Curves.linear;
  if (t <= stops.first) return vals.first;
  for (var i = 0; i < stops.length - 1; i++) {
    if (t <= stops[i + 1]) {
      final span = stops[i + 1] - stops[i];
      final u = span <= 0 ? 1.0 : c.transform(_c01((t - stops[i]) / span));
      return vals[i] + (vals[i + 1] - vals[i]) * u;
    }
  }
  return vals.last;
}

/// `animation: <name> <dur>s <delay>s ... both` — progress 0..1, held at both
/// ends.
double _once(double t, double dur, [double delay = 0]) =>
    _c01((t - delay) / dur);

/// `animation: <name> <dur>s infinite` — repeating phase 0..1.
double _loop(double t, double dur) {
  final x = t % dur;
  return (x < 0 ? x + dur : x) / dur;
}

enum _Screen { start, play }

class _SirahStoryGameState extends State<SirahStoryGame>
    with TickerProviderStateMixin {
  // One monotonic clock drives every animation; each derives its own phase
  // from the elapsed seconds. An hour outlasts any sitting, so it never wraps
  // mid-play.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(hours: 1),
  )..forward();

  double get _now => _clock.value * 3600.0;

  /// The question card's entrance. Unlike the rest of the game's motion this
  /// runs off its own controller and is applied with FadeTransition and
  /// SlideTransition — those animate at the render layer, so the card's text
  /// and gradients are laid out once instead of being rebuilt, re-scaled and
  /// re-rasterised on every frame.
  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  Animation<double> _in(double begin, double end) => CurvedAnimation(
    parent: _card,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _inCard = _in(0.0, 0.65);
  late final Animation<double> _inChip = _in(0.12, 0.80);
  late final Animation<double> _inPrompt = _in(0.20, 0.88);
  late final Animation<double> _inAnswerA = _in(0.32, 1.0);
  late final Animation<double> _inAnswerB = _in(0.44, 1.0);

  /// The ending screen arrives the same way: one controller, render-layer
  /// transitions, each piece on its own slice of it.
  late final AnimationController _end = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  Animation<double> _endIn(double begin, double end) => CurvedAnimation(
    parent: _end,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _inVeil = _endIn(0.0, 0.22);
  late final Animation<double> _inBoy = _endIn(0.10, 0.50);
  late final Animation<double> _inGirl = _endIn(0.16, 0.56);
  late final Animation<double> _inPlaque = _endIn(0.26, 0.68);
  late final Animation<double> _inPanel = _endIn(0.50, 0.80);
  late final Animation<double> _inContinue = _endIn(0.66, 1.0);

  /// A single burst of light behind the plaque as it lands — up fast, gone
  /// slowly, so the moment has a beat of its own without flashing at anyone.
  late final Animation<double> _endFlash = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 26),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 16,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 58,
    ),
  ]).animate(_end);

  // Per-element clocks, so entrance animations restart when the thing they
  // belong to appears (the prototype gets this for free from mounting).
  double _screenT0 = 0;
  double _badgeT0 = 0;
  double _narrateT0 = 0;
  double _finishT0 = 0;

  /// When the current page's narration ended and its layer lit up.
  double _glowT0 = 0;
  double _shakeT0 = 0;

  _Screen _screen = _Screen.start;
  int _page = 0;
  bool _narrating = false;
  bool _glowReady = false;
  bool _opening = false;

  bool _curtain = false;
  double _curtainT0 = 0;
  double _curtainDur = _kOpenQuestion;
  String _curtainLabel = '';
  bool _showModal = false;
  bool _answered = false;
  bool _shake = false;
  bool _confirmExit = false;
  bool _finished = false;

  /// The prototype re-rolls which side the correct answer sits on for every
  /// page, so the right choice is never in the same place twice running.
  bool _flip = false;
  final math.Random _rng = math.Random();

  int _errors = 0;

  Timer? _narrateTimer;
  Timer? _advanceTimer;
  Timer? _shakeTimer;
  Timer? _openTimer;
  Timer? _wipeMidTimer;

  SirahStorySession get _session => widget.session;
  List<SirahStoryPage> get _pages => _session.pages;
  SirahStoryPage get _p => _pages[_page];

  @override
  void initState() {
    super.initState();
    // The scenes are painted landscape — the app is portrait-locked
    // everywhere else, so this activity flips the device for as long as it is
    // on screen and puts it back on the way out (the same trade
    // `classroom_heroes_game.dart` makes).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _narrateTimer?.cancel();
    _advanceTimer?.cancel();
    _shakeTimer?.cancel();
    _openTimer?.cancel();
    _wipeMidTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _card.dispose();
    _end.dispose();
    _clock.dispose();
    super.dispose();
  }

  static Duration _ms(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  // -------------------------------------------------------------------------
  // Flow
  // -------------------------------------------------------------------------

  /// The prototype's `onPlay()`, with the curtain in place of its loading
  /// spinner: it closes over the start screen, names the session, and opens
  /// on the first scene.
  void _startAdventure() {
    if (_curtain) return;
    HapticFeedback.mediumImpact();
    _wipe(_kWipe, _session.title, () {
      setState(() {
        _screen = _Screen.play;
        _screenT0 = _now;
        _page = 0;
        _errors = 0;
        _finished = false;
      });
      _beginPage();
    });
  }

  /// The prototype's `startNarration()` — the line is "read out" as a filling
  /// progress bar for the page's own authored duration, and only then does the
  /// scene dim and the subject light up. There is no recorded audio yet,
  /// exactly as in the prototype; the bar is the whole of the narration beat.
  void _beginPage() {
    _narrateTimer?.cancel();
    _opening = false;
    setState(() {
      _narrating = true;
      _glowReady = false;
      _flip = _rng.nextBool();
      _narrateT0 = _now;
    });
    _narrateTimer = Timer(Duration(milliseconds: _p.narrationMs), () {
      if (!mounted) return;
      setState(() {
        _narrating = false;
        _glowReady = true;
        _glowT0 = _now;
      });
    });
  }

  void _replayNarration() {
    if (!_glowReady && _narrating) return;
    // The pressed frame is the feedback now, so there is no icon left to
    // spin — the button just replays the line.
    HapticFeedback.selectionClick();
    _beginPage();
  }

  /// Classroom Heroes' `wipe()`, in this game's wood-and-gold: the curtain
  /// draws shut over the scene, holds long enough to name the question, then
  /// opens on whatever [atMidpoint] put behind it.
  void _wipe(double dur, String label, VoidCallback atMidpoint) {
    _openTimer?.cancel();
    _wipeMidTimer?.cancel();
    setState(() {
      _curtain = true;
      _curtainT0 = _now;
      _curtainDur = dur;
      _curtainLabel = label;
    });
    _wipeMidTimer = Timer(_ms(dur * _kWipeMid), () {
      if (!mounted) return;
      atMidpoint();
    });
    _openTimer = Timer(_ms(dur), () {
      if (!mounted) return;
      setState(() {
        _curtain = false;
        _opening = false;
      });
    });
  }

  /// The question card's own Back: it closes the card and hands the page
  /// back to the learner, reading the line again from the start so they can
  /// listen before answering.
  void _closeQuestion() {
    if (!_showModal) return;
    HapticFeedback.selectionClick();
    _advanceTimer?.cancel();
    setState(() {
      _showModal = false;
      _answered = false;
      _shake = false;
    });
    _beginPage();
  }

  void _tapGlow() {
    if (_showModal || _opening || !_glowReady) return;
    HapticFeedback.selectionClick();
    setState(() {
      _opening = true;
      _answered = false;
    });
    _openTimer?.cancel();
    _openTimer = Timer(_ms(_kOpenQuestion), () {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _showModal = true;
      });
      _card.forward(from: 0);
    });
  }

  void _pickCorrect() {
    if (_answered) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _answered = true;
      _badgeT0 = _now;
    });
    _advanceTimer?.cancel();
    _advanceTimer = Timer(_ms(_kAdvance), () {
      if (!mounted) return;
      final next = _page + 1;
      if (next >= _pages.length) {
        setState(() {
          _showModal = false;
          _answered = false;
          _finished = true;
          _finishT0 = _now;
        });
        _end.forward(from: 0);
      } else {
        // The scene itself changes here, so the swap happens behind the
        // curtain the same way the question's does.
        _wipe(_kWipe, 'Question ${next + 1}', () {
          setState(() {
            _page = next;
            _showModal = false;
            _answered = false;
          });
          _beginPage();
        });
      }
    });
  }

  void _pickWrong() {
    if (_answered) return;
    HapticFeedback.lightImpact();
    setState(() {
      _errors++;
      _shake = true;
      _shakeT0 = _now;
    });
    _shakeTimer?.cancel();
    _shakeTimer = Timer(_ms(_kShake), () {
      if (!mounted) return;
      setState(() => _shake = false);
    });
  }

  /// The prototype's back arrow: one page back, or — on the first page — the
  /// "Leave the story?" confirm.
  void _back() {
    _openTimer?.cancel();
    _wipeMidTimer?.cancel();
    _curtain = false;
    if (_page == 0) {
      setState(() => _confirmExit = true);
      return;
    }
    _advanceTimer?.cancel();
    setState(() {
      _page = _page - 1;
      _showModal = false;
      _answered = false;
      _finished = false;
    });
    _beginPage();
  }

  void _backToStart() {
    _narrateTimer?.cancel();
    _advanceTimer?.cancel();
    _openTimer?.cancel();
    _wipeMidTimer?.cancel();
    setState(() {
      _screen = _Screen.start;
      _screenT0 = _now;
      _page = 0;
      _opening = false;
      _curtain = false;
      _showModal = false;
      _answered = false;
      _confirmExit = false;
      _narrating = false;
      _glowReady = false;
      _finished = false;
    });
  }

  /// The ending screen's Continue Next Lesson — the lesson's only way on, so
  /// it reports the session's score up to the lesson player.
  void _finish() {
    final attempts = _pages.length + _errors;
    final accuracy = attempts == 0 ? 100.0 : _pages.length / attempts * 100.0;
    widget.onComplete(widget.xp, accuracy, _errors);
  }

  // -------------------------------------------------------------------------
  // Frame
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final backdrop = _screen == _Screen.start
        ? 'assets/images/sirah_story/start_bg.png'
        : _p.background;
    return ColoredBox(
      color: _stageBack,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fills the letterbox bands beside the stage with the same scene,
          // so the frame never shows bare black at odd aspect ratios.
          Image.asset(backdrop, fit: BoxFit.cover),
          Center(
            child: AspectRatio(
              aspectRatio: _kW / _kH,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _kW,
                  height: _kH,
                  child: _screen == _Screen.start
                      ? _buildStart()
                      : _buildPlay(),
                ),
              ),
            ),
          ),
          // The curtain is drawn at screen size, not inside the stage: the
          // stage is letterboxed on screens that aren't its exact shape, and
          // a curtain drawn in there left those bands uncovered.
          if (_curtain)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) =>
                    _buildCurtain(box.maxWidth, box.maxHeight),
              ),
            ),
        ],
      ),
    );
  }

  /// Rebuilds just the wrapped leaf on every clock tick, handing it the
  /// current time.
  Widget _fx(Widget Function(double t) builder) =>
      AnimatedBuilder(animation: _clock, builder: (_, _) => builder(_now));

  // =========================================================================
  // Start screen — identical for every session bar the card's own lines.
  // =========================================================================

  /// The title screen, laid out to the supplied reference: the scroll logo
  /// over the square, its ribbon tucked under it, and the PLAY button where
  /// the reference's blank board sits. Identical for all four sessions —
  /// which session is being opened is what the curtain plate announces.
  Widget _buildStart() {
    return Stack(
      children: [
        // The backdrop holds still; the sky above it carries the motion.
        Positioned.fill(
          child: Image.asset(
            'assets/images/sirah_story/start_bg.png',
            fit: BoxFit.cover,
          ),
        ),
        // Clouds drifting across and a few birds gliding through the sky.
        Positioned.fill(
          child: IgnorePointer(
            child: _fx((t) => CustomPaint(painter: _SkyPainter(t - _screenT0))),
          ),
        ),
        // Logo eases down and settles — no bounce, it just comes to rest.
        Positioned(
          left: (_kW - _kLogoW) / 2,
          top: 0.02 * _kH,
          child: _fx((t) {
            final e = t - _screenT0;
            final drop = Curves.easeOutCubic.transform(_once(e, 0.95, 0.15));
            return Opacity(
              opacity: Curves.easeOut.transform(
                _c01(_once(e, 0.95, 0.15) * 2.2),
              ),
              child: Transform.translate(
                offset: Offset(0, -130 * (1 - drop)),
                child: Transform.scale(
                  scale: 1.06 - 0.06 * drop,
                  child: _shine(
                    e,
                    delay: 2.4,
                    child: Image.asset(
                      'assets/images/sirah_story/title_logo.png',
                      width: _kLogoW,
                      height: _kLogoW / _kLogoAspect,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        Positioned(
          left: (_kW - _kLogoW) / 2 - 60,
          top: 0,
          width: _kLogoW + 120,
          height: 0.02 * _kH + _kLogoW / _kLogoAspect,
          child: IgnorePointer(
            child: _fx(
              (t) => CustomPaint(painter: _SparklePainter(t - _screenT0)),
            ),
          ),
        ),
        // Ribbon slides out from under the scroll and widens into place.
        Positioned(
          left: (_kW - _kRibbonW) / 2,
          top: 0.435 * _kH,
          child: _fx((t) {
            final p = Curves.easeOutCubic.transform(
              _once(t - _screenT0, 0.75, 0.7),
            );
            return Opacity(
              opacity: _c01(p * 2),
              child: Transform.translate(
                offset: Offset(0, -46 * (1 - p)),
                child: Transform.scale(
                  scaleX: 0.86 + 0.14 * p,
                  scaleY: 0.94 + 0.06 * p,
                  child: Image.asset(
                    'assets/images/sirah_story/title_ribbon.png',
                    width: _kRibbonW,
                    height: _kRibbonW / _kRibbonAspect,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            );
          }),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0.695 * _kH,
          child: Center(
            child: _fx((t) {
              final e = t - _screenT0;
              final p = Curves.easeOutCubic.transform(_once(e, 0.65, 1.45));
              final breathe = e > 2.2 ? 0.022 * math.sin((e - 2.2) * 3.0) : 0.0;
              return Opacity(
                opacity: p,
                child: Transform.translate(
                  offset: Offset(0, 46 * (1 - p)),
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * p + breathe,
                    child: _shine(e, delay: 3.2, child: _playButton()),
                  ),
                ),
              );
            }),
          ),
        ),
        if (widget.onExit != null)
          Positioned(
            left: 44,
            top: 36,
            child: _artButton(
              key: const ValueKey('sirah-exit'),
              onTap: widget.onExit!,
              asset: 'back_btn',
              width: _kBackW,
              aspect: _kBackAspect,
            ),
          ),
      ],
    );
  }

  /// A gloss highlight sliding across [child] every few seconds. It is a
  /// shader masked to the child's own alpha, so the streak only ever lands on
  /// the art itself — never on the sky around it. Always wrapped, even when
  /// idle, so the child is never rebuilt as the sweep comes and goes.
  Widget _shine(double e, {required double delay, required Widget child}) {
    const period = 4.5;
    const sweep = 1.1;
    final local = e - delay;
    final p = local < 0 ? -1.0 : _loop(local, period) * period / sweep;
    // Band centre in gradient space; parked off the art between sweeps.
    final x = (p < 0 || p > 1)
        ? -1.0
        : -0.15 + 1.3 * Curves.easeInOut.transform(p);
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (r) => LinearGradient(
        begin: const Alignment(-1, -0.7),
        end: const Alignment(1, 0.7),
        colors: const [Color(0x00FFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
        stops: [
          (x - 0.12).clamp(0.0, 1.0),
          x.clamp(0.0, 1.0),
          (x + 0.12).clamp(0.0, 1.0),
        ],
      ).createShader(r),
      child: child,
    );
  }

  Widget _playButton() {
    return _Push(
      key: const ValueKey('sirah-play'),
      onTap: _startAdventure,
      dy: 6,
      builder: (down) => Image.asset(
        down
            ? 'assets/images/sirah_story/play_btn_down.png'
            : 'assets/images/sirah_story/play_btn.png',
        width: _kPlayW,
        height: _kPlayW / _kPlayAspect,
        fit: BoxFit.fill,
        gaplessPlayback: true,
      ),
    );
  }

  // =========================================================================
  // Play screen
  // =========================================================================

  Widget _buildPlay() {
    final glowOn = _glowReady && !_showModal && !_finished;
    // The question's own darkness. It starts filling the moment the glowing
    // layer is tapped and is already all the way in by the time the card
    // pops, so the two read as one move.
    final dark = _opening || _showModal;
    const fade = Duration(milliseconds: 600);
    return Stack(
      children: [
        // A story page is a still picture and stays one — no drift, no
        // pulse. Everything the learner is asked to look at holds its place.
        Positioned.fill(child: Image.asset(_p.background, fit: BoxFit.cover)),
        ..._buildScene(glowOn),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: dark ? 1 : 0,
              duration: fade,
              curve: Curves.easeInOut,
              child: const ColoredBox(color: _scrim),
            ),
          ),
        ),
        if (!_finished)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: dark,
              child: AnimatedOpacity(
                opacity: dark ? 0 : 1,
                duration: fade,
                curve: Curves.easeInOut,
                child: Stack(
                  children: [
                    _buildBack(),
                    _buildReplay(),
                    _buildNarration(),
                    _buildDots(),
                  ],
                ),
              ),
            ),
          ),
        if (_showModal) _buildModal(),
        // Sits where the scene's own Back sits, so it reads as the same
        // button rather than a new one appearing.
        if (_showModal && !_answered)
          Positioned(
            left: 44,
            top: 36,
            child: _artButton(
              key: const ValueKey('sirah-question-back'),
              onTap: _closeQuestion,
              asset: 'back_btn',
              width: _kBackW,
              aspect: _kBackAspect,
            ),
          ),
        if (_answered) _buildConfetti(_badgeT0),
        if (_confirmExit) _buildConfirmExit(),
        if (_finished) _buildFinish(),
      ],
    );
  }

  /// The wipe itself — two halves of a wood curtain meeting in the middle,
  /// with the question's own plate swelling between them while they are shut.
  /// [w] x [h] is the whole screen. The two halves meet across all of it;
  /// the plate between them is scaled with the stage, so it is the same size
  /// relative to the scene on every device.
  Widget _buildCurtain(double w, double h) {
    final k = math.min(w / _kW, h / _kH);
    return SizedBox(
      width: w,
      height: h,
      child: IgnorePointer(
        child: ClipRect(
          child: _fx((t) {
            // Timeline in seconds, so the plate's reading time is exact.
            final e = (t - _curtainT0).clamp(0.0, _curtainDur);
            final cover = _kf(
              e,
              [0, _kWipeShut, _kPlateGone, _curtainDur],
              [0, 1, 1, 0],
              _curtainCurve,
            );
            final plate = _kf(
              e,
              [_kPlateIn, _kPlateUp, _kPlateUp + _kPlateHold, _kPlateGone],
              [0, 1, 1, 0],
              Curves.easeOut,
            );
            final plateScale = _kf(
              e,
              [
                _kPlateIn,
                _kPlateUp - 0.15,
                _kPlateUp,
                _kPlateUp + _kPlateHold,
                _kPlateGone,
              ],
              [0.7, 1.04, 1, 1, 0.92],
              Curves.easeOut,
            );
            final half = h * 0.502;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: -half * (1 - cover),
                  height: half,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_woodTop, _woodBottom],
                      ),
                      border: Border(
                        bottom: BorderSide(color: _woodEdge, width: 6),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -half * (1 - cover),
                  height: half,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_woodBottom, _woodTop],
                      ),
                      border: Border(
                        top: BorderSide(color: _woodEdge, width: 6),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: _c01(plate),
                      child: Transform.scale(
                        scale: plateScale,
                        // Laid out at stage size, then fitted to this screen.
                        child: SizedBox(
                          width: _kPlateW * k,
                          height: _kPlateW / _kPlateAspect * k,
                          child: FittedBox(child: _curtainPlate()),
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

  /// The plate the curtain announces on: the painted board with its star
  /// crest and lanterns, the session line and the big label set inside its
  /// cream field.
  Widget _plateRule() => Container(
    width: 46,
    height: 3,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(2),
      gradient: const LinearGradient(
        colors: [Color(0x00B8873C), _plateEyebrow],
      ),
    ),
  );

  Widget _curtainPlate() {
    return SizedBox(
      width: _kPlateW,
      height: _kPlateW / _kPlateAspect,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/sirah_story/curtain_plate.png',
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            // The crest sits in the top third and the lanterns at the ends,
            // so the text keeps to the cream field between them.
            padding: const EdgeInsets.fromLTRB(96, 121, 96, 51),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The eyebrow: a real bold (the variable face — the
                  // static Baloo 2 only ships SemiBold, so w700 used to fall
                  // back to it), darker, with a small rule either side.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _plateRule(),
                        const SizedBox(width: 14),
                        Text(
                          'SIRAH STORY  ·  SESSION ${_session.number}',
                          style: const TextStyle(
                            fontFamily: 'Baloo2Var',
                            fontVariations: [FontVariation('wght', 800)],
                            fontSize: 30,
                            letterSpacing: 3.5,
                            color: _plateEyebrow,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 14),
                        _plateRule(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _curtainLabel,
                      style: const TextStyle(
                        fontFamily: 'Baloo2Var',
                        fontVariations: [FontVariation('wght', 800)],
                        fontSize: 68,
                        color: _greenDeep,
                        height: 1.05,
                        shadows: [
                          // A soft lift off the parchment.
                          Shadow(
                            color: Color(0x33FFFFFF),
                            offset: Offset(0, 2),
                          ),
                          Shadow(
                            color: Color(0x40876329),
                            offset: Offset(0, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Rect _rectOf(SirahStoryLayer l) => Rect.fromCenter(
    center: Offset(l.x * _kW, l.y * _kH),
    width: l.w * _kW,
    height: l.h * _kH,
  );

  /// The scene's cut-out layers. While the narration reads, everything sits
  /// plainly in the picture; once it ends the prototype drops the whole scene
  /// to `brightness(0.5)` and leaves the one glowing layer lit on top of it,
  /// which is the page's whole "tap me" cue.
  List<Widget> _buildScene(bool glowOn) {
    final hidden = _showModal || _finished;
    return [
      for (final d in _p.deco)
        Positioned.fromRect(
          rect: _rectOf(d),
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: hidden ? 0 : 1,
              duration: const Duration(milliseconds: 400),
              child: _dimmable(glowOn, Image.asset(d.asset, fit: BoxFit.fill)),
            ),
          ),
        ),
      // The dim goes over the background and its set dressing, under the
      // glowing layer.
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: glowOn ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: const ColoredBox(color: Color(0x73000000)),
          ),
        ),
      ),
      if (_p.celebrate && glowOn) ..._buildCelebration(),
      Positioned.fromRect(
        rect: _rectOf(_p.glow),
        child: AnimatedScale(
          scale: _opening || _showModal ? 1.07 : 1,
          duration: Duration(
            milliseconds: _opening ? (_kOpenQuestion * 1000).round() : 300,
          ),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: hidden ? 0 : 1,
            duration: const Duration(milliseconds: 400),
            child: IgnorePointer(
              ignoring: !glowOn,
              child: GestureDetector(
                key: const ValueKey('sirah-glow'),
                behavior: HitTestBehavior.opaque,
                onTap: _tapGlow,
                child: _p.celebrate ? _risingGlow(glowOn) : _litGlow(glowOn),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// Lit, and then steady — the glow marks the thing to tap, it does not keep
  /// moving while the learner looks at it.
  Widget _litGlow(bool glowOn) {
    final img = Image.asset(_p.glow.asset, fit: BoxFit.fill);
    if (!glowOn) return img;
    return Stack(
      fit: StackFit.expand,
      children: [_glowCopy(img, 22, 0.85), _glowCopy(img, 58, 0.6), img],
    );
  }

  /// The finale's star is not in the sky while the line is read — the line
  /// is *about* it. Once the narration ends a bloom of light opens where it
  /// will be, and the star rises gently up into it: no spin, no overshoot,
  /// one long ease so it arrives rather than pops.
  Widget _risingGlow(bool glowOn) {
    if (!_glowReady) return const SizedBox.expand();
    return _fx((t) {
      final e = t - _glowT0;
      final p = Curves.easeOutCubic.transform(_c01((e - 0.15) / 1.4));
      return Opacity(
        opacity: Curves.easeOut.transform(_c01((e - 0.15) / 0.7)),
        child: Transform.translate(
          offset: Offset(0, 150 * (1 - p)),
          child: Transform.scale(
            scale: 0.62 + 0.38 * p,
            child: _starGlow(glowOn, _starBreath(e)),
          ),
        ),
      );
    });
  }

  /// The star's glow breathing, 0..1, once it has landed: a slow swell and
  /// ease on a 2.4s cycle, faded in so it never starts mid-throb. The star
  /// itself holds still — only its light moves.
  double _starBreath(double e) {
    final on = _c01((e - 1.5) / 0.8);
    final wave = 0.5 - 0.5 * math.cos((e - 1.5) * 2 * math.pi / 2.4);
    return on * Curves.easeInOut.transform(wave);
  }

  /// The star lit far brighter than an ordinary layer: a white-hot core close
  /// in, strong gold around it, then a wide warm haze — each swelling with
  /// the breath [g].
  Widget _starGlow(bool glowOn, [double g = 0]) {
    final img = Image.asset(_p.glow.asset, fit: BoxFit.fill);
    if (!glowOn) return img;
    return Stack(
      fit: StackFit.expand,
      children: [
        _glowCopy(img, 190 + 60 * g, 0.55 + 0.3 * g),
        _glowCopy(img, 100 + 30 * g, 0.9),
        _glowCopy(img, 44 + 12 * g, 1.0),
        _glowCopy(img, 16 + 6 * g, 1.0, color: const Color(0xFFFFFBEA)),
        _glowCopy(img, 6, 0.75 + 0.25 * g, color: const Color(0xFFFFFFFF)),
        img,
      ],
    );
  }

  /// `filter: brightness(0.5)` — the dim a deco layer takes along with the
  /// background while the glow is lit. (The background gets it from the
  /// full-bleed scrim; a deco layer sits above that scrim, so it darkens
  /// itself.)
  Widget _dimmable(bool dim, Widget child) => ColorFiltered(
    colorFilter: ColorFilter.mode(
      dim ? const Color(0x73000000) : const Color(0x00000000),
      BlendMode.srcATop,
    ),
    child: child,
  );

  /// One `drop-shadow(0 0 Npx rgba(255,215,120,a))` pass: the sprite painted
  /// solid gold, blurred, and laid behind itself.
  Widget _glowCopy(
    Widget img,
    double sigma,
    double alpha, {
    Color color = const Color(0xFFFFCD5A),
  }) => ImageFiltered(
    imageFilter: ui.ImageFilter.blur(sigmaX: sigma / 3, sigmaY: sigma / 3),
    child: ColorFiltered(
      colorFilter: ColorFilter.mode(
        color.withValues(alpha: alpha),
        BlendMode.srcATop,
      ),
      child: img,
    ),
  );

  /// Session 4's `sirah-halo` + `sirah-rays`, centred on the star.
  List<Widget> _buildCelebration() {
    final rect = _rectOf(_p.glow);
    final reach = math.max(rect.width, rect.height) / 2;
    return [
      // Rays, last to arrive: they turn up once the star has nearly landed.
      Positioned.fromRect(
        rect: rect.inflate(reach * 3.8),
        child: IgnorePointer(
          child: _afterRise(
            delay: 0.9,
            dur: 0.9,
            child: const CustomPaint(
              painter: _RaysPainter(turn: 0),
              size: Size.infinite,
            ),
          ),
        ),
      ),
      // The bloom: opens first, where the star is about to be.
      Positioned.fromRect(
        rect: rect.inflate(reach * 2.2),
        child: IgnorePointer(
          child: _afterRise(
            delay: 0.0,
            dur: 0.8,
            grow: true,
            breathe: true,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFFFFFDF2),
                    Color(0xD9FFE89A),
                    Color(0x7AFFC24D),
                    Color(0x00FFA92C),
                  ],
                  stops: [0.0, 0.22, 0.48, 0.78],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// Fades [child] in on its own beat after the narration ends — and, for the
  /// bloom, opens it outward from the centre as it comes.
  Widget _afterRise({
    required double delay,
    required double dur,
    bool grow = false,
    bool breathe = false,
    required Widget child,
  }) => _fx((t) {
    final u = Curves.easeOutCubic.transform(_c01((t - _glowT0 - delay) / dur));
    final g = breathe ? _starBreath(t - _glowT0) : 0.0;
    return Opacity(
      opacity: u * (0.82 + 0.18 * g),
      child: grow
          ? Transform.scale(
              scale: (0.35 + 0.65 * u) * (1 + 0.1 * g),
              child: child,
            )
          : child,
    );
  });

  Widget _buildBack() {
    return Positioned(
      left: 44,
      top: 36,
      child: _artButton(
        key: const ValueKey('sirah-back'),
        onTap: _back,
        asset: 'back_btn',
        width: _kBackW,
        aspect: _kBackAspect,
      ),
    );
  }

  /// A button that is a picture: the supplied art at rest, the matching
  /// pressed frame while held. Both frames are cropped to the same box, so
  /// the art itself carries the press — nothing is tinted or scaled on top.
  Widget _artButton({
    Key? key,
    required VoidCallback onTap,
    required String asset,
    required double width,
    required double aspect,
  }) {
    return _Push(
      key: key,
      onTap: onTap,
      dy: 3,
      builder: (down) => Image.asset(
        'assets/images/sirah_story/$asset${down ? '_down' : ''}.png',
        width: width,
        height: width / aspect,
        fit: BoxFit.fill,
        gaplessPlayback: true,
      ),
    );
  }

  Widget _buildReplay() {
    final ready = _glowReady && !_narrating;
    return Positioned(
      right: 44,
      top: 36,
      child: IgnorePointer(
        ignoring: !ready,
        child: AnimatedOpacity(
          opacity: ready ? (_showModal ? 0.45 : 1) : 0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: ready ? 1 : 0.9,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            child: _artButton(
              key: const ValueKey('sirah-replay'),
              onTap: _replayNarration,
              asset: 'replay_btn',
              width: _kReplayW,
              aspect: _kReplayAspect,
            ),
          ),
        ),
      ),
    );
  }

  /// The narration bar — speaker chip, the line, and a progress bar that
  /// fills across the page's authored duration. Passive: it never takes a
  /// tap, so a glow that reaches under it still answers.
  /// The narration bar — the drawn cream panel, its speaker chip, the line
  /// being read, and the progress bar that fills across the page's own
  /// duration. Passive: it never takes a tap, so a glow that reaches under it
  /// still answers.
  Widget _buildNarration() {
    return Positioned(
      left: (_kW - _kNarrationW) / 2,
      bottom: 59,
      width: _kNarrationW,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.fromLTRB(44, 28, 44, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_panelTop, _panelBottom],
            ),
            border: Border.all(color: _panelEdge, width: 6),
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 16),
                blurRadius: 44,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_green, _greenDeep],
                      ),
                      border: Border.all(color: _cream, width: 4),
                      boxShadow: [
                        // A steady halo while the line is being read — the
                        // cue that it is playing, without any pulsing.
                        BoxShadow(
                          color: Color.fromRGBO(
                            61,
                            145,
                            89,
                            _narrating ? 0.28 : 0,
                          ),
                          spreadRadius: 10,
                        ),
                        const BoxShadow(
                          color: Color(0x4D000000),
                          offset: Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.volume_up_rounded,
                      size: 44,
                      color: _cream,
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Text(
                      _p.narration,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: _kBaloo,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                        height: 1.32,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // The track belongs to the line being read: it fills across the
              // page's own duration and then fades off, so a finished panel
              // never sits there looking like it is still playing.
              AnimatedOpacity(
                opacity: _narrating ? 1 : 0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_kBarH / 2),
                  child: SizedBox(
                    height: _kBarH,
                    child: ColoredBox(
                      color: const Color(0x2E7A5F34),
                      child: _fx((t) {
                        final p = _narrating
                            ? _once(t - _narrateT0, _p.narrationMs / 1000)
                            : 1.0;
                        // heightFactor: 1 matters — an Align would hand the
                        // childless fill a loose height and it would lay out
                        // at zero, leaving the track looking empty.
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: p,
                          heightFactor: 1,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_greenMid, _gold],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 21,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _pages.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: i == _page ? 52 : 20,
              height: 20,
              decoration: BoxDecoration(
                color: i == _page ? _gold : const Color(0x73FFF6DA),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // Question card
  // =========================================================================

  Widget _buildModal() {
    return Positioned.fill(
      child: Center(child: _enter(_inCard, 0.10, _modalCard())),
    );
  }

  /// A piece of the card arriving: fade plus a short rise, nothing scaled.
  /// Scaling text forces a glyph re-raster every frame, which is what made
  /// the old entrance look soft and stuttery.
  Widget _enter(Animation<double> a, double rise, Widget child) =>
      FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, rise),
            end: Offset.zero,
          ).animate(a),
          child: child,
        ),
      );

  Widget _modalCard() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        SizedBox(
          width: _kBoardW,
          height: _kBoardW / _kBoardAspect,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/sirah_story/question_board.png',
                  fit: BoxFit.fill,
                ),
              ),
              Padding(
                padding: _kBoardPad,
                // Centred in the field below the medallion, so the space
                // above the question and below the last answer match.
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The chip sits beside the question rather than pushing
                    // it off-centre, so the prompt reads centred on the board.
                    // At least as tall as the chip — a one-line question
                    // made this row shorter than it, and the Stack clipped the
                    // chip's top and bottom into a flat oval.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: _kSpeakerD),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 112,
                            ),
                            child: _enter(
                              _inPrompt,
                              0.35,
                              Text(
                                _p.prompt,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                // The variable face, so this is a real bold —
                                // the static Baloo 2 only ships SemiBold.
                                style: const TextStyle(
                                  fontFamily: 'Baloo2Var',
                                  fontVariations: [FontVariation('wght', 800)],
                                  fontSize: 42,
                                  color: _ink,
                                  height: 1.18,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            child: _enter(
                              _inChip,
                              0.35,
                              Image.asset(
                                'assets/images/sirah_story/speaker.png',
                                width: _kSpeakerD,
                                height: _kSpeakerD,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (final (i, isCorrect)
                        in (_flip ? const [false, true] : const [true, false])
                            .indexed) ...[
                      if (i > 0) const SizedBox(height: 18),
                      _option(isCorrect, i),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_answered) Positioned(top: -44, child: _mumtazBadge()),
      ],
    );
  }

  Widget _option(bool isCorrect, int index) {
    final won = isCorrect && _answered;
    // The tile is the painted pill; the label sits on it and the win state
    // is a gold glow and a tick rather than a repaint of the art.
    final button = _Push(
      onTap: isCorrect ? _pickCorrect : _pickWrong,
      dy: 4,
      builder: (down) => AspectRatio(
        aspectRatio: _kTileAspect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(90),
            boxShadow: won
                ? const [
                    BoxShadow(
                      color: Color(0x99FFD75E),
                      spreadRadius: 6,
                      blurRadius: 22,
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/sirah_story/choice_tile.png',
                  fit: BoxFit.fill,
                  color: down ? const Color(0xFFE8D9AE) : null,
                  colorBlendMode: down ? BlendMode.modulate : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 90),
                child: Text(
                  isCorrect ? _p.correct : _p.decoy,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: 'Baloo2Var',
                    fontVariations: const [FontVariation('wght', 800)],
                    fontSize: 40,
                    color: won ? _green : _ink,
                    height: 1.15,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (won)
                Positioned(
                  right: 26,
                  child: Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x40000000),
                          offset: Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // The clock only drives this tile while it is actually shaking — the
    // rest of the time it is a plain, still widget.
    final settled = !isCorrect && _shake
        ? _fx(
            (t) => Transform.translate(
              offset: Offset(
                -12 * math.sin(_once(t - _shakeT0, _kShake) * math.pi * 3),
                0,
              ),
              child: button,
            ),
          )
        : button;

    return _enter(
      index == 0 ? _inAnswerA : _inAnswerB,
      0.35,
      AnimatedScale(
        scale: won ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: settled,
      ),
    );
  }

  Widget _mumtazBadge() {
    return _fx((t) {
      final p = _badgeOut.transform(_once(t - _badgeT0, _kBadgePop));
      return Opacity(
        opacity: _c01(p * 2),
        child: Transform.rotate(
          angle: (-10 + 8 * p) * math.pi / 180,
          child: Transform.scale(
            scale: 0.4 + 0.6 * p,
            child: Image.asset(
              'assets/images/sirah_story/mumtaz_ribbon.png',
              width: _kBadgeW,
              height: _kBadgeW / _kRibbonArtAspect,
              fit: BoxFit.fill,
            ),
          ),
        ),
      );
    });
  }

  /// 26 pieces falling past the whole frame, as in the prototype.
  Widget _buildConfetti(double t0) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: _fx((t) {
            final e = t - t0;
            return Stack(
              children: [for (var i = 0; i < 26; i++) _confettiPiece(i, e)],
            );
          }),
        ),
      ),
    );
  }

  Widget _confettiPiece(int i, double e) {
    final dur = 1.4 + (i % 5) * 0.25;
    final delay = (i % 7) * 0.12;
    final p = _loop(math.max(0.0, e - delay), dur);
    if (e < delay) return const SizedBox.shrink();
    final round = i % 4 == 0;
    final small = i % 3 == 0;
    return Positioned(
      left: (i * 37) % 100 / 100 * _kW,
      top: -0.06 * _kH + p * (_kH + 0.46 * _kH),
      child: Opacity(
        opacity: p < 0.15 ? p / 0.15 : (p > 0.9 ? (1 - p) / 0.1 : 1),
        child: Transform.rotate(
          angle: p * 3 * math.pi,
          child: Container(
            width: small ? 18 : 24,
            height: small ? 18 : 14,
            decoration: BoxDecoration(
              color: _confettiColors[i % _confettiColors.length],
              borderRadius: BorderRadius.circular(round ? 12 : 4),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Leave-the-story confirm and Session Complete
  // =========================================================================

  Widget _buildConfirmExit() {
    return Positioned.fill(
      child: ColoredBox(
        color: _scrimDeep,
        child: Center(
          child: Container(
            width: 1010,
            padding: const EdgeInsets.fromLTRB(60, 60, 60, 48),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_panelTop, _panelBottom],
              ),
              border: Border.all(color: _panelEdge, width: 10),
              borderRadius: BorderRadius.circular(48),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x73000000),
                  offset: Offset(0, 36),
                  blurRadius: 80,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Leave the story? You will go back to the start screen.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _kBaloo,
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 44),
                Row(
                  children: [
                    Expanded(
                      child: _chunkyButton(
                        label: 'Keep Reading',
                        onTap: () => setState(() => _confirmExit = false),
                        top: _optionTop,
                        bottom: _optionBottom,
                        edge: _panelEdge,
                        shade: _optionShade,
                        ink: _inkSoft,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: _chunkyButton(
                        label: 'Go to Start',
                        onTap: _backToStart,
                        top: _green,
                        bottom: _greenDeep,
                        edge: _greenDeep,
                        shade: _greenBtnShade,
                        ink: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The ending, laid out to the supplied reference — but staged on the
  /// scene that was just played rather than on the title screen's square, so
  /// the session finishes where it ended instead of cutting somewhere else.
  /// The play stack's own backdrop is still underneath and still drifting;
  /// this only lays a warm veil over it and brings the award art in.
  /// The ending, laid out to the supplied reference — but staged on the
  /// scene that was just played rather than on the title screen's square, so
  /// the session finishes where it ended instead of cutting somewhere else.
  /// The play stack's own backdrop is still underneath; this lays a warm veil
  /// over it and brings the award art in, one piece at a time.
  Widget _buildFinish() {
    const asset = 'assets/images/sirah_story';
    const plaqueH = _kEndPlaqueW / _kEndPlaqueAspect;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _inVeil,
              child: const ColoredBox(color: _endVeil),
            ),
          ),
          // The burst behind the plaque's medallion.
          Positioned(
            left: 0,
            right: 0,
            top: -plaqueH * 0.35,
            height: plaqueH * 1.3,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _endFlash,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0xCCFFF6D6),
                        Color(0x66FFD75E),
                        Color(0x00FFA92C),
                      ],
                      stops: [0.0, 0.35, 0.72],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0.235 * _kW - _kEndKidW / 2,
            bottom: 0.01 * _kH,
            child: _enterArt(
              _inBoy,
              rise: 0.30,
              from: 0.92,
              child: Image.asset(
                '$asset/end_boy.png',
                width: _kEndKidW,
                height: _kEndKidW / _kEndBoyAspect,
                fit: BoxFit.fill,
              ),
            ),
          ),
          Positioned(
            left: 0.765 * _kW - _kEndKidW / 2,
            bottom: 0.01 * _kH,
            child: _enterArt(
              _inGirl,
              rise: 0.30,
              from: 0.92,
              child: Image.asset(
                '$asset/end_girl.png',
                width: _kEndKidW,
                height: _kEndKidW / _kEndGirlAspect,
                fit: BoxFit.fill,
              ),
            ),
          ),
          Positioned(
            left: (_kW - _kEndPlaqueW) / 2,
            top: 0,
            child: _enterArt(
              _inPlaque,
              rise: -0.35,
              from: 1.1,
              child: Image.asset(
                '$asset/end_plaque.png',
                width: _kEndPlaqueW,
                height: plaqueH,
                fit: BoxFit.fill,
              ),
            ),
          ),
          Positioned(
            left: (_kW - _kEndPanelW) / 2,
            top: 0.555 * _kH,
            child: _enterArt(
              _inPanel,
              rise: 0.28,
              from: 0.96,
              child: SizedBox(
                width: _kEndPanelW,
                height: _kEndPanelW / _kEndPanelAspect,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        '$asset/end_panel_blank.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                    // Inside the ornamented frame: clear of the corner
                    // flowers and the side diamonds.
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        _kEndPanelW * 0.14,
                        _kEndPanelW / _kEndPanelAspect * 0.2,
                        _kEndPanelW * 0.14,
                        _kEndPanelW / _kEndPanelAspect * 0.18,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Congratulations!',
                              style: _endStyle(40, 800, _greenDeep),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You completed the whole lesson!',
                              style: _endStyle(28, 700, _ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Keep learning and doing good.',
                              style: _endStyle(24, 600, _plateEyebrow),
                            ),
                          ],
                        ),
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
            top: 0.80 * _kH,
            child: Center(
              child: _enterArt(
                _inContinue,
                rise: 0.45,
                from: 0.90,
                child: _fx((t) {
                  final e = t - _finishT0;
                  final breathe = e > 1.9
                      ? 0.02 * math.sin((e - 1.9) * 3.0)
                      : 0.0;
                  return Transform.scale(
                    scale: 1 + breathe,
                    child: _Push(
                      key: const ValueKey('sirah-continue'),
                      onTap: _finish,
                      dy: 6,
                      builder: (down) => Image.asset(
                        down ? '$asset/end_btn_down.png' : '$asset/end_btn.png',
                        width: _kEndBtnW,
                        height: _kEndBtnW / _kEndBtnAspect,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          _buildConfetti(_finishT0),
        ],
      ),
    );
  }

  TextStyle _endStyle(double size, double weight, Color color) => TextStyle(
    fontFamily: 'Baloo2Var',
    fontVariations: [FontVariation('wght', weight)],
    fontSize: size,
    color: color,
    height: 1.15,
  );

  /// Like [_enter], with a scale as well — these pieces are pictures, so
  /// scaling them costs nothing and gives each one a little travel.
  Widget _enterArt(
    Animation<double> a, {
    required double rise,
    required double from,
    required Widget child,
  }) => FadeTransition(
    opacity: a,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, rise),
        end: Offset.zero,
      ).animate(a),
      child: ScaleTransition(
        scale: Tween<double>(begin: from, end: 1.0).animate(a),
        child: child,
      ),
    ),
  );

  // -------------------------------------------------------------------------
  // Shared chrome
  // -------------------------------------------------------------------------

  Widget _chunkyButton({
    required String label,
    required VoidCallback onTap,
    required Color top,
    required Color bottom,
    required Color edge,
    required Color shade,
    required Color ink,
  }) {
    return _Push(
      onTap: onTap,
      dy: 5,
      builder: (down) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
          border: Border.all(color: edge, width: 6),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: shade, offset: Offset(0, down ? 4 : 9))],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: _kBaloo,
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: ink,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

/// The start screen's sky: a few soft clouds drifting across and a handful
/// of birds gliding through on slow arcs. Painted, not asset-based, so it
/// sits over any backdrop and costs a few paths a frame.
class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.t);

  /// Seconds since the screen appeared.
  final double t;

  // (y, width, px/s, start offset) — mismatched speeds so they never line up.
  // Kept high: below this the corners are palms and awnings.
  static const _clouds = [
    (46.0, 230.0, 14.0, 0.0),
    (92.0, 170.0, 22.0, 700.0),
    (24.0, 150.0, 18.0, 1300.0),
    (70.0, 200.0, 11.0, 400.0),
  ];

  // (y, px/s, start offset, flap period, size)
  static const _birds = [
    (95.0, 58.0, 0.0, 0.62, 38.0),
    (122.0, 52.0, 70.0, 0.55, 31.0),
    (78.0, 64.0, -64.0, 0.70, 26.0),
  ];

  /// The backdrop's corners are palms and market awnings reaching up into the
  /// sky. Anything drawn over them would sit *in front* of them, so the sky's
  /// moving pieces fade out before they get there and live only over the
  /// open sky in the middle.
  static double _open(double x, double width) {
    const edge = 330.0;
    const ramp = 170.0;
    return _c01((x - edge) / ramp) * _c01((width - edge - x) / ramp);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final (y, w, speed, offset) in _clouds) {
      final span = size.width + w * 2;
      final x = (offset + t * speed) % span - w;
      final a = _open(x + w / 2, size.width);
      if (a <= 0.01) continue;
      final cloud = Paint()
        ..color = Color.fromRGBO(255, 255, 255, 0.78 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      // A cloud is a few overlapping puffs on a flat base.
      final h = w * 0.34;
      canvas.drawOval(Rect.fromLTWH(x, y + h * 0.35, w, h * 0.65), cloud);
      canvas.drawCircle(Offset(x + w * 0.32, y + h * 0.42), h * 0.42, cloud);
      canvas.drawCircle(Offset(x + w * 0.56, y + h * 0.30), h * 0.52, cloud);
      canvas.drawCircle(Offset(x + w * 0.76, y + h * 0.48), h * 0.36, cloud);
    }

    // The flock crosses together, then the sky is clear for a while.
    const cycle = 34.0;
    final phase = t % cycle;
    for (final (y, speed, offset, flap, sz) in _birds) {
      final x = -80 + offset + phase * speed;
      final a = _open(x, size.width);
      if (a <= 0.01) continue;
      final lift = math.sin(t * 2 * math.pi / flap);
      final by = y + 8 * math.sin(phase * 0.6 + offset);
      _paintBird(canvas, Offset(x, by), sz, lift, a);
    }
  }

  /// A small cartoon bird in profile, flying right: body, head with an eye and
  /// beak, a forked tail, and two wings hinged at the shoulder. [lift] (-1..1)
  /// is the wingbeat — the near wing sweeps from raised to lowered and the far
  /// wing follows a touch behind, so the flap reads as flight, not a wobble.
  static void _paintBird(
    Canvas canvas,
    Offset at,
    double sz,
    double lift,
    double a,
  ) {
    final body = Paint()..color = Color.fromRGBO(74, 52, 30, a);
    final shade = Paint()..color = Color.fromRGBO(52, 36, 20, a);
    final belly = Paint()..color = Color.fromRGBO(214, 176, 124, a);
    final beak = Paint()..color = Color.fromRGBO(232, 163, 60, a);
    final eye = Paint()..color = Color.fromRGBO(255, 248, 230, a);

    canvas.save();
    canvas.translate(at.dx, at.dy);
    // A slight nose-up tilt on the downstroke, as the bird climbs.
    canvas.rotate(-0.08 * lift);

    Path wing() => Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-sz * 0.18, -sz * 0.62, -sz * 0.62, -sz * 0.74)
      ..quadraticBezierTo(-sz * 0.46, -sz * 0.38, -sz * 0.52, -sz * 0.12)
      ..quadraticBezierTo(-sz * 0.2, -sz * 0.02, sz * 0.16, sz * 0.02)
      ..close();
    final shoulder = Offset(sz * 0.06, -sz * 0.08);

    // Far wing first, so the body covers its root.
    canvas.save();
    canvas.translate(shoulder.dx + sz * 0.06, shoulder.dy - sz * 0.02);
    canvas.rotate(_wingAngle(lift * 0.9) - 0.12);
    canvas.drawPath(wing(), shade);
    canvas.restore();

    // Tail: a short fork trailing behind.
    canvas.drawPath(
      Path()
        ..moveTo(-sz * 0.36, -sz * 0.06)
        ..lineTo(-sz * 0.78, -sz * 0.24)
        ..lineTo(-sz * 0.64, sz * 0.0)
        ..lineTo(-sz * 0.78, sz * 0.18)
        ..lineTo(-sz * 0.36, sz * 0.08)
        ..close(),
      body,
    );

    // Body and a paler belly.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: sz * 0.98, height: sz * 0.44),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(sz * 0.08, sz * 0.08),
        width: sz * 0.62,
        height: sz * 0.22,
      ),
      belly,
    );

    // Head, beak, eye.
    final head = Offset(sz * 0.46, -sz * 0.12);
    canvas.drawCircle(head, sz * 0.2, body);
    canvas.drawPath(
      Path()
        ..moveTo(head.dx + sz * 0.16, head.dy - sz * 0.05)
        ..lineTo(head.dx + sz * 0.38, head.dy + sz * 0.01)
        ..lineTo(head.dx + sz * 0.16, head.dy + sz * 0.07)
        ..close(),
      beak,
    );
    canvas.drawCircle(
      Offset(head.dx + sz * 0.07, head.dy - sz * 0.04),
      math.max(1.6, sz * 0.055),
      eye,
    );

    // Near wing last, over the body.
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(_wingAngle(lift));
    canvas.drawPath(wing(), body);
    canvas.restore();

    canvas.restore();
  }

  /// The wing is drawn tip-up and swept back; this hinges it from that raised
  /// pose (lift = 1) down past the body to a lowered one behind it (lift = -1).
  static double _wingAngle(double lift) => -0.55 + 0.85 * lift;

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t;
}

/// Star glints twinkling around the title scroll once it has landed — each on
/// its own phase, so they wink in turn rather than all at once.
class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.t);

  final double t;

  // (x, y as fractions of the painted box, size, phase)
  static const _stars = [
    (0.06, 0.26, 26.0, 0.0),
    (0.95, 0.22, 30.0, 0.35),
    (0.04, 0.50, 20.0, 0.6),
    (0.97, 0.46, 22.0, 0.15),
    (0.24, 0.06, 18.0, 0.8),
    (0.78, 0.08, 20.0, 0.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t < 1.4) return; // wait for the scroll to settle
    final fade = _c01((t - 1.4) / 0.6);
    const period = 2.4;
    for (final (fx, fy, sz, ph) in _stars) {
      final k = _loop(t / period + ph, 1.0);
      // A quick swell and a slower fade, then rest.
      final a = k < 0.5 ? math.sin(k / 0.5 * math.pi) : 0.0;
      if (a <= 0.01) continue;
      final c = Offset(fx * size.width, fy * size.height);
      final r = sz * (0.5 + 0.5 * a);
      final glow = Paint()
        ..color = Color.fromRGBO(255, 236, 170, 0.45 * a * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(c, r * 0.7, glow);
      final star = Paint()..color = Color.fromRGBO(255, 250, 225, a * fade);
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, star);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}

/// The Session 4 finale's `repeating-conic-gradient` rays, turning behind the
/// glow. Each wedge is painted with a radial shader so it fades in from the
/// centre and out at the edge, which is what the prototype's mask does.
class _RaysPainter extends CustomPainter {
  const _RaysPainter({required this.turn});

  /// 0..1 — one full revolution.
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final reach = math.max(size.width, size.height);
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x00FFECAA), Color(0xA6FFECAA), Color(0x00FFECAA)],
        stops: [0.16, 0.34, 0.62],
      ).createShader(rect);

    canvas.save();
    // The shader was built in painter space, so undo the centring shift for
    // it by translating the canvas rather than the gradient.
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(turn * 2 * math.pi);
    canvas.translate(-centre.dx, -centre.dy);
    const rays = 24;
    const half = math.pi / rays * 0.2;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(
          centre.dx + math.cos(a - half) * reach,
          centre.dy + math.sin(a - half) * reach,
        )
        ..lineTo(
          centre.dx + math.cos(a + half) * reach,
          centre.dy + math.sin(a + half) * reach,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.turn != turn;
}

/// A button that sinks while held, like the prototype's `:active` rule — the
/// hard drop-shadow shrinks with it, which is what sells the press.
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
