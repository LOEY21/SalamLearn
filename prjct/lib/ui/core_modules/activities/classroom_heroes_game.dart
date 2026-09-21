import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// Classroom Heroes — pick the hero choice in three classroom scenarios.
/// Ported 1:1 from the supplied "Classroom Heroes" design prototype: same
/// title screen, curtain wipe, narration bar, Classroom Hero Meter, choice
/// cards, MUMTAZ! burst, Try again card and hero badge, with the same
/// artwork, copy and motion.
///
/// The prototype was authored against a fixed 1600x900 landscape stage that
/// it scales to fit the viewport, so the whole game is built inside that
/// same virtual frame (see [build]) and the screen is locked to landscape
/// while it is on — the app is portrait everywhere else.
///
/// One [ClassroomHeroesSession] per session, distributed one per stage
/// (Destinations 4-7). The title screen is identical for every session, so a
/// learner meets the same opening whichever one they are on.
class ClassroomHeroesGame extends StatefulWidget {
  const ClassroomHeroesGame({
    super.key,
    required this.session,
    required this.xp,
    required this.onComplete,
    this.onExit,
  });

  final ClassroomHeroesSession session;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Leaves the lesson — wired to the title screen's ✕ and the badge
  /// screen's home button, the two places the prototype's layout has room
  /// for an exit.
  final VoidCallback? onExit;

  @override
  State<ClassroomHeroesGame> createState() => _ClassroomHeroesGameState();
}

// ---------------------------------------------------------------------------
// Frame, assets, palette — all lifted from the prototype.
// ---------------------------------------------------------------------------

const double _kW = 1600;
const double _kH = 900;
const String _kA = 'assets/images/classroom_heroes';
const String _kBaloo = 'Baloo2';
const String _kNunito = 'Nunito';

const _cream = Color(0xFFFDF8EA);
const _creamChip = Color(0xFFFDF9EC);
const _creamPanel = Color(0xF5FDF8EA); // rgba(253,248,234,.96)
const _creamEdge = Color(0xFFCBB98D);
const _inkGreen = Color(0xFF1F4D2B);
const _deepGreen = Color(0xFF1F6B3A);
const _amber = Color(0xFFC9761B);
const _promptInk = Color(0xFF2C2418);
const _gold = Color(0xFFF2C34A);
const _goldDeep = Color(0xFFE0A537);
const _goldEdge = Color(0xFFA06A1C);
const _goldShade = Color(0xFF8A5A17);
const _goldInk = Color(0xFF7A4A17);
const _goldDrop = Color(0xFFDCA42F);
const _goldDropShade = Color(0xFFA97A1D);
const _leafGreen = Color(0xFF4FB15F);
const _leafGreenLit = Color(0xFF63C973);
const _leafGreenDeep = Color(0xFF2F8B45);
const _leafGreenShade = Color(0xFF1F6B32);
const _meterFill = Color(0xFF5FC06F);
const _meterTrack = Color(0xFFC8C3B4);
const _meterTrackEdge = Color(0xFFA9A394);
const _barTrack = Color(0xFFDED6BF);
const _barTrackEdge = Color(0xFFBDB29A);
const _decoyRed = Color(0xFFD9544C);
const _decoyRedDeep = Color(0xFFB32F2A);
const _decoyEdge = Color(0xFF8F2521);
const _curtainLit = Color(0xFF2C5A3A);
const _curtainDim = Color(0xFF22462D);
const _badgeEdge = Color(0xFFD8B04A);
const _sunYellow = Color(0xFFFFD94A);
const _ringYellow = Color(0xFFFFD75E);
const _retryBg = Color(0xFFFFF3F2);
const _retryEdge = Color(0xFFCF4A44);
const _retryInk = Color(0xFFC0342F);
const _retryBody = Color(0xFF6B3A36);
const _retryMark = Color(0xFFD8A52F);
const _successBg = Color(0xFFEEF7EA);
const _successEdge = Color(0xFF9FC9A6);
const _successCircle = Color(0xFFDCEFD6);
const _scenarioFallback = Color(0xFFDCD0B4);
const _stageBack = Color(0xFF0F1A12);

// Easing, straight from the prototype's `cubic-bezier(...)` calls.
const Curve _easeOut = Curves.easeOut;
const Curve _easeInOut = Curves.easeInOut;
const Curve _linear = Curves.linear;
const Curve _popOut = Cubic(0.3, 1.5, 0.5, 1); // ch-pop / ch-fill
const Curve _burstOut = Cubic(0.3, 1.6, 0.5, 1); // MUMTAZ pop
const Curve _curtainCurve = Cubic(0.65, 0, 0.35, 1);

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

/// `animation: <name> <dur>s infinite` — repeating phase 0..1.
double _loop(double t, double dur) {
  final x = t % dur;
  return (x < 0 ? x + dur : x) / dur;
}

/// The prototype's own timings, in seconds.
const double _kCurtain = 1.0;
const double _kNarrateDelay = 0.62;
const double _kMumtaz = 1.7;
const double _kTryAgain = 2.6;
const double _kReplaySpin = 0.9;

enum _Screen { start, play }

class _ClassroomHeroesGameState extends State<ClassroomHeroesGame>
    with SingleTickerProviderStateMixin {
  // A single monotonic clock drives every animation in the game; each one
  // derives its own phase from the elapsed seconds. One hour is far longer
  // than any sitting, so it never wraps mid-play.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(hours: 1),
  )..forward();

  double get _now => _clock.value * 3600.0;

  // Per-screen and per-element clocks, so entrance animations restart when
  // the thing they belong to appears (the prototype gets this for free from
  // mounting and unmounting its markup).
  double _screenT0 = 0;
  double _curtainT0 = 0;
  double _panelT0 = 0;
  double _successT0 = 0;
  double _mumtazT0 = 0;
  double _tryAgainT0 = 0;
  double _wrongT0 = 0;
  double _replayT0 = 0;
  double _finishT0 = 0;
  double _narrateT0 = 0;
  double _narrateDur = 1;

  double get _st => _now - _screenT0;

  _Screen _screen = _Screen.start;
  int _index = 0;
  int _correct = 0;
  bool _answered = false;
  bool _wrong = false;
  bool _mumtaz = false;
  bool _tryAgain = false;
  bool _replaying = false;
  bool _curtain = false;
  bool _narrating = false;
  bool _finished = false;

  int _errors = 0;

  Timer? _curtainTimer;
  Timer? _mumtazTimer;
  Timer? _tryAgainTimer;
  Timer? _replayTimer;
  Timer? _narrateDelayTimer;
  Timer? _narrateEndTimer;

  ClassroomHeroesSession get _session => widget.session;
  List<ClassroomHeroesQuestion> get _items => _session.questions;
  ClassroomHeroesQuestion get _q => _items[_index];

  @override
  void initState() {
    super.initState();
    // The prototype's stage is a 1600x900 landscape canvas — the app is
    // portrait-locked everywhere else, so this activity flips the device for
    // as long as it is on screen and puts it back on the way out (the same
    // trade `cast_screen.dart` makes for the casting view).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _curtainTimer?.cancel();
    _mumtazTimer?.cancel();
    _tryAgainTimer?.cancel();
    _replayTimer?.cancel();
    _stopNarration();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _clock.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Flow
  // -------------------------------------------------------------------------

  /// The prototype's `wipe()` — a 1s curtain across the question change.
  void _wipe() {
    _curtainTimer?.cancel();
    setState(() {
      _curtain = true;
      _curtainT0 = _now;
    });
    _curtainTimer = Timer(_ms(_kCurtain), () {
      if (!mounted) return;
      setState(() => _curtain = false);
    });
  }

  void _stopNarration() {
    _narrateDelayTimer?.cancel();
    _narrateEndTimer?.cancel();
  }

  /// The prototype's `narrate(delay)` — the question is "read out" as a
  /// filling progress bar whose length scales with the prompt's word count.
  /// There is no recorded audio yet, exactly as in the prototype (`say()` is
  /// a no-op there); the bar is the whole of the narration beat.
  void _narrate(double delay) {
    _stopNarration();
    final words = _q.promptText.split(RegExp(r'\s+')).length;
    final dur = 1.6 + words * 0.34;
    setState(() {
      _narrating = true;
      _narrateDur = dur;
      _narrateT0 = _now + delay;
    });
    _narrateDelayTimer = Timer(_ms(delay), () {
      if (!mounted) return;
      setState(() => _narrateT0 = _now);
      _narrateEndTimer = Timer(_ms(dur), () {
        if (!mounted) return;
        setState(() {
          _narrating = false;
          _panelT0 = _now;
        });
      });
    });
  }

  static Duration _ms(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  void _beginQuestion() {
    _wipe();
    _narrate(_kNarrateDelay);
  }

  void _play() {
    setState(() {
      _screen = _Screen.play;
      _screenT0 = _now;
      _index = 0;
      _correct = 0;
      _answered = false;
      _wrong = false;
      _tryAgain = false;
      _mumtaz = false;
      _finished = false;
      _errors = 0;
    });
    _beginQuestion();
  }

  void _backToStart() {
    _curtainTimer?.cancel();
    _mumtazTimer?.cancel();
    _tryAgainTimer?.cancel();
    _stopNarration();
    setState(() {
      _screen = _Screen.start;
      _screenT0 = _now;
      _index = 0;
      _correct = 0;
      _answered = false;
      _wrong = false;
      _tryAgain = false;
      _mumtaz = false;
      _curtain = false;
      _narrating = false;
      _finished = false;
    });
  }

  void _pick(bool good) {
    if (_answered) return;
    if (good) {
      HapticFeedback.mediumImpact();
      setState(() {
        _answered = true;
        _wrong = false;
        _tryAgain = false;
        _mumtaz = true;
        _mumtazT0 = _now;
        _successT0 = _now;
        _correct += 1;
      });
      _mumtazTimer?.cancel();
      _mumtazTimer = Timer(_ms(_kMumtaz), () {
        if (!mounted) return;
        setState(() => _mumtaz = false);
      });
    } else {
      HapticFeedback.lightImpact();
      setState(() {
        _wrong = true;
        _wrongT0 = _now;
        _tryAgain = true;
        _tryAgainT0 = _now;
        _errors += 1;
      });
      _tryAgainTimer?.cancel();
      _tryAgainTimer = Timer(_ms(_kTryAgain), () {
        if (!mounted) return;
        setState(() {
          _tryAgain = false;
          _wrong = false;
        });
      });
    }
  }

  void _next() {
    if (_index + 1 >= _items.length) {
      _mumtazTimer?.cancel();
      _stopNarration();
      setState(() {
        _finished = true;
        _mumtaz = false;
        _finishT0 = _now;
      });
      return;
    }
    setState(() {
      _index += 1;
      _answered = false;
      _wrong = false;
      _tryAgain = false;
      _mumtaz = false;
    });
    _beginQuestion();
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
    _narrate(0);
  }

  void _skipNarration() {
    _stopNarration();
    setState(() {
      _narrating = false;
      _panelT0 = _now;
    });
  }

  /// The badge screen's continue button — the lesson's only way on, so it
  /// reports the session's score up to the lesson player.
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
    final backdrop = _screen == _Screen.start
        ? '$_kA/start_screen.png'
        : _q.scenarioImage;
    final game = SizedBox(
      width: _kW,
      height: _kH,
      child: _screen == _Screen.start ? _buildStart() : _buildPlay(),
    );
    return ColoredBox(
      color: _stageBack,
      child: LayoutBuilder(
        builder: (context, box) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: _scenarioFallback,
                child: _screen == _Screen.start
                    ? _fx((t) {
                        final p = Curves.easeOutCubic.transform(_once(t, 1.8));
                        return Opacity(
                          opacity: math.min(1.0, p * 3),
                          child: Transform.scale(
                            scale: 1.07 - 0.07 * p,
                            child: SizedBox.expand(
                              child: Image.asset(backdrop, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      })
                    : _finished
                    ? _fx((_) {
                        final p = _easeOut.transform(
                          _once(_now - _finishT0, 0.6),
                        );
                        // Blur by decoding tiny and upscaling smoothly - no
                        // blur filter, so no soft/dark edge at the screen
                        // border. Cross-fades over the sharp scene.
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(backdrop, fit: BoxFit.cover),
                            Opacity(
                              opacity: p,
                              child: Image.asset(
                                backdrop,
                                fit: BoxFit.cover,
                                cacheWidth: 80,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                            ColoredBox(
                              color: Color.fromRGBO(255, 214, 120, 0.18 * p),
                            ),
                          ],
                        );
                      })
                    : Image.asset(backdrop, fit: BoxFit.cover),
              ),
              Center(
                child: AspectRatio(
                  aspectRatio: _kW / _kH,
                  child: FittedBox(fit: BoxFit.contain, child: game),
                ),
              ),
              if (_curtain)
                _buildCurtain(
                  box.maxHeight,
                  math.min(box.maxWidth / _kW, box.maxHeight / _kH),
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

  // =========================================================================
  // Title screen
  // =========================================================================

  Widget _buildStart() {
    return Stack(
      children: [
        // Logo drops in and settles with a soft overshoot.
        Positioned(
          left: (_kW - 747) / 2,
          top: 34,
          child: _fx((t) {
            final p = _once(t, 0.9, 0.2);
            final drop = Curves.easeOutBack.transform(p);
            return Opacity(
              opacity: Curves.easeOut.transform(math.min(1.0, p * 2.5)),
              child: Transform.translate(
                offset: Offset(0, -140 * (1 - drop)),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * drop,
                  child: Image.asset(
                    '$_kA/logo.png',
                    width: 747,
                    height: 351,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            );
          }),
        ),
        // Banner unrolls outward from its centre after the logo lands.
        Positioned(
          left: (_kW - 667) / 2,
          top: 290,
          child: _fx((t) {
            final p = Curves.easeInOutCubic.transform(_once(t, 0.8, 0.95));
            return Opacity(
              opacity: math.min(1.0, p * 4),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.center,
                  widthFactor: p,
                  child: Image.asset(
                    '$_kA/ribbon.png',
                    width: 667,
                    height: 222,
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
          bottom: 48,
          child: Center(
            child: _fx((t) {
              final p = Curves.easeOutCubic.transform(_once(t, 0.7, 1.6));
              final pulse = t > 2.4 ? 0.025 * math.sin((t - 2.4) * 3.2) : 0.0;
              return Opacity(
                opacity: p,
                child: Transform.translate(
                  offset: Offset(0, 36 * (1 - p)),
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * p + pulse,
                    child: _sessionCard(),
                  ),
                ),
              );
            }),
          ),
        ),
        if (widget.onExit != null)
          Positioned(
            left: 30,
            top: 24,
            child: _roundGold(Icons.close, 80, 38, widget.onExit!),
          ),
      ],
    );
  }

  Widget _sessionCard() {
    return _Push(
      key: const ValueKey('ch-play'),
      onTap: _play,
      dy: 5,
      builder: (down) => Image.asset(
        down ? '$_kA/play_btn_down.png' : '$_kA/play_btn.png',
        width: 460,
        gaplessPlayback: true,
      ),
    );
  }

  // =========================================================================
  // Play screen
  // =========================================================================

  Widget _buildPlay() {
    return Stack(
      children: [
        if (!_finished) _buildChrome(),
        if (_narrating && !_finished) _buildNarrationBar(),
        if (!_narrating && !_finished) _buildPanel(),
        if (_mumtaz) _buildMumtaz(),
        if (_tryAgain) _buildTryAgain(),
        if (_finished) _buildFinish(),
      ],
    );
  }

  /// Back arrow + the Classroom Hero Meter, one chunk per question.
  Widget _buildChrome() {
    return Positioned(
      top: 20,
      left: 26,
      right: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _roundGold(Icons.arrow_back, 88, 46, _backToStart),
          Expanded(child: Center(child: _heroMeter())),
          const SizedBox(width: 88),
        ],
      ),
    );
  }

  Widget _heroMeter({bool allFull = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 14, 26, 14),
      decoration: BoxDecoration(
        color: _creamChip,
        border: Border.all(color: _creamEdge, width: 5),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x29000000), offset: Offset(0, 7)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Classroom Hero Meter',
            style: TextStyle(
              fontFamily: _kNunito,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _inkGreen,
            ),
          ),
          const SizedBox(width: 22),
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            _meterChunk(
              on: allFull || i < _correct,
              // Only the chunk just earned wipes in; the ones before it are
              // already full and stay put.
              animate: !allFull && i == _correct - 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _meterChunk({required bool on, required bool animate}) {
    const fill = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_meterFill, _leafGreenDeep],
        ),
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: SizedBox.expand(),
    );
    return Container(
      width: 88,
      height: 38,
      decoration: BoxDecoration(
        color: _meterTrack,
        border: Border.all(color: _meterTrackEdge, width: 3),
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: !on
          ? const SizedBox.expand()
          // ch-fill .45s cubic-bezier(.3,1.5,.5,1) — the bar wipes in from
          // its left edge as the meter lights up.
          : animate
          ? _fx((_) {
              final p = _popOut.transform(_once(_now - _successT0, 0.45));
              return Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(widthFactor: _c01(p), child: fill),
              );
            })
          : fill,
    );
  }

  /// "Listen to the question…" — the narration beat, with its Skip.
  Widget _buildNarrationBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 34,
      child: Center(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (_, _) {
            final inT = _easeOut.transform(_once(_now - _narrateT0, 0.3));
            final pct = _c01((_now - _narrateT0) / _narrateDur);
            return Opacity(
              opacity: inT,
              child: Transform.translate(
                offset: Offset(0, 26 - 26 * inT),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 26, 18),
                  decoration: BoxDecoration(
                    color: _creamPanel,
                    border: Border.all(color: _creamEdge, width: 5),
                    borderRadius: BorderRadius.circular(999),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [_leafGreen, _leafGreenDeep],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _leafGreenShade,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.volume_up,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Listen to the question…',
                            style: TextStyle(
                              fontFamily: _kNunito,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 26 * 0.02,
                              color: _inkGreen,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: 640,
                            height: 26,
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
                      const SizedBox(width: 24),
                      _Push(
                        onTap: _skipNarration,
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
      ),
    );
  }

  /// The question panel — prompt (or success band) over the two choices.
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
                  if (_answered) _successBand() else _promptRow(),
                  const SizedBox(height: 22),
                  // `display:flex` stretches both cards to the taller one's
                  // height; a bare stretching Row has no height to stretch
                  // to inside this min-sized Column, so it is measured first.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _choice(
                            text: _q.correctText,
                            icon: Icons.thumb_up,
                            top: _answered ? _leafGreenLit : _leafGreen,
                            bottom: _leafGreenDeep,
                            edge: _leafGreenShade,
                            shake: false,
                            dim: 1,
                            tick: _answered,
                            onTap: () => _pick(true),
                          ),
                        ),
                        const SizedBox(width: 26),
                        Expanded(
                          child: _choice(
                            text: _q.decoyText,
                            icon: Icons.thumb_down,
                            top: _decoyRed,
                            bottom: _decoyRedDeep,
                            edge: _decoyEdge,
                            shake: _wrong,
                            dim: _answered ? 0.55 : 1,
                            tick: false,
                            onTap: () => _pick(false),
                          ),
                        ),
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
            _q.promptText,
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
        _Push(
          onTap: _replay,
          builder: (down) => Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_gold, _goldDeep],
              ),
              border: Border.all(color: _goldEdge, width: 5),
              boxShadow: [
                BoxShadow(color: _goldShade, offset: Offset(0, down ? 3 : 7)),
                const BoxShadow(
                  color: Color(0x38000000),
                  offset: Offset(0, 10),
                  blurRadius: 18,
                ),
              ],
            ),
            // ch-spin .9s linear while replaying
            child: _fx((_) {
              final a = _replaying
                  ? _loop(_now - _replayT0, _kReplaySpin) * 2 * 3.1415926535
                  : 0.0;
              return Transform.rotate(
                angle: a,
                child: const Icon(
                  Icons.refresh,
                  size: 50,
                  color: Color(0xFFFFFBE9),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _successBand() {
    return _fx((_) {
      final p = _easeOut.transform(_once(_now - _successT0, 0.3));
      return Opacity(
        opacity: p,
        child: Transform.translate(
          offset: Offset(0, 26 - 26 * p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _successBg,
              border: Border.all(color: _successEdge, width: 4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _successCircle,
                    shape: BoxShape.circle,
                    border: Border.all(color: _successEdge, width: 5),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 44,
                    color: _leafGreenDeep,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    _q.successFeedback,
                    style: const TextStyle(
                      fontFamily: _kBaloo,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1.22,
                      color: _inkGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                _Push(
                  onTap: _next,
                  builder: (down) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 34,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_leafGreen, _leafGreenDeep],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: _leafGreenShade,
                          offset: Offset(0, down ? 3 : 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _index + 1 >= _items.length ? 'Finish' : 'Next',
                          style: const TextStyle(
                            fontFamily: _kBaloo,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.arrow_forward,
                          size: 34,
                          color: Colors.white,
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
    });
  }

  Widget _choice({
    required String text,
    required IconData icon,
    required Color top,
    required Color bottom,
    required Color edge,
    required bool shake,
    required double dim,
    required bool tick,
    required VoidCallback onTap,
  }) {
    final card = _Push(
      onTap: onTap,
      builder: (down) => Container(
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
          border: Border.all(color: edge, width: 5),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: edge, offset: Offset(0, down ? 4 : 8)),
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
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 52, color: Colors.white),
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
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Color(0x33000000), offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
            if (tick) ...[
              const SizedBox(width: 24),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 40, color: _leafGreenDeep),
              ),
            ],
          ],
        ),
      ),
    );

    final dimmed = Opacity(opacity: dim, child: card);
    if (!shake) return dimmed;
    // ch-shake .45s ease-in-out — the decoy refuses the tap.
    return _fx((_) {
      final p = _once(_now - _wrongT0, 0.45);
      final dx = _kf(
        p,
        [0, 0.15, 0.3, 0.45, 0.6, 0.8, 1],
        [0, -14, 12, -9, 7, -4, 0],
        _easeInOut,
      );
      return Transform.translate(offset: Offset(dx, 0), child: dimmed);
    });
  }

  // =========================================================================
  // Overlays
  // =========================================================================

  Widget _buildMumtaz() {
    return Positioned(
      left: 0,
      right: 0,
      top: 150,
      child: IgnorePointer(
        child: _fx((_) {
          final t = _now - _mumtazT0;
          final pop = _once(t, 0.5);
          final ring = _loop(t, 0.9);
          return SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // ch-ring .9s ease-out infinite
                Opacity(
                  opacity: _kf(ring, [0, 1], [0.55, 0], _easeOut),
                  child: Transform.scale(
                    scale: _kf(ring, [0, 1], [0.6, 1.9], _easeOut),
                    child: Container(
                      width: 520,
                      height: 520,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _ringYellow, width: 16),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: _kf(pop, [0, 0.55, 1], [0, 1, 1]),
                  child: Transform.scale(
                    scale: _kf(
                      pop,
                      [0, 0.55, 0.75, 1],
                      [0.3, 1.12, 0.96, 1],
                      _burstOut,
                    ),
                    child: Transform.rotate(
                      angle:
                          _kf(
                            pop,
                            [0, 0.55, 0.75, 1],
                            [-12, 3, -1, -2],
                            _burstOut,
                          ) *
                          3.1415926535 /
                          180,
                      child: const _StrokedTitle(
                        'MUMTAZ!',
                        size: 92,
                        stroke: 10,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _kW / 2 - 330 - 26,
                  top: -10,
                  child: _twinkle(74, _sunYellow, 1.0),
                ),
                Positioned(
                  left: _kW / 2 + 290 - 26,
                  top: 60,
                  child: _twinkle(56, const Color(0xFFFFE680), 1.3),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// ch-star — a star that breathes and rocks, used beside MUMTAZ! and over
  /// the hero badge.
  Widget _twinkle(double size, Color color, double period, {Widget? child}) {
    return _fx((_) {
      final p = _loop(_now, period);
      final scale = _kf(p, [0, 0.5, 1], [0.85, 1.15, 0.85], _easeInOut);
      final angle = _kf(p, [0, 0.5, 1], [-8, 8, -8], _easeInOut);
      final opacity = _kf(p, [0, 0.5, 1], [0.85, 1, 0.85], _easeInOut);
      return Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle * 3.1415926535 / 180,
          child: Transform.scale(
            scale: scale,
            child:
                child ??
                Text(
                  '★',
                  style: TextStyle(fontSize: size, color: color, height: 1),
                ),
          ),
        ),
      );
    });
  }

  /// The curtain wipe between questions, with the question's number on it.
  Widget _buildCurtain(double h, double k) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: _fx((_) {
            final t = _now - _curtainT0;
            final p = _once(t, _kCurtain);
            // 0%,42% at rest, then out to ±104%.
            final slide = _kf(p, [0, 0.42, 1], [0, 0, 1.04], _curtainCurve);
            final badge = _once(t, 1.0);
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
                        BoxShadow(
                          color: Color(0xFF1A3623),
                          offset: Offset(0, 6),
                        ),
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
                        BoxShadow(
                          color: Color(0xFF1A3623),
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                  ),
                ),
                // ch-badge 1s ease-out — swells in, holds, shrinks away.
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: _kf(
                        badge,
                        [0, 0.22, 0.55, 0.72, 1],
                        [0, 1, 1, 0, 0],
                        _easeOut,
                      ),
                      child: Transform.scale(
                        scale:
                            k *
                            _kf(
                              badge,
                              [0, 0.22, 0.55, 0.72, 1],
                              [0.6, 1.04, 1, 0.9, 0.9],
                              _easeOut,
                            ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 62,
                            vertical: 30,
                          ),
                          decoration: BoxDecoration(
                            color: _cream,
                            border: Border.all(color: _badgeEdge, width: 7),
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
                                  color: _amber,
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
                                  color: _deepGreen,
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

  Widget _buildTryAgain() {
    return Positioned(
      right: 34,
      top: 140,
      child: _fx((_) {
        final p = _easeOut.transform(_once(_now - _tryAgainT0, 0.28));
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 26 - 26 * p),
            child: CustomPaint(
              foregroundPainter: const _DashedBorder(
                color: _retryEdge,
                width: 5,
                radius: 30,
              ),
              child: Container(
                width: 400,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 26,
                ),
                decoration: BoxDecoration(
                  color: _retryBg,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3D000000),
                      offset: Offset(0, 12),
                      blurRadius: 26,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _ringYellow,
                            shape: BoxShape.circle,
                            border: Border.all(color: _retryMark, width: 4),
                          ),
                          child: const Text(
                            '?',
                            style: TextStyle(
                              fontFamily: _kNunito,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: _goldInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Held to the card's width whatever the translation
                        // or fallback font does to it.
                        const Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Try again!',
                              style: TextStyle(
                                fontFamily: _kBaloo,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: _retryInk,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _session.retryText,
                      style: const TextStyle(
                        fontFamily: _kNunito,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: _retryBody,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // =========================================================================
  // Badge screen
  // =========================================================================

  Widget _buildFinish() {
    return Positioned.fill(
      child: _fx((_) {
        final t = _now - _finishT0;
        final reveal = _easeOut.transform(_once(t, 0.45));
        final card = _once(t, 0.55);
        return Opacity(
          opacity: reveal,
          child: Stack(
            children: [
              Positioned.fill(child: _confetti()),
              Positioned(
                left: 0,
                right: 0,
                top: 22,
                child: Center(child: _heroMeter(allFull: true)),
              ),
              // Amina and Ahmad, cheering either side of the card.
              Positioned(
                left: 24,
                bottom: 14,
                child: _cheer('amina_celebrate', 320, 489),
              ),
              Positioned(
                right: 24,
                bottom: 14,
                child: _cheer('ahmad_celebrate', 316, 489),
              ),
              Positioned(
                left: (_kW - 900) / 2,
                top: 236,
                width: 900,
                child: Opacity(
                  opacity: _kf(card, [0, 0.55, 1], [0, 1, 1]),
                  child: Transform.scale(
                    scale: _kf(
                      card,
                      [0, 0.55, 0.75, 1],
                      [0.3, 1.08, 0.97, 1],
                      _popOut,
                    ),
                    child: _badgePanel(),
                  ),
                ),
              ),
              if (widget.onExit != null)
                Positioned(
                  left: 30,
                  top: 24,
                  child: _roundGold(
                    Icons.home_outlined,
                    80,
                    38,
                    widget.onExit!,
                    bordered: false,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  /// A cheering character - static.
  Widget _cheer(String asset, double w, double h) =>
      Image.asset('$_kA/$asset.png', width: w, height: h);

  /// Confetti drifting down behind the card. Deterministic so it is stable.
  Widget _confetti() {
    const colors = [
      Color(0xFFFFD23F),
      Color(0xFF3DDC84),
      Color(0xFF3BA7FF),
      Color(0xFFFF5FA2),
      Color(0xFFFF8A2B),
    ];
    return IgnorePointer(
      child: Stack(
        children: [
          for (var i = 0; i < 28; i++)
            Positioned(
              left: ((i * 0.6180339) % 1.0) * _kW,
              top:
                  -30 +
                  (((_now - _finishT0) * (0.16 + (i % 5) * 0.035) + i * 0.137) %
                          1.0) *
                      (_kH + 60),
              child: Transform.rotate(
                angle: (_now * (1.2 + i % 3) + i) * 2,
                child: Container(
                  width: 12.0 + (i % 3) * 3,
                  height: 22.0 + (i % 2) * 6,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badgePanel() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Image.asset(
          '$_kA/badge_frame.png',
          width: 900,
          height: 539,
          fit: BoxFit.fill,
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(90, 34, 90, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('$_kA/ribbon_hero.png', width: 620, height: 157),
                const SizedBox(height: 10),
                Text(
                  _session.finishText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _kBaloo,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: _inkGreen,
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  label: 'Continue to Next Lesson',
                  child: _Push(
                    onTap: _finish,
                    dy: 3,
                    builder: (down) => Image.asset(
                      down
                          ? '$_kA/continue_btn_down.png'
                          : '$_kA/continue_btn.png',
                      width: 380,
                      height: 121,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -62,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _star(88, 1.1),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _star(112, 1.3),
              ),
              const SizedBox(width: 2),
              _star(88, 1.5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _star(double size, double period) {
    final img = Image.asset('$_kA/star.png', width: size, height: size * 0.908);
    return _fx((_) {
      final g = _kf(
        _loop(_now, period),
        [0, 0.5, 1],
        [0.45, 1, 0.45],
        _easeInOut,
      );
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size * 0.908,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(255, 236, 120, 0.9 * g),
                  blurRadius: size * 0.7 * (0.8 + 0.4 * g),
                  spreadRadius: size * 0.22 * g,
                ),
                BoxShadow(
                  color: Color.fromRGBO(255, 170, 30, 0.7 * g),
                  blurRadius: size * 1.4 * (0.8 + 0.4 * g),
                  spreadRadius: size * 0.4 * g,
                ),
              ],
            ),
          ),
          _twinkle(size, _sunYellow, period, child: img),
        ],
      );
    });
  }

  /// The prototype's round gold button — back, home and close all share it.
  Widget _roundGold(
    IconData icon,
    double size,
    double iconSize,
    VoidCallback onTap, {
    bool bordered = true,
  }) {
    return _Push(
      onTap: onTap,
      builder: (down) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bordered
                ? const [_gold, _goldDeep]
                : const [_gold, _goldDrop],
          ),
          border: Border.all(color: _goldEdge, width: 5),
          boxShadow: [
            BoxShadow(color: _goldShade, offset: Offset(0, down ? 3 : 6)),
            const BoxShadow(
              color: Color(0x4D000000),
              offset: Offset(0, 10),
              blurRadius: 18,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: bordered ? const Color(0xFFFFFBE9) : _goldInk,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

/// A button that sinks while held, like the prototype's `:active` rule —
/// the hard drop-shadow shrinks with it, which is what sells the press.
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

/// MUMTAZ! — gold fill inside a thick green outline. CSS gets this from
/// `-webkit-text-stroke` + `paint-order: stroke fill`; here the stroked copy
/// is painted first and the filled one laid over it.
class _StrokedTitle extends StatelessWidget {
  const _StrokedTitle(this.text, {required this.size, required this.stroke});

  final String text;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: _kBaloo,
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: size * 0.02,
      height: 1,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeJoin = StrokeJoin.round
              ..color = _deepGreen,
            shadows: const [
              Shadow(color: Color(0x40000000), offset: Offset(0, 10)),
            ],
          ),
        ),
        Text(text, style: base.copyWith(color: _sunYellow)),
      ],
    );
  }
}

/// `border: 5px dashed` — Flutter has no dashed border, so the Try again
/// card's outline is stroked by hand.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({
    required this.color,
    required this.width,
    required this.radius,
  });

  final Color color;
  final double width;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height).deflate(width / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    const dash = 14.0;
    const gap = 10.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, (d + dash).clamp(0, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.width != width || old.radius != radius;
}
