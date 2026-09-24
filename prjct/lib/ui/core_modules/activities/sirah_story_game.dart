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

  // Live start-screen backdrop; null until loaded (static art meanwhile).
  // The second shader instance renders the open-sky mask the birds fly in.
  ui.FragmentShader? _bgShader;
  ui.FragmentShader? _skyShader;
  List<ui.Image>? _bgLayers;

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
    _loadLiveBg();
  }

  Future<void> _loadLiveBg() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/sirah_start_bg.frag',
      );
      final images = await Future.wait([
        for (final l in ['clean', 'palms', 'field', 'aux', 'clouds', 'lamp'])
          _decodeAsset('assets/images/sirah_story/start_bg_$l.png'),
      ]);
      if (!mounted) {
        for (final i in images) {
          i.dispose();
        }
        return;
      }
      setState(() {
        _bgShader = program.fragmentShader();
        _skyShader = program.fragmentShader();
        _bgLayers = images;
      });
    } catch (_) {
      // Shaders unsupported here: the static art stays.
    }
  }

  static Future<ui.Image> _decodeAsset(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  @override
  void dispose() {
    _bgShader?.dispose();
    _skyShader?.dispose();
    for (final i in _bgLayers ?? const <ui.Image>[]) {
      i.dispose();
    }
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
          // ...and darkens them exactly as the stage darkens its own scene,
          // so a dim or a scrim reaches the screen edge instead of stopping
          // at the stage's. The stage paints over these, so its own area is
          // never darkened twice.
          if (_screen == _Screen.play) ..._bandOverlays(),
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

  /// The full-bleed layers the play screen lays over its scene, repeated at
  /// screen size for the letterbox bands. Same colours, same timings.
  List<Widget> _bandOverlays() => [
    // The dim once the narration ends.
    AnimatedOpacity(
      opacity: _glowOn ? 1 : 0,
      duration: const Duration(milliseconds: 600),
      child: const ColoredBox(color: Color(0x73000000)),
    ),
    // The question card's darkness.
    AnimatedOpacity(
      opacity: _dark ? 1 : 0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: const ColoredBox(color: _scrim),
    ),
    if (_confirmExit) const ColoredBox(color: _scrimDeep),
    if (_finished)
      FadeTransition(
        opacity: _inVeil,
        child: const ColoredBox(color: _endVeil),
      ),
  ];

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
        // The square in the wind: palms and plants sway, clouds drift behind
        // them, birds cross the open sky and sand blows over the paving.
        Positioned.fill(
          child: IgnorePointer(
            child: _fx((t) {
              final gust = _gust(t);
              final shader = _bgShader;
              final sky = _skyShader;
              final layers = _bgLayers;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (shader != null && sky != null && layers != null) ...[
                    CustomPaint(
                      painter: _LiveBgPainter(shader, layers, t, gust, 0),
                    ),
                    CustomPaint(
                      painter: _SkyPainter(
                        t - _screenT0,
                        mask: _LiveBgPainter.configure(
                          sky,
                          layers,
                          const Size(_kW, _kH),
                          t,
                          gust,
                          1,
                        ),
                      ),
                    ),
                  ] else ...[
                    Image.asset(
                      'assets/images/sirah_story/start_bg.png',
                      fit: BoxFit.cover,
                    ),
                    CustomPaint(painter: _SkyPainter(t - _screenT0)),
                  ],
                  CustomPaint(painter: _SandPainter(t)),
                ],
              );
            }),
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
    final glowOn = _glowOn;
    // The question's own darkness. It starts filling the moment the glowing
    // layer is tapped and is already all the way in by the time the card
    // pops, so the two read as one move.
    final dark = _dark;
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

  /// The scene is dimmed and its layer lit — narration done, nothing over it.
  bool get _glowOn => _glowReady && !_showModal && !_finished;

  /// The question's darkness: from the tap until the card closes.
  bool get _dark => _opening || _showModal;

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

/// The wind over the square, 0.24–1: a slow swell with a quicker gust on
/// top. The palms (via the shader), the birds' mask and the sand all read it,
/// so everything moves with the same weather.
double _gust(double t) =>
    0.62 + 0.25 * math.sin(0.23 * t) + 0.13 * math.sin(0.61 * t + 1.7);

/// How far the wind has blown by [t] — the integral of [_gust]. Anything the
/// wind carries travels by this, so it speeds up and slows with the gusts
/// instead of jumping when they change.
double _windRun(double t) =>
    0.62 * t -
    0.25 / 0.23 * math.cos(0.23 * t) -
    0.13 / 0.61 * math.cos(0.61 * t + 1.7);

/// The start screen's backdrop, drawn by `shaders/sirah_start_bg.frag` from
/// the layers in [layers] (clean, palms, field, aux, clouds). [mode] 1 draws
/// only the open-sky coverage instead, as the birds' mask.
class _LiveBgPainter extends CustomPainter {
  _LiveBgPainter(this.shader, this.layers, this.t, this.gust, this.mode);

  final ui.FragmentShader shader;
  final List<ui.Image> layers;
  final double t;
  final double gust;
  final double mode;

  static ui.FragmentShader configure(
    ui.FragmentShader shader,
    List<ui.Image> layers,
    Size size,
    double t,
    double gust,
    double mode,
  ) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, t)
      ..setFloat(3, gust)
      ..setFloat(4, mode);
    for (var i = 0; i < layers.length; i++) {
      shader.setImageSampler(i, layers[i]);
    }
    return shader;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = configure(shader, layers, size, t, gust, mode),
    );
  }

  @override
  bool shouldRepaint(_LiveBgPainter old) => old.t != t;
}

/// The start screen's birds: a loose skein crossing with the wind and, now
/// and then, a lone far bird beating back against it. Each flies the way real
/// birds do — bursts of wingbeats that lift it, then a glide on held wings
/// that lets it sink — with the wingtips lagging the arm on every stroke.
/// [mask] (the backdrop shader's sky mode) hides them behind palms and
/// awnings as those sway.
class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.t, {this.mask});

  /// Seconds since the screen appeared.
  final double t;
  final Shader? mask;

  // (x behind the leader, y, size, wingbeats/s, seed)
  static const _skein = [
    (0.0, 104.0, 34.0, 3.1, 0.0),
    (-58.0, 86.0, 29.0, 3.4, 1.3),
    (-66.0, 128.0, 30.0, 3.3, 2.6),
    (-120.0, 72.0, 25.0, 3.7, 3.9),
    (-128.0, 148.0, 24.0, 3.8, 5.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final birds = <(Offset, double, double, double, bool)>[];

    // The skein crosses, then the sky is clear for a while.
    const cycle = 36.0;
    final lead = -100 + (t % cycle) * 62;
    for (final (dx, y, sz, hz, seed) in _skein) {
      final x = lead + dx + 6 * math.sin(t * 0.3 + seed);
      if (x < -60 || x > size.width + 60) continue;
      final at = Offset(x, y + 4 * math.sin(t * 0.37 + seed * 2));
      birds.add((at, sz, hz, seed, false));
    }
    // A far bird heading the other way, slower against the wind.
    const lone = 58.0;
    final lx = size.width + 60 - ((t + 20) % lone) * 36;
    if (lx > -60 && lx < size.width + 60) {
      birds.add((Offset(lx, 168), 15.0, 4.4, 7.7, true));
    }
    if (birds.isEmpty) return;

    final bounds = Offset.zero & size;
    final m = mask;
    if (m != null) canvas.saveLayer(bounds, Paint());
    for (final (at, sz, hz, seed, left) in birds) {
      // Flapping comes in bursts; between them the bird glides.
      final cruise = math.sin(t * 0.45 + seed * 1.7);
      final flap = _c01((cruise + 0.2) / 0.6);
      final beat = t * hz * 2 * math.pi + seed * 5;
      final lift = 0.15 * (1 - flap) + math.sin(beat) * flap;
      // It climbs while flapping and sinks on the glide; the body rises a
      // touch on every downstroke.
      final y =
          at.dy +
          10 * math.cos(t * 0.45 + seed * 1.7) +
          sz * 0.07 * math.cos(beat) * flap;
      final pitch = -0.1 * cruise - 0.06 * lift;
      final hand = 0.45 * math.sin(beat - 1.1) * flap - 0.1 * (1 - flap);
      canvas.save();
      canvas.translate(at.dx, y);
      if (left) canvas.scale(-1, 1);
      _paintBird(canvas, sz, lift, hand, pitch);
      canvas.restore();
    }
    if (m != null) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = m
          ..blendMode = BlendMode.dstIn,
      );
      canvas.restore();
    }
  }

  /// A rock dove flying right, seen side-on and a little from below: a
  /// tapered grey body shading pale underneath, a dark-banded fan tail, a
  /// green sheen on the neck, and long wings with fingered primaries.
  ///
  /// Wings beat towards and away from the viewer, so they are drawn at full
  /// span and then foreshortened by the sine of their elevation — tall when
  /// raised or lowered, a sliver as they pass level — which is what reads as
  /// real flight rather than a paddle rotating in the picture plane. [lift]
  /// (-1..1) is the stroke; [hand] (about -0.5..0.5) spreads the primaries on
  /// the downstroke and tucks them on the way up.
  static void _paintBird(
    Canvas canvas,
    double sz,
    double lift,
    double hand,
    double pitch,
  ) {
    canvas.rotate(pitch);
    canvas.scale(sz);

    final elev = 0.25 + 0.95 * lift;
    const tilt = 0.35;
    final spread = _c01(0.5 + hand * 1.1);
    final reach = 0.8 + 0.2 * spread;

    // Far wing first: its upper side, darker, behind the body.
    _paintWing(
      canvas,
      const Offset(0.1, -0.12),
      math.sin(elev - tilt) * 0.9 * reach,
      spread,
      const Color(0xFF5F5A54),
      const Color(0xFF34302C),
    );

    // Tail: a short fan with the dark terminal band.
    canvas.drawPath(
      Path()
        ..moveTo(-0.36, -0.07)
        ..lineTo(-0.78, -0.11)
        ..quadraticBezierTo(-0.87, 0, -0.78, 0.1)
        ..lineTo(-0.36, 0.06)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF7D776F), Color(0xFF6A645D), Color(0xFF2E2B28)],
          stops: [0, 0.7, 0.9],
        ).createShader(const Rect.fromLTRB(-0.36, -0.12, -0.87, 0.1)),
    );

    // Body: deep breast, flat back, tapering into the tail; a round head.
    final plumage = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5E5953), Color(0xFF8B857C), Color(0xFFCBC3B6)],
        stops: [0, 0.45, 1],
      ).createShader(const Rect.fromLTRB(-0.42, -0.22, 0.54, 0.18));
    canvas.drawPath(
      Path()
        ..moveTo(0.36, -0.17)
        ..quadraticBezierTo(0, -0.22, -0.3, -0.1)
        ..lineTo(-0.42, -0.04)
        ..lineTo(-0.42, 0.05)
        ..quadraticBezierTo(-0.1, 0.18, 0.25, 0.12)
        ..quadraticBezierTo(0.4, 0.07, 0.44, -0.02)
        ..close(),
      plumage,
    );
    canvas.drawCircle(const Offset(0.42, -0.1), 0.12, plumage);
    // Iridescent neck.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0.34, -0.06),
        width: 0.2,
        height: 0.16,
      ),
      Paint()..color = const Color(0x4D4E8A6E),
    );
    // Beak and eye.
    canvas.drawPath(
      Path()
        ..moveTo(0.52, -0.12)
        ..lineTo(0.63, -0.08)
        ..lineTo(0.52, -0.05)
        ..close(),
      Paint()..color = const Color(0xFF3A3632),
    );
    canvas.drawCircle(
      const Offset(0.46, -0.13),
      0.03,
      Paint()..color = const Color(0xFF1C1A18),
    );

    // Near wing last: pale underside when raised, as seen from below.
    _paintWing(
      canvas,
      const Offset(0.04, -0.1),
      math.sin(elev + tilt) * reach,
      spread,
      const Color(0xFFBDB5A9),
      const Color(0xFF3C3833),
    );
  }

  /// One wing at full span pointing up from [root], then squashed to
  /// [project] of its height (negative flips it below the body). Coverts in
  /// [base], shading to [tip] across the primaries; the primaries' fingers
  /// open with [spread].
  static void _paintWing(
    Canvas canvas,
    Offset root,
    double project,
    double spread,
    Color base,
    Color tip,
  ) {
    canvas.save();
    canvas.translate(root.dx, root.dy);
    canvas.scale(1, project);

    final wingTip = Offset(
      -0.45 - 0.1 * (1 - spread),
      -1.15 + 0.12 * (1 - spread),
    );
    const rear = Offset(-0.5, -0.55);
    final path = Path()
      ..moveTo(0.1, 0)
      ..quadraticBezierTo(0.14, -0.3, 0.02, -0.5)
      ..quadraticBezierTo(-0.08, -0.85, wingTip.dx, wingTip.dy);
    // Fingered primaries along the back of the hand.
    const fingers = 6;
    final depth = 0.02 + 0.07 * spread;
    for (var i = 1; i <= fingers; i++) {
      final prev = Offset.lerp(wingTip, rear, (i - 1) / fingers)!;
      final next = Offset.lerp(wingTip, rear, i / fingers)!;
      final mid = Offset.lerp(prev, next, 0.5)!;
      path.lineTo(mid.dx + depth * 0.9, mid.dy + depth * 0.5);
      path.lineTo(next.dx, next.dy);
    }
    // Secondaries back to the body.
    path
      ..quadraticBezierTo(-0.52, -0.3, -0.4, -0.1)
      ..quadraticBezierTo(-0.32, 0, -0.2, 0.02)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [base, base, tip],
          stops: const [0, 0.5, 0.95],
        ).createShader(const Rect.fromLTRB(-0.6, -1.15, 0.16, 0.02)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t;
}

/// Sand lifted off the square by the wind: grains hopping low over the
/// paving (each hop's length tied to how far the wind carries it), fine dust
/// hanging higher up, and thin sheets of sand skimming the ground in the
/// gusts. Smaller and fainter towards the far side of the square.
class _SandPainter extends CustomPainter {
  const _SandPainter(this.t);

  final double t;

  static const _light = Color(0xFFF6E2B6);
  static const _dark = Color(0xFFD9B27A);

  /// A fixed pseudo-random 0..1 per particle and property.
  static double _h(int i, int k) {
    final v = math.sin(i * 127.1 + k * 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// 0 at the far edge of the paving, 1 at the front of the frame.
  static double _depth(double y) => _c01((y - 555) / 286);

  @override
  void paint(Canvas canvas, Size size) {
    final run = _windRun(t);
    final gust = _gust(t);
    final span = size.width + 120;

    // Sheets of sand skimming the paving, only in the stronger gusts.
    final sheet = 0.2 * _c01(gust * 1.6 - 0.55);
    if (sheet > 0.01) {
      for (var i = 0; i < 7; i++) {
        final y = 590 + _h(i, 1) * 230;
        final k = 0.3 + 0.7 * _depth(y);
        final len = (140 + 200 * _h(i, 2)) * k;
        final loop = span + len;
        final x =
            (_h(i, 4) * loop + run * (150 + 60 * _h(i, 3)) * k) % loop - len;
        final path = Path();
        for (var s = 0; s <= 12; s++) {
          final f = s / 12;
          final px = x + len * f;
          final py =
              y -
              3 * k * math.sin(px * 0.025 - t * 3 + i) -
              8 * k * f * (1 - f);
          s == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (2 + 3 * _h(i, 5)) * k
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * k)
            ..shader = LinearGradient(
              colors: [
                _light.withValues(alpha: 0),
                _light.withValues(alpha: sheet),
                _light.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromLTWH(x, y - 12, len, 24)),
        );
      }
    }

    final dot = Paint();

    // Fine dust hanging in the air, drifting slowly downwind.
    for (var i = 0; i < 40; i++) {
      final y0 = 420 + _h(i, 11) * 380;
      final k = 0.4 + 0.6 * _depth(y0);
      final d = _h(i, 12) * span + run * (28 + 30 * _h(i, 13)) * k;
      final x = d % span - 60 + 10 * math.sin(t * 0.9 + i);
      final y =
          y0 + 9 * math.sin(t * 0.6 + i * 1.7) + 4 * math.sin(t * 1.9 + i);
      final a =
          (0.1 + 0.18 * _h(i, 14)) *
          (0.55 + 0.45 * math.sin(t * 0.8 + i * 2.3));
      dot.color = _light.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), (0.8 + 1.4 * _h(i, 15)) * k, dot);
    }

    // Grains hopping along the paving; they're only aloft while the wind
    // is strong enough to lift them.
    for (var i = 0; i < 120; i++) {
      final y0 = 565 + math.pow(_h(i, 1), 0.8).toDouble() * 270;
      final k = 0.25 + 0.75 * _depth(y0);
      final d = _h(i, 3) * span + run * (70 + 110 * _h(i, 2)) * k;
      final x = d % span - 60;
      final hopLen = (26 + 50 * _h(i, 4)) * k;
      final u = (d / hopLen) % 1.0;
      final hop =
          4 * u * (1 - u) * (5 + 14 * _h(i, 5)) * k * (0.5 + 0.5 * gust);
      final aloft = _c01((gust - 0.35 - 0.4 * _h(i, 6)) * 4);
      final a = (0.35 + 0.45 * _h(i, 7)) * aloft * (0.4 + 0.6 * k);
      if (a < 0.02) continue;
      dot.color = (i.isEven ? _light : _dark).withValues(alpha: a);
      canvas.drawCircle(
        Offset(x, y0 - hop),
        (0.9 + 1.3 * _h(i, 8)) * (0.5 + 0.8 * k),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_SandPainter old) => old.t != t;
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
