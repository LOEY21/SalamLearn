import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../widgets/arc_text_painter.dart';
import 'classroom_heroes_audio.dart';
import '../../widgets/app_orientation.dart';
import '../game_stage.dart';
import '../game_ui_audio.dart';

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
    this.onEnding,
    this.onExit,
    this.audioEnabled = true,
    this.audio,
  });

  final ClassroomHeroesSession session;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Fired when the game's own ending screen appears (the lesson player's
  /// cue for its congratulations sound).
  final VoidCallback? onEnding;

  /// Leaves the lesson — wired to the title screen's ✕ and the badge
  /// screen's home button, the two places the prototype's layout has room
  /// for an exit.
  final VoidCallback? onExit;
  final bool audioEnabled;
  final ClassroomAudioPlayback? audio;

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
const _leafGreenDeep = Color(0xFF2F8B45);
const _leafGreenShade = Color(0xFF1F6B32);
const _meterFill = Color(0xFF5FC06F);
const _meterWrong = Color(0xFFEF5B50);
const _meterWrongDeep = Color(0xFFC0352C);
const _meterTrack = Color(0xFFC8C3B4);
const _meterTrackEdge = Color(0xFFA9A394);
const _barTrack = Color(0xFFDED6BF);
const _barTrackEdge = Color(0xFFBDB29A);
// Both choice cards share one neutral colour, so neither gives the answer away.
const _choiceBlue = Color(0xFF4A90D9);
const _choiceBlueDeep = Color(0xFF2F6FB5);
const _choiceBlueEdge = Color(0xFF1F4F86);
const _curtainLit = Color(0xFF2C5A3A);
const _curtainDim = Color(0xFF22462D);
const _badgeEdge = Color(0xFFD8B04A);
const _sunYellow = Color(0xFFFFD94A);
const _ringYellow = Color(0xFFFFD75E);
const _successBg = Color(0xFFEEF7EA);
const _successEdge = Color(0xFF9FC9A6);
const _successCircle = Color(0xFFDCEFD6);
// The same band and cards on a wrong pick.
const _missBg = Color(0xFFFBEAE8);
const _missEdge = Color(0xFFE3A39B);
const _missCircle = Color(0xFFF6D6D1);
const _missRed = Color(0xFFE0574A);
const _missRedDeep = Color(0xFFC03A2F);
const _missRedEdge = Color(0xFF8E2219);
const _inkRed = Color(0xFF7A1F17);
const _scenarioFallback = Color(0xFFDCD0B4);
const _stageBack = Color(0xFF0F1A12);

// Easing, straight from the prototype's `cubic-bezier(...)` calls.
const Curve _easeOut = Curves.easeOut;
const Curve _easeInOut = Curves.easeInOut;
const Curve _linear = Curves.linear;
const Curve _popOut = Cubic(0.3, 1.5, 0.5, 1); // ch-pop / ch-fill

/// ease-out-quart: the end board's calm, no-overshoot arrival.
const Curve _quart = Cubic(0.25, 1, 0.5, 1);
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
/// The curtain wipe, on Sirah Stories' timeline (seconds): it shuts over
/// the current screen, the question plate comes up and **holds for 4
/// seconds**, then goes and the curtain opens. What is behind it changes at
/// the very end of the hold, so the prompt starts as the curtain opens.
const double _kWipeShut = 0.9; // curtain closed by here
const double _kPlateIn = 0.6; // plate starts to swell in
const double _kPlateUp = 1.1; // plate fully up
const double _kPlateHold = 4.0; // time it sits there, readable
const double _kPlateGone = _kPlateUp + _kPlateHold + 0.5;
const double _kCurtain = _kPlateGone + 0.9; // curtain drawn back by here
const double _kCurtainMid = _kPlateGone - 0.1;
const double _kMumtaz = 1.7;

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
  double _bandT0 = 0;
  double _wrongT0 = 0;
  double _finishT0 = 0;
  double _narrateT0 = 0;
  double _narrateDur = 1;
  ClassroomAudioPlayback? _audio;
  ClassroomQuestionAudio get _questionAudio =>
      classroomAudio[_session.number - 1][_index];

  double get _st => _now - _screenT0;

  _Screen _screen = _Screen.start;
  int _index = 0;
  int _correct = 0;
  bool _answered = false;

  /// The card tapped (and heard) but not yet submitted: true = hero card.
  bool? _selected;
  bool _wrong = false;
  bool _mumtaz = false;
  bool _curtain = false;

  /// The question number the curtain announces (the one coming up).
  int _curtainQ = 1;
  bool _narrating = false;
  bool _finished = false;
  bool _heroLeft = true;
  final _rng = math.Random();

  int _errors = 0;

  /// Each answered question's outcome, in order — the Hero Meter's chunks
  /// (green right, red wrong).
  final _results = <bool>[];

  Timer? _curtainTimer;
  Timer? _curtainMidTimer;
  Timer? _mumtazTimer;
  Timer? _narrateDelayTimer;
  Timer? _narrateEndTimer;

  ClassroomHeroesSession get _session => widget.session;
  List<ClassroomHeroesQuestion> get _items => _session.questions;
  ClassroomHeroesQuestion get _q => _items[_index];

  @override
  void initState() {
    super.initState();
    if (widget.audioEnabled) {
      _audio = widget.audio ?? ClassroomHeroesAudio();
      unawaited(_audio!.startMusic());
      _sayTitle();
    }
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
    _curtainMidTimer?.cancel();
    _mumtazTimer?.cancel();
    _stopNarration();
    if (_audio != null) unawaited(_audio!.dispose());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    restoreAppOrientations();
    _clock.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Flow
  // -------------------------------------------------------------------------

  /// True while a curtain is shutting over the old question — taps on it
  /// would act on a question that is about to be swapped out.
  bool get _swapping => _curtainMidTimer?.isActive ?? false;

  /// The curtain across a question change: it shuts over what is on screen,
  /// announces question [number], and opens on whatever [atMidpoint] put
  /// behind it.
  void _wipe(int number, VoidCallback atMidpoint) {
    _curtainTimer?.cancel();
    _curtainMidTimer?.cancel();
    setState(() {
      _curtain = true;
      _curtainT0 = _now;
      _curtainQ = number;
    });
    _curtainMidTimer = Timer(_ms(_kCurtainMid), () {
      if (!mounted) return;
      atMidpoint();
    });
    _curtainTimer = Timer(_ms(_kCurtain), () {
      if (!mounted) return;
      setState(() => _curtain = false);
    });
  }

  void _stopNarration() {
    _narrateDelayTimer?.cancel();
    _narrateEndTimer?.cancel();
    if (_audio != null) unawaited(_audio!.stopVoice());
  }

  void _endNarration() {
    _narrateEndTimer?.cancel();
    if (!mounted || !_narrating) return;
    setState(() {
      _narrating = false;
      _panelT0 = _now;
    });
    _playChoices();
  }

  /// Reads the two cards aloud left to right — the hero choice's side is
  /// random per question, so the spoken order doesn't give it away either.
  void _playChoices() {
    final audio = _audio;
    if (audio == null) return;
    final first = _heroLeft ? _questionAudio.correct : _questionAudio.decoy;
    final second = _heroLeft ? _questionAudio.decoy : _questionAudio.correct;

    void playSecond() {
      if (!mounted ||
          _screen != _Screen.play ||
          _answered ||
          _wrong ||
          _narrating) {
        return;
      }
      unawaited(audio.play(second));
    }

    unawaited(audio.play(first, onComplete: playSecond, onError: playSecond));
  }

  void _fallbackNarration(double duration) {
    if (!mounted) return;
    _narrateEndTimer?.cancel();
    _narrateEndTimer = Timer(_ms(duration), _endNarration);
  }

  /// Play the prompt after the curtain's opening beat. The authored duration
  /// remains the fallback when sound is unavailable.
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
      if (_audio == null) {
        _fallbackNarration(dur);
      } else {
        unawaited(
          _audio!.play(
            _questionAudio.prompt,
            onComplete: _endNarration,
            onError: () => _fallbackNarration(dur),
            onDuration: (duration) {
              if (mounted && duration.inMilliseconds > 0) {
                setState(() => _narrateDur = duration.inMilliseconds / 1000);
              }
            },
          ),
        );
      }
    });
  }

  static Duration _ms(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  /// Behind the closed curtain: deal the cards and read the prompt as the
  /// curtain opens.
  void _beginQuestion() {
    _heroLeft = _rng.nextBool();
    _narrate(_kPlateGone - _kCurtainMid);
  }

  void _play() {
    if (_swapping) return;
    // "Let's go!" / "Tayo na!" (~1.3s) ends long before the first prompt is
    // read at the curtain's midpoint ([_kCurtainMid]).
    if (_audio != null) unawaited(_audio!.play(ClassroomHeroesAudio.letsGo));
    _wipe(1, () {
      setState(() {
        _screen = _Screen.play;
        _screenT0 = _now;
        _index = 0;
        _correct = 0;
        _answered = false;
        _selected = null;
        _wrong = false;
        _mumtaz = false;
        _finished = false;
        _errors = 0;
        _results.clear();
      });
      _beginQuestion();
    });
  }

  void _sayTitle() {
    if (_audio == null) return;
    unawaited(_audio!.play(ClassroomHeroesAudio.title, localized: false));
  }

  bool _musicOn = true;

  void _toggleMusic() {
    setState(() => _musicOn = !_musicOn);
    if (_audio != null) unawaited(_audio!.setMusicEnabled(_musicOn));
  }

  /// Home in the game: stops the narration and leaves the lesson, like the
  /// start screen's close button (or back to the start screen when nothing
  /// hosts the game).
  void _home() {
    final exit = widget.onExit;
    if (exit == null) return _backToStart();
    _curtainTimer?.cancel();
    _curtainMidTimer?.cancel();
    _mumtazTimer?.cancel();
    _stopNarration();
    exit();
  }

  void _backToStart() {
    _curtainTimer?.cancel();
    _curtainMidTimer?.cancel();
    _mumtazTimer?.cancel();
    _stopNarration();
    setState(() {
      _screen = _Screen.start;
      _screenT0 = _now;
      _index = 0;
      _correct = 0;
      _answered = false;
      _selected = null;
      _wrong = false;
      _mumtaz = false;
      _curtain = false;
      _narrating = false;
      _finished = false;
      _results.clear();
    });
    _sayTitle();
  }

  /// Tapping a card only selects it and reads it aloud; Submit answers.
  void _select(bool good) {
    if (_answered || _swapping) return;
    HapticFeedback.selectionClick();
    _stopNarration();
    setState(() => _selected = good);
    if (_audio != null) {
      unawaited(
        _audio!.play(good ? _questionAudio.correct : _questionAudio.decoy),
      );
    }
  }

  void _pick(bool good) {
    if (_answered || _swapping) return;
    if (_audio != null) {
      unawaited(
        good ? _audio!.play(ClassroomHeroesAudio.mumtaz) : _audio!.stopVoice(),
      );
    }
    if (good) {
      HapticFeedback.mediumImpact();
      setState(() {
        _answered = true;
        _wrong = false;
        _mumtaz = true;
        _mumtazT0 = _now;
        _successT0 = _now;
        _bandT0 = _now;
        _correct += 1;
        _results.add(true);
      });
      _mumtazTimer?.cancel();
      _mumtazTimer = Timer(_ms(_kMumtaz), () {
        if (!mounted) return;
        setState(() => _mumtaz = false);
      });
    } else {
      // A wrong pick still ends the question: the decoy shakes, the hero
      // card is revealed, and Next moves on — no retry prompt.
      HapticFeedback.lightImpact();
      setState(() {
        _answered = true;
        _wrong = true;
        _wrongT0 = _now;
        _bandT0 = _now;
        _successT0 = _now;
        _errors += 1;
        GameUiAudio.instance.wrong();
        _results.add(false);
      });
    }
  }

  void _next() {
    if (_swapping) return;
    if (_index + 1 >= _items.length) {
      _mumtazTimer?.cancel();
      _stopNarration();
      setState(() {
        _finished = true;
        _mumtaz = false;
        _finishT0 = _now;
      });
      widget.onEnding?.call();
      return;
    }
    _wipe(_index + 2, () {
      setState(() {
        _index += 1;
        _answered = false;
        _selected = null;
        _wrong = false;
        _mumtaz = false;
      });
      _beginQuestion();
    });
  }

  void _readAgain() => _narrate(0);

  void _skipNarration() {
    _stopNarration();
    _endNarration();
  }

  /// The badge screen's continue button — the lesson's only way on, so it
  /// reports the session's score up to the lesson player.
  void _finish() {
    if (_audio != null) unawaited(_audio!.stopVoice());
    final accuracy = _items.isEmpty ? 100.0 : _correct / _items.length * 100.0;
    widget.onComplete(widget.xp, accuracy, _errors);
  }

  // -------------------------------------------------------------------------
  // Frame
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final start = _screen == _Screen.start;
    final backdrop = start ? '$_kA/start_screen.png' : _q.scenarioImage;
    const art = Rect.fromLTWH((_kW - _kArtW) / 2, 0, _kArtW, _kH);
    final game = SizedBox(
      width: _kW,
      height: _kH,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Full art height, centred: the 1870x841 art is wider than the
          // 16:9 frame, so it spills past the frame's sides and fills a
          // wide phone edge to edge — still lined up with the frame, where
          // the logo sits on its chalkboard.
          if (start) Positioned.fromRect(rect: art, child: _backdrop(backdrop)),
          start ? _buildStart() : _buildPlay(),
        ],
      ),
    );
    return ColoredBox(
      color: _stageBack,
      child: LayoutBuilder(
        builder: (context, box) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // The start art must stay under the logo, so it stays in the
              // frame and the bars a tablet leaves continue its edges. A
              // question's scene has nothing on it to line up with, so it
              // is drawn at screen size: on a wide phone exactly where the
              // frame would put it, on a squarer tablet zoomed to fill.
              if (start)
                StageBands(
                  asset: backdrop,
                  design: const Size(_kW, _kH),
                  art: art,
                )
              else
                _backdrop(backdrop),
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

  /// The scene art's width at the frame's height (art is 1870x841).
  static const double _kArtW = _kH * 1870 / 841;

  /// The scene art, animated as each screen needs.
  Widget _backdrop(String backdrop) {
    return ColoredBox(
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
              final p = _easeOut.transform(_once(_now - _finishT0, 0.6));
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
                  ColoredBox(color: Color.fromRGBO(255, 214, 120, 0.18 * p)),
                ],
              );
            })
          : Image.asset(backdrop, fit: BoxFit.cover),
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
                  child: SizedBox(
                    width: 667,
                    height: 222,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset('$_kA/ribbon.png', fit: BoxFit.fill),
                        // Bent along the band between its two stars:
                        // dark green outline under the white fill.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(122, 62, 122, 100),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              for (final style in _ribbonStyles)
                                CustomPaint(
                                  painter: ArcTextPainter(
                                    'Ready to Be a Hero Today?'.tr,
                                    style,
                                    radius: 1848,
                                  ),
                                ),
                            ],
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
        // Same Home and Music buttons as the game screen, same spots.
        if (widget.onExit != null)
          Positioned(
            left: 26,
            top: 20,
            child: _roundArt(
              Icons.home_rounded,
              widget.onExit!,
              label: 'Home',
              key: const ValueKey('ch-start-home'),
            ),
          ),
        Positioned(right: 26, top: 20, child: _musicButton()),
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
        // Sized up front (art is 1319x517) so the button doesn't measure
        // zero until the image decodes.
        height: 460 * 517 / 1319,
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
        if (_finished) _buildFinish(),
      ],
    );
  }

  /// Home + the Classroom Hero Meter (one chunk per question) + Music.
  Widget _buildChrome() {
    return Positioned(
      top: 20,
      left: 26,
      right: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _roundArt(
            Icons.home_rounded,
            _home,
            label: 'Home',
            key: const ValueKey('ch-home'),
          ),
          Expanded(child: Center(child: _heroMeter())),
          _musicButton(),
        ],
      ),
    );
  }

  Widget _musicButton() => _roundArt(
    _musicOn ? Icons.music_note_rounded : Icons.music_off_rounded,
    _toggleMusic,
    label: _musicOn ? 'Music on' : 'Music off',
    key: const ValueKey('ch-music'),
    dim: !_musicOn,
  );

  /// The painted gold round button with [icon] on it (Home, Music).
  Widget _roundArt(
    IconData icon,
    VoidCallback onTap, {
    required String label,
    Key? key,
    bool dim = false,
  }) {
    const size = 96.0;
    return Semantics(
      button: true,
      label: label,
      child: _Push(
        key: key,
        onTap: onTap,
        builder: (down) => Opacity(
          opacity: dim ? 0.6 : 1,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  down ? '$_kA/btn_round_down.png' : '$_kA/btn_round.png',
                  width: size,
                  height: size,
                  gaplessPlayback: true,
                ),
                Icon(
                  icon,
                  size: 50,
                  color: const Color(0xFFFFFBE9),
                  shadows: const [
                    Shadow(color: _goldShade, offset: Offset(0, 3)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroMeter({bool still = false}) {
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
              result: i < _results.length ? _results[i] : null,
              // Only the chunk just answered wipes in; the ones before it are
              // already filled and stay put.
              animate: !still && _answered && i == _results.length - 1,
            ),
          ],
        ],
      ),
    );
  }

  /// One question's chunk: green for a hero choice, red for a wrong one,
  /// empty while unanswered.
  Widget _meterChunk({required bool? result, required bool animate}) {
    final on = result != null;
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: result == false
              ? const [_meterWrong, _meterWrongDeep]
              : const [_meterFill, _leafGreenDeep],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: const SizedBox.expand(),
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
    final hero = _choice(
      text: _q.correctText,
      shake: false,
      dim: 1,
      tick: _answered,
      result: _answered ? true : null,
      selected: !_answered && _selected == true,
      onTap: () => _select(true),
    );
    final decoy = _choice(
      text: _q.decoyText,
      shake: _wrong,
      // The wrong pick stays bright in red; an unpicked decoy fades back.
      dim: _answered && !_wrong ? 0.55 : 1,
      // A cross on the wrong pick, so the result isn't colour alone.
      tick: _wrong,
      result: _answered ? false : null,
      selected: !_answered && _selected == false,
      onTap: () => _select(false),
    );
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
                        Expanded(child: _heroLeft ? hero : decoy),
                        const SizedBox(width: 26),
                        Expanded(child: _heroLeft ? decoy : hero),
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
    final canSubmit = _selected != null;
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
          key: const ValueKey('ch-read-again'),
          onTap: _readAgain,
          builder: (down) => Container(
            height: 92,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.volume_up, size: 42, color: Color(0xFFFFFBE9)),
                SizedBox(width: 12),
                Text(
                  'Read again',
                  style: TextStyle(
                    fontFamily: _kBaloo,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFFBE9),
                    shadows: [Shadow(color: _goldShade, offset: Offset(0, 2))],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        Opacity(
          opacity: canSubmit ? 1 : 0.5,
          child: _Push(
            key: const ValueKey('ch-submit'),
            onTap: () {
              if (_selected case final good?) _pick(good);
            },
            builder: (down) => Container(
              height: 92,
              padding: const EdgeInsets.symmetric(horizontal: 34),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_leafGreen, _leafGreenDeep],
                ),
                border: Border.all(color: _leafGreenShade, width: 5),
                boxShadow: [
                  BoxShadow(
                    color: _leafGreenShade,
                    offset: Offset(0, down && canSubmit ? 3 : 7),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 42, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Submit',
                    style: TextStyle(
                      fontFamily: _kBaloo,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _successBand() {
    return _fx((_) {
      final p = _easeOut.transform(_once(_now - _bandT0, 0.3));
      return Opacity(
        opacity: p,
        child: Transform.translate(
          offset: Offset(0, 26 - 26 * p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _wrong ? _missBg : _successBg,
              border: Border.all(
                color: _wrong ? _missEdge : _successEdge,
                width: 4,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _wrong ? _missCircle : _successCircle,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _wrong ? _missEdge : _successEdge,
                      width: 5,
                    ),
                  ),
                  child: Icon(
                    _wrong ? Icons.close_rounded : Icons.check,
                    size: 44,
                    color: _wrong ? _missRedDeep : _leafGreenDeep,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    _wrong
                        ? 'Good try! The hero choice is marked.'
                        : _q.successFeedback,
                    style: TextStyle(
                      fontFamily: _kBaloo,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1.22,
                      color: _wrong ? _inkRed : _inkGreen,
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
    required bool shake,
    required double dim,
    required bool tick,
    required bool selected,
    required VoidCallback onTap,
    bool? result,
  }) {
    // Once answered: the hero card turns green, the decoy red.
    final (top, deep, edge) = switch (result) {
      true => (_leafGreen, _leafGreenDeep, _leafGreenShade),
      false => (_missRed, _missRedDeep, _missRedEdge),
      null => (_choiceBlue, _choiceBlueDeep, _choiceBlueEdge),
    };
    final card = _Push(
      onTap: onTap,
      builder: (down) => AnimatedScale(
        scale: selected ? 1.03 : 1,
        duration: const Duration(milliseconds: 160),
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, deep],
            ),
            border: Border.all(
              color: selected ? _gold : edge,
              width: selected ? 9 : 5,
            ),
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
                child: const Icon(
                  Icons.touch_app_rounded,
                  size: 52,
                  color: Colors.white,
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
                  child: Icon(
                    result == false ? Icons.close_rounded : Icons.check,
                    size: 40,
                    color: result == false ? _missRedDeep : _leafGreenDeep,
                  ),
                ),
              ],
            ],
          ),
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
            // Timeline in seconds, so the plate's reading time is exact.
            final e = (_now - _curtainT0).clamp(0.0, _kCurtain);
            final cover = _kf(
              e,
              [0, _kWipeShut, _kPlateGone, _kCurtain],
              [0, 1, 1, 0],
              _curtainCurve,
            );
            final slide = 1 - cover;
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
                // Swells in, holds 4s to be read, shrinks away.
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: _c01(plate),
                      child: Transform.scale(
                        scale: k * plateScale,
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
                                'Question $_curtainQ',
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

  // =========================================================================
  // Badge screen
  // =========================================================================

  Widget _buildFinish() {
    final still = MediaQuery.of(context).disableAnimations;
    return Positioned.fill(
      child: _fx((_) {
        // Reduced motion lands straight on the settled board.
        final t = still ? 99.0 : _now - _finishT0;
        // One calm, staged arrival: the room fades in, the board rises,
        // then the cheering friends step up and the confetti starts.
        final room = _quart.transform(_once(t, 0.35));
        final card = _quart.transform(_once(t, 0.55, 0.05));
        final kids = _quart.transform(_once(t, 0.55, 0.35));
        final party = _once(t, 0.8, 0.6);
        return Opacity(
          opacity: room,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(opacity: party, child: _confetti()),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 22,
                child: Center(child: _heroMeter(still: true)),
              ),
              // Amina and Ahmad, cheering either side of the board.
              Positioned(
                left: 24,
                bottom: 14,
                child: _riseIn(kids, 70, _cheer('amina_celebrate', 320, 489)),
              ),
              Positioned(
                right: 24,
                bottom: 14,
                child: _riseIn(kids, 70, _cheer('ahmad_celebrate', 316, 489)),
              ),
              Positioned(
                left: (_kW - 900) / 2,
                top: 236,
                width: 900,
                child: Opacity(
                  opacity: card,
                  child: Transform.translate(
                    offset: Offset(0, 48 * (1 - card)),
                    child: Transform.scale(
                      scale: 0.96 + 0.04 * card,
                      child: _badgePanel(t),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// Fades [child] in while it rises [dy] px into place; [p] is 0..1.
  static Widget _riseIn(double p, double dy, Widget child) => Opacity(
    opacity: p,
    child: Transform.translate(offset: Offset(0, dy * (1 - p)), child: child),
  );

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

  /// Stars for the round: every hero choice 3, at least half 2, else 1.
  int get _stars {
    final n = _items.length;
    if (_correct >= n) return 3;
    return _correct * 2 >= n ? 2 : 1;
  }

  String get _verdict => switch (_stars) {
    3 => 'Perfect! You made every hero choice!',
    2 => 'Great job! Keep being a classroom hero!',
    _ => 'Good try! Play again to earn more stars!',
  };

  /// The end board, read top to bottom: the CLASSROOM HERO! ribbon on the
  /// frame's top edge, the stars earned, how it went, one mark per
  /// question, and Continue on the bottom edge. [t] staggers each in.
  Widget _badgePanel(double t) {
    Widget step(double delay, Widget child) =>
        _riseIn(_quart.transform(_once(t, 0.45, delay)), 16, child);
    Widget starIn(int i, Widget star) {
      final p = _quart.transform(_once(t, 0.45, 0.55 + i * 0.12));
      return Opacity(
        opacity: p,
        child: Transform.scale(scale: 0.6 + 0.4 * p, child: star),
      );
    }

    // Tall enough to hold Continue where it straddles the frame's bottom
    // edge — a tap only lands inside its parent's bounds.
    return SizedBox(
      width: 900,
      height: 539 + 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Image.asset(
            '$_kA/badge_frame.png',
            width: 900,
            height: 539,
            fit: BoxFit.fill,
          ),
          // Inside the frame's starry border, under the ribbon and above
          // the button. Copy wraps first and only shrinks if it must.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 539,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(120, 92, 120, 74),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 660,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          starIn(0, _star(76, 1.1, on: _stars >= 1)),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: starIn(1, _star(96, 1.3, on: _stars >= 2)),
                          ),
                          const SizedBox(width: 10),
                          starIn(2, _star(76, 1.5, on: _stars >= 3)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      step(
                        0.8,
                        Text(
                          _verdict,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: _kBaloo,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                            color: _deepGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      step(
                        0.9,
                        Text(
                          _session.finishText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: _kBaloo,
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: _inkGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      step(1.0, _resultMarks()),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -58,
            child: step(
              0.3,
              Image.asset('$_kA/ribbon_hero.png', width: 470, height: 119),
            ),
          ),
          Positioned(
            bottom: 0,
            child: step(
              1.1,
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
                    width: 316,
                    height: 101,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One mark per question, in the order played: a green tick for a hero
  /// choice, a red cross for a miss.
  Widget _resultMarks() {
    return Semantics(
      label: '$_correct of ${_items.length}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, ok) in _results.indexed) ...[
            if (i > 0) const SizedBox(width: 16),
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ok ? _leafGreenDeep : _meterWrongDeep,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                ok ? Icons.check_rounded : Icons.close_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Unearned stars: greyed out, no glow or twinkle.
  static const _greyStar = ColorFilter.matrix([
    .2126, .7152, .0722, 0, 0, //
    .2126, .7152, .0722, 0, 0,
    .2126, .7152, .0722, 0, 0,
    0, 0, 0, .45, 0,
  ]);

  Widget _star(double size, double period, {bool on = true}) {
    final img = Image.asset('$_kA/star.png', width: size, height: size * 0.908);
    if (!on) return ColorFiltered(colorFilter: _greyStar, child: img);
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

/// The start ribbon's lettering: a dark green outline, then white.
final _ribbonStyles = [
  for (final fill in [false, true])
    TextStyle(
      fontFamily: _kBaloo,
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: fill ? Colors.white : null,
      foreground: fill
          ? null
          : (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF0C4A1A)),
    ),
];
