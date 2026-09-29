import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import 'greeting_match_audio.dart';

enum _Screen { start, howTo, countdown, play, done }

/// Tapped-choice feedback state for one answer button.
enum _ChoiceState { idle, correct, wrong }

const String _kArabicFont = 'ScheherazadeNew';
const String _kUiFont = 'Baloo2Var';
const Color _kInk = Color(0xFF3B2A16);

/// Greeting Match:
/// A Madrasah classroom start screen (Zara, Amir, title logo, session
/// ribbon, subtitle pill, Play). Play opens the matching round: a full-bleed
/// cartoon scenario, the greeting auto-plays (replayable via Play Audio),
/// and the learner taps the right Arabic response. Correct turns the button
/// green, the scene cheers and a Greeting Star is earned; wrong shakes the
/// button with a brief red flash.
class GreetingMatchActivity extends StatefulWidget {
  const GreetingMatchActivity({
    super.key,
    required this.session,
    required this.xp,
    required this.onComplete,
    this.onBack,
  });

  final GreetingMatchSession session;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;
  final VoidCallback? onBack;

  @override
  State<GreetingMatchActivity> createState() => _GreetingMatchActivityState();
}

class _GreetingMatchActivityState extends State<GreetingMatchActivity>
    with TickerProviderStateMixin {
  _Screen _screen = _Screen.start;
  int _idx = 0;

  /// One result per answered question: true = gold star, false = red star.
  final List<bool> _results = [];
  double _wobble = 0.0;
  bool _playDown = false;
  int? _correctIdx;
  int? _wrongIdx;

  /// After a wrong tap, the right answer lights up green so the learner
  /// sees it before the game moves on.
  int? _revealIdx;
  Timer? _wrongTimer;
  Timer? _nextTimer;
  Timer? _promptTimer;
  Timer? _revealTimer;

  /// How to Play holds its Let's Play button back for 5 seconds so the
  /// steps get read first.
  static const _howToHold = Duration(seconds: 5);
  bool _howToReady = false;
  Timer? _howToTimer;

  /// 3-2-1 before each round.
  int _count = 3;
  Timer? _countTimer;

  /// False while the scene is shown alone before the choices slide in.
  bool _revealed = false;

  late final AnimationController _wobbleController;
  late final AnimationController _idleController;
  late final AnimationController _cheerController;
  final GreetingMatchAudio _audio = GreetingMatchAudio();

  List<GreetingQuestion> get _questions => widget.session.questions;
  GreetingQuestion get _question => _questions[_idx];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _wobbleController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addListener(() {
          final t = _wobbleController.value;
          setState(() {
            _wobble = math.sin(t * math.pi * 3) * 10 * (1 - t);
          });
        });

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _cheerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final q in _questions) {
      precacheImage(AssetImage(q.scenarioImage), context);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _wrongTimer?.cancel();
    _nextTimer?.cancel();
    _promptTimer?.cancel();
    _revealTimer?.cancel();
    _howToTimer?.cancel();
    _countTimer?.cancel();
    _wobbleController.dispose();
    _idleController.dispose();
    _cheerController.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  void _startGame() {
    HapticFeedback.mediumImpact();
    _openHowTo();
  }

  void _openHowTo() {
    _howToTimer?.cancel();
    setState(() {
      _screen = _Screen.howTo;
      _howToReady = false;
    });
    _howToTimer = Timer(_howToHold, () {
      if (mounted) setState(() => _howToReady = true);
    });
  }

  void _backToStart() {
    _howToTimer?.cancel();
    setState(() => _screen = _Screen.start);
  }

  void _startCountdown() {
    HapticFeedback.mediumImpact();
    _countTimer?.cancel();
    setState(() {
      _screen = _Screen.countdown;
      _count = 3;
    });
    _countTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_count > 1) {
        HapticFeedback.selectionClick();
        setState(() => _count--);
      } else {
        t.cancel();
        _beginRound();
      }
    });
  }

  void _beginRound() {
    _idleController.stop();
    HapticFeedback.mediumImpact();
    setState(() {
      _screen = _Screen.play;
      _idx = 0;
      _results.clear();
      _correctIdx = null;
      _wrongIdx = null;
      _revealIdx = null;
    });
    _queuePrompt();
  }

  int get _correctCount => _results.where((r) => r).length;
  int get _errors => _results.where((r) => !r).length;

  double get _accuracyPct => _results.isEmpty
      ? 100.0
      : _correctCount / _results.length * 100;

  /// 3 stars for all correct, 2 from 60%, 1 for any correct, else 0.
  int get _starRating => _errors == 0
      ? 3
      : _accuracyPct >= 60
      ? 2
      : _correctCount > 0
      ? 1
      : 0;

  void _finish() =>
      widget.onComplete(widget.xp, _accuracyPct, _errors);

  void _playAgain() {
    HapticFeedback.mediumImpact();
    _idleController.repeat();
    _openHowTo();
  }

  /// Auto-plays the greeting once the new scene has faded in.
  /// Shows the whole scene for 4 seconds (greeting auto-plays over it),
  /// then slides in the title, stars, prompt card and choices.
  void _queuePrompt() {
    _promptTimer?.cancel();
    _revealTimer?.cancel();
    setState(() => _revealed = false);
    _promptTimer = Timer(const Duration(milliseconds: 450), _playPrompt);
    _revealTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  Widget _reveal(Widget child, {required double dy}) {
    final d = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 500);
    return IgnorePointer(
      ignoring: !_revealed,
      child: AnimatedOpacity(
        opacity: _revealed ? 1 : 0,
        duration: d,
        curve: Curves.easeOutQuart,
        child: AnimatedSlide(
          offset: _revealed ? Offset.zero : Offset(0, dy),
          duration: d,
          curve: Curves.easeOutQuart,
          child: child,
        ),
      ),
    );
  }

  void _playPrompt() {
    if (!mounted) return;
    unawaited(_audio.play([_question.audioAsset]));
  }

  /// One tap per question: right = gold star, wrong = red star (the right
  /// answer is shown, then the game moves on — no retry).
  void _handleChoice(int i) {
    if (_results.length > _idx || !_revealed) return;
    final choice = _question.choices[i];
    if (choice.correct) {
      HapticFeedback.lightImpact();
      _wrongTimer?.cancel();
      setState(() {
        _correctIdx = i;
        _wrongIdx = null;
        _results.add(true);
      });
      if (MediaQuery.of(context).disableAnimations) {
        _cheerController.value = 1;
      } else {
        _cheerController.forward(from: 0);
      }
      unawaited(_audio.play([choice.audioAsset, GreetingMatchAudio.mumtaz]));
      _nextTimer = Timer(const Duration(milliseconds: 1600), _next);
    } else {
      HapticFeedback.heavyImpact();
      final right = _question.choices.indexWhere((c) => c.correct);
      setState(() {
        _wrongIdx = i;
        _results.add(false);
      });
      if (!MediaQuery.of(context).disableAnimations) {
        _wobbleController.forward(from: 0);
      }
      unawaited(
        _audio.play([
          GreetingMatchAudio.tryAgain,
          _question.choices[right].audioAsset,
        ]),
      );
      _wrongTimer?.cancel();
      _wrongTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _revealIdx = right);
      });
      _nextTimer = Timer(const Duration(milliseconds: 2400), _next);
    }
  }

  void _next() {
    if (!mounted) return;
    if (_idx + 1 >= _questions.length) {
      _promptTimer?.cancel();
      _revealTimer?.cancel();
      _idleController.repeat();
      setState(() => _screen = _Screen.done);
    } else {
      setState(() {
        _idx++;
        _correctIdx = null;
        _wrongIdx = null;
        _revealIdx = null;
      });
      _queuePrompt();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey(_screen),
        child: switch (_screen) {
          _Screen.start => _buildStartScreen(),
          _Screen.howTo => _buildHowToScreen(),
          _Screen.countdown => _buildCountdownScreen(),
          _Screen.play => _buildPlayScreen(),
          _Screen.done => _buildEndScreen(),
        },
      ),
    );
  }

  // Shared 1870x841 canvas over the classroom scene, washed back so cards
  // read clearly; Home + Music sit top-right like every other screen.
  Widget _sceneCanvas({
    required List<Widget> children,
    VoidCallback? onBackTap,
    required String keyPrefix,
    bool chrome = true,
  }) {
    final showHome = chrome && widget.onBack != null;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF6EC),
        image: DecorationImage(
          image: AssetImage('assets/images/greeting_match/start_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: const Color(0xFFFFF7E6).withValues(alpha: 0.55),
        child: SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 1870,
                height: 841,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ...children,
                    if (onBackTap != null)
                      Positioned(
                        left: 32,
                        top: 14,
                        width: 110,
                        height: 110,
                        child: _backButton(Key('$keyPrefix-back'), onBackTap),
                      ),
                    if (showHome)
                      Positioned(
                        right: 32,
                        top: 14,
                        width: 110,
                        height: 110,
                        child: _homeButton(
                          Key('$keyPrefix-home'),
                          widget.onBack!,
                        ),
                      ),
                    if (chrome)
                      Positioned(
                        right: showHome ? 162 : 32,
                        top: 14,
                        width: 110,
                        height: 110,
                        child: _musicButton(Key('$keyPrefix-music')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── HOW TO PLAY ─────────────────────────────────────────────────────────────

  Widget _buildHowToScreen() {
    const steps = [
      (
        Icons.volume_up_rounded,
        _Palette.blue,
        'Watch & Listen',
        'Look at the picture and listen to the greeting.',
      ),
      (
        Icons.touch_app_rounded,
        _Palette.gold,
        'Tap the Reply',
        'Tap the correct Arabic reply to the greeting.',
      ),
      (
        Icons.star_rounded,
        _Palette.green,
        'Earn Stars',
        'Get a Greeting Star for every right answer!',
      ),
    ];
    return _sceneCanvas(
      keyPrefix: 'greeting-howto',
      onBackTap: _backToStart,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 12,
          child: Center(
            child: _Enter(
              from: Offset(0, -0.4),
              scale: 0.9,
              curve: Curves.easeOutBack,
              child: _TitleBadge(title: 'How to Play'),
            ),
          ),
        ),
        Positioned(
          left: 170,
          right: 170,
          top: 215,
          height: 400,
          child: Row(
            children: [
              for (final (i, (icon, palette, title, text)) in steps.indexed) ...[
                if (i > 0) const SizedBox(width: 50),
                Expanded(
                  child: _Enter(
                    delay: 250 + i * 160,
                    from: const Offset(0, 0.18),
                    scale: 0.94,
                    child: _StepCard(
                      number: i + 1,
                      icon: icon,
                      palette: palette,
                      title: title,
                      text: text,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_howToReady)
          Positioned(
            left: (1870 - 480) / 2,
            top: 668,
            width: 480,
            height: 118,
            child: _Enter(
              duration: 600,
              from: Offset.zero,
              scale: 0.4,
              curve: Curves.easeOutBack,
              child: _GlossyButton(
                key: const Key('greeting-howto-play'),
                palette: _Palette.green,
                radius: 56,
                depth: 9,
                outline: Colors.white,
                onTap: _startCountdown,
                child: const _IconLabel(
                  icon: Icons.play_arrow_rounded,
                  label: "Let's Play!",
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── COUNTDOWN ───────────────────────────────────────────────────────────────

  Widget _buildCountdownScreen() {
    return _sceneCanvas(
      keyPrefix: 'greeting-countdown',
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 12,
          child: Center(
            child: _Enter(
              from: Offset(0, -0.4),
              scale: 0.9,
              curve: Curves.easeOutBack,
              child: _TitleBadge(title: 'Get Ready!'),
            ),
          ),
        ),
        Positioned(
          left: (1870 - 360) / 2,
          top: 250,
          width: 360,
          height: 360,
          child: _Enter(
            key: ValueKey('greeting-countdown-$_count'),
            duration: 480,
            from: Offset.zero,
            scale: 0.3,
            curve: Curves.easeOutBack,
            child: _GlossyButton(
              palette: _Palette.gold,
              radius: 180,
              depth: 14,
              outline: Colors.white,
              child: Text(
                '$_count',
                style: const TextStyle(
                  fontFamily: _kUiFont,
                  fontSize: 210,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6E3A08),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 668,
          child: Center(
            child: _Enter(
              delay: 200,
              child: Text(
                'Listen carefully!',
                style: TextStyle(
                  fontFamily: _kUiFont,
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── ENDING ──────────────────────────────────────────────────────────────────

  Widget _buildEndScreen() {
    final rating = _starRating;
    return _sceneCanvas(
      keyPrefix: 'greeting-end',
      chrome: false,
      children: [
        // Zara and Amir cheering either side of the results card.
        Positioned(
          left: 40,
          top: 300,
          width: 390,
          height: 520,
          child: _Enter(
            delay: 250,
            from: const Offset(-0.6, 0),
            duration: 700,
            child: _bob(
              Image.asset(
                'assets/images/greeting_match/start_girl.png',
                fit: BoxFit.contain,
              ),
              phase: 0,
            ),
          ),
        ),
        Positioned(
          right: 40,
          top: 300,
          width: 390,
          height: 520,
          child: _Enter(
            delay: 350,
            from: const Offset(0.6, 0),
            duration: 700,
            child: _bob(
              Image.asset(
                'assets/images/greeting_match/start_boy.png',
                fit: BoxFit.contain,
              ),
              phase: 0.5,
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 12,
          child: Center(
            child: _Enter(
              from: Offset(0, -0.4),
              scale: 0.8,
              duration: 650,
              curve: Curves.easeOutBack,
              child: _TitleBadge(title: 'Great Job!'),
            ),
          ),
        ),
        Positioned(
          key: const Key('greeting-end'),
          left: 460,
          right: 460,
          top: 196,
          height: 468,
          child: _Enter(
            delay: 300,
            from: const Offset(0, 0.08),
            scale: 0.88,
            duration: 600,
            curve: Curves.easeOutBack,
            child: _ResultsCard(
              rating: rating,
              results: _results,
              accuracyPct: _accuracyPct,
              xp: widget.xp,
              questions: _questions,
            ),
          ),
        ),
        Positioned(
          left: 1870 / 2 - 420,
          top: 692,
          width: 400,
          height: 112,
          child: _Enter(
            delay: 1100,
            from: const Offset(0, 0.5),
            child: _GlossyButton(
              key: const Key('greeting-end-replay'),
              palette: _Palette.blue,
              radius: 52,
              depth: 9,
              outline: Colors.white,
              onTap: _playAgain,
              child: const _IconLabel(
                icon: Icons.replay_rounded,
                label: 'Play Again',
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          left: 1870 / 2 + 20,
          top: 692,
          width: 400,
          height: 112,
          child: _Enter(
            delay: 1200,
            from: const Offset(0, 0.5),
            child: _GlossyButton(
              key: const Key('greeting-end-continue'),
              palette: _Palette.green,
              radius: 52,
              depth: 9,
              outline: Colors.white,
              onTap: _finish,
              child: const _IconLabel(
                icon: Icons.arrow_forward_rounded,
                label: 'Continue',
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Gentle idle bob for the cheering mascots.
  Widget _bob(Widget child, {required double phase}) => AnimatedBuilder(
    animation: _idleController,
    builder: (context, child) {
      final t = (_idleController.value + phase) % 1.0;
      return Transform.translate(
        offset: Offset(0, math.sin(t * 2 * math.pi) * 8),
        child: child,
      );
    },
    child: child,
  );

  // ─── START SCREEN ────────────────────────────────────────────────────────────

  bool _muted = false;

  void _toggleMuted() {
    setState(() => _muted = !_muted);
    unawaited(_audio.setMuted(_muted));
  }

  /// Music note = sound on/off. Muted shows greyed out with a red slash.
  Widget _musicButton(Key key) => _Enter(
    delay: 520,
    from: Offset.zero,
    scale: 0.7,
    curve: Curves.easeOutBack,
    child: _musicToggle(key),
  );

  Widget _musicToggle(Key key) => Semantics(
    button: true,
    toggled: !_muted,
    label: _muted ? 'Sound off' : 'Sound on',
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: _muted
              ? const ColorFilter.matrix([
                  0.5, 0.35, 0.1, 0, 0, //
                  0.4, 0.4, 0.1, 0, 0, //
                  0.35, 0.3, 0.2, 0, 0, //
                  0, 0, 0, 1, 0,
                ])
              : const ColorFilter.mode(Color(0x00000000), BlendMode.dst),
          child: _ImageButton(key: key, name: 'music', onTap: _toggleMuted),
        ),
        if (_muted)
          IgnorePointer(
            child: CustomPaint(painter: _MutedSlashPainter()),
          ),
      ],
    ),
  );

  Widget _buildStartScreen() {
    const double canvasW = 1870.0;
    const double canvasH = 841.0;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF6EC),
        image: DecorationImage(
          image: AssetImage('assets/images/greeting_match/start_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: canvasW,
                  height: canvasH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Background scene layer
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/greeting_match/start_bg.png',
                          fit: BoxFit.fill,
                        ),
                      ),

                      if (widget.onBack != null) ...[
                        Positioned(
                          left: 32,
                          top: 14,
                          width: 110,
                          height: 110,
                          child: _backButton(
                            const Key('greeting-start-back'),
                            widget.onBack!,
                          ),
                        ),
                        Positioned(
                          right: 32,
                          top: 14,
                          width: 110,
                          height: 110,
                          child: _homeButton(
                            const Key('greeting-start-home'),
                            widget.onBack!,
                          ),
                        ),
                      ],
                      Positioned(
                        right: widget.onBack != null ? 162 : 32,
                        top: 14,
                        width: 110,
                        height: 110,
                        child: _musicButton(const Key('greeting-start-music')),
                      ),

                      // Floor shadows under the mascots' feet
                      const Positioned(
                        left: 306,
                        top: 762,
                        width: 300,
                        height: 46,
                        child: _FloorShadow(),
                      ),
                      const Positioned(
                        left: 1239,
                        top: 765,
                        width: 300,
                        height: 46,
                        child: _FloorShadow(),
                      ),

                      // Zara (left) and Amir (right)
                      Positioned(
                        left: 241,
                        top: 239,
                        width: 422,
                        height: 562,
                        child: _Enter(
                          delay: 250,
                          from: const Offset(-0.5, 0),
                          duration: 650,
                          child: Image.asset(
                            'assets/images/greeting_match/start_girl.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 1165,
                        top: 253,
                        width: 413,
                        height: 550,
                        child: _Enter(
                          delay: 330,
                          from: const Offset(0.5, 0),
                          duration: 650,
                          child: Image.asset(
                            'assets/images/greeting_match/start_boy.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // Title logo with the session name on its ribbon
                      AnimatedBuilder(
                        animation: _idleController,
                        builder: (context, child) {
                          final t = _idleController.value;
                          final dy = math.sin(t * 2 * math.pi) * 3.0;
                          return Positioned(
                            left: 620,
                            top: 26 + dy,
                            width: 560,
                            height: 446,
                            child: _Enter(
                              from: const Offset(0, -0.3),
                              scale: 0.85,
                              duration: 700,
                              curve: Curves.easeOutBack,
                              child: child!,
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/greeting_match/start_logo.png',
                                fit: BoxFit.fill,
                              ),
                            ),
                            Positioned(
                              left: 84,
                              right: 84,
                              top: 368,
                              bottom: 20,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.session.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 27,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                      shadows: [
                                        Shadow(
                                          color: Color(0xCC0B2A7A),
                                          offset: Offset(0, 2),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Subtitle pill: nine-slice keeps the rounded caps
                      // round at the pill's much wider on-screen aspect.
                      Positioned(
                        left: 600,
                        top: 480,
                        width: 645,
                        height: 53,
                        child: _Enter(
                          delay: 450,
                          from: const Offset(0, 0.6),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: FittedBox(
                                  fit: BoxFit.fill,
                                  child: SizedBox(
                                    width: 5234,
                                    height: 430,
                                    child: Image.asset(
                                      'assets/images/greeting_match/start_pill.png',
                                      fit: BoxFit.fill,
                                      centerSlice: const Rect.fromLTRB(
                                        240,
                                        0,
                                        1645,
                                        430,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 26,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.session.subtitle,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Color(0xFF5B3B1E),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Ray bursts either side of Play
                      Positioned(
                        left: 628,
                        top: 572,
                        width: 56,
                        height: 64,
                        child: _Enter(
                          delay: 700,
                          from: Offset.zero,
                          scale: 0.3,
                          curve: Curves.easeOutBack,
                          child: Image.asset(
                            'assets/images/greeting_match/start_rays.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 1186,
                        top: 572,
                        width: 56,
                        height: 64,
                        child: Transform.flip(
                          flipX: true,
                          child: _Enter(
                            delay: 700,
                            from: Offset.zero,
                            scale: 0.3,
                            curve: Curves.easeOutBack,
                            child: Image.asset(
                              'assets/images/greeting_match/start_rays.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      // Play Button with breathing pulse
                      Positioned(
                        left: 685,
                        top: 554,
                        width: 500,
                        height: 177,
                        child: AnimatedBuilder(
                          animation: _idleController,
                          builder: (context, child) {
                            final t = _idleController.value;
                            final pulseScale = _playDown
                                ? 0.94
                                : (1.0 + math.sin(t * 2 * math.pi) * 0.025);
                            return Transform.scale(
                              scale: pulseScale,
                              child: child,
                            );
                          },
                          child: _Enter(
                            delay: 560,
                            from: Offset.zero,
                            scale: 0.6,
                            duration: 600,
                            curve: Curves.easeOutBack,
                            child: GestureDetector(
                              key: const Key('greeting-match-play-btn'),
                              onTapDown: (_) => setState(() => _playDown = true),
                              onTapUp: (_) {
                                setState(() => _playDown = false);
                                _startGame();
                              },
                              onTapCancel: () =>
                                  setState(() => _playDown = false),
                              child: Image.asset(
                                _playDown
                                    ? 'assets/images/greeting_match/start_play_down.png'
                                    : 'assets/images/greeting_match/start_play.png',
                                fit: BoxFit.contain,
                              ),
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

  // ─── PLAY SCREEN ─────────────────────────────────────────────────────────────

  Widget _buildPlayScreen() {
    const double canvasW = 1870.0;
    const double canvasH = 841.0;
    final question = _question;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed scenario; gives a small cheer bounce on a correct answer.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: AnimatedBuilder(
            key: ValueKey(question.id),
            animation: _cheerController,
            builder: (context, child) {
              final t = _cheerController.value;
              return Transform.scale(
                scale: 1.0 + math.sin(t * math.pi) * 0.025,
                child: child,
              );
            },
            child: _Enter(
              duration: 900,
              from: Offset.zero,
              scale: 1.06,
              child: Image.asset(
                question.scenarioImage,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: canvasW,
                height: canvasH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 30,
                      top: 10,
                      child: _reveal(
                        _TitleBadge(title: widget.session.title),
                        dy: -0.4,
                      ),
                    ),
                    Positioned(
                      left: (canvasW - _StarsBar.widthFor(_questions.length)) / 2,
                      top: 18,
                      width: _StarsBar.widthFor(_questions.length),
                      height: 92,
                      child: _reveal(
                        _StarsBar(
                          total: _questions.length,
                          results: _results,
                        ),
                        dy: -0.6,
                      ),
                    ),
                    if (widget.onBack != null)
                      Positioned(
                        right: 32,
                        top: 14,
                        width: 110,
                        height: 110,
                        child: _homeButton(
                          const Key('greeting-home'),
                          widget.onBack!,
                        ),
                      ),
                    Positioned(
                      right: widget.onBack != null ? 162 : 32,
                      top: 14,
                      width: 110,
                      height: 110,
                      child: _musicButton(const Key('greeting-music')),
                    ),

                    // "Mumtaz!" badge over the scene on a correct answer.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 292,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _cheerController,
                          builder: (context, child) {
                            final t = _cheerController.value;
                            if (t == 0 || _correctIdx == null) {
                              return const SizedBox.shrink();
                            }
                            final e = Curves.easeOutQuart.transform(
                              (t * 2.5).clamp(0.0, 1.0),
                            );
                            return Opacity(
                              opacity: e,
                              child: Transform.scale(
                                scale: 0.7 + 0.3 * e,
                                child: child,
                              ),
                            );
                          },
                          child: const _MumtazBadge(),
                        ),
                      ),
                    ),

                    // Prompt card with the response buttons.
                    Positioned(
                      left: 290,
                      top: 484,
                      width: 1290,
                      height: 344,
                      child: _reveal(
                        _PromptCard(
                          question: question,
                          buttons: [
                            for (var i = 0; i < question.choices.length; i++)
                              Transform.translate(
                                offset: Offset(_wrongIdx == i ? _wobble : 0, 0),
                                child: _ChoiceButton(
                                  key: Key('greeting-choice-$i'),
                                  choice: question.choices[i],
                                  state: _correctIdx == i || _revealIdx == i
                                      ? _ChoiceState.correct
                                      : _wrongIdx == i
                                      ? _ChoiceState.wrong
                                      : _ChoiceState.idle,
                                  onTap: () => _handleChoice(i),
                                ),
                              ),
                          ],
                        ),
                        dy: 0.35,
                      ),
                    ),

                    // Play Audio pill straddling the card's top edge.
                    Positioned(
                      left: (canvasW - 430) / 2,
                      top: 424,
                      width: 430,
                      height: 96,
                      child: _reveal(
                        _GlossyButton(
                          key: const Key('greeting-play-audio'),
                          palette: _Palette.blue,
                          radius: 48,
                          depth: 8,
                          outline: Colors.white,
                          onTap: _playPrompt,
                          child: const _IconLabel(
                            icon: Icons.volume_up_rounded,
                            label: 'Play Audio',
                            color: Colors.white,
                          ),
                        ),
                        dy: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Face/edge colors for a glossy button: [top] and [bottom] shade the face,
/// [edge] is the extruded underside and outline.
class _Palette {
  const _Palette(this.top, this.bottom, this.edge);

  final Color top;
  final Color bottom;
  final Color edge;

  static const gold = _Palette(
    Color(0xFFFFE680),
    Color(0xFFFFBE2E),
    Color(0xFFC57F06),
  );
  static const blue = _Palette(
    Color(0xFF63BCFF),
    Color(0xFF1570E4),
    Color(0xFF0B469E),
  );
  static const green = _Palette(
    Color(0xFF7EE067),
    Color(0xFF2BAA35),
    Color(0xFF16701E),
  );
  static const red = _Palette(
    Color(0xFFFF8277),
    Color(0xFFE2372F),
    Color(0xFF9E1A17),
  );
}

/// Chunky cartoon button: an extruded [depth]-px underside, a vertical
/// gradient face with a glossy top highlight, and an optional [outline].
/// Sinks onto its underside while pressed.
class _GlossyButton extends StatefulWidget {
  const _GlossyButton({
    super.key,
    required this.palette,
    required this.radius,
    required this.child,
    this.depth = 8,
    this.outline,
    this.onTap,
  });

  final _Palette palette;
  final double radius;
  final double depth;
  final Color? outline;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_GlossyButton> createState() => _GlossyButtonState();
}

class _GlossyButtonState extends State<_GlossyButton> {
  bool _down = false;

  void _setDown(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final r = BorderRadius.circular(widget.radius);
    final sink = _down ? widget.depth * 0.75 : 0.0;
    final button = Stack(
      children: [
        // Extruded underside + ground shadow.
        Positioned.fill(
          top: widget.depth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: p.edge,
              borderRadius: r,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutQuart,
          left: 0,
          right: 0,
          top: sink,
          bottom: widget.depth - sink,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutQuart,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.top, p.bottom],
              ),
              border: Border.all(
                color: widget.outline ?? p.edge,
                width: widget.outline != null ? 5 : 4,
              ),
            ),
            child: Stack(
              children: [
                // Glossy highlight across the upper face.
                Positioned(
                  left: widget.radius * 0.35,
                  right: widget.radius * 0.35,
                  top: 6,
                  child: Container(
                    height: widget.radius * 0.62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.62),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(child: widget.child),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.onTap == null) return button;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapCancel: () => _setDown(false),
      onTapUp: (_) => _setDown(false),
      onTap: widget.onTap,
      child: button,
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: color,
              shadows: const [
                Shadow(color: Color(0x59000000), offset: Offset(0, 3)),
              ],
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontFamily: _kUiFont,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: color,
                shadows: const [
                  Shadow(color: Color(0x59000000), offset: Offset(0, 3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBadge extends StatelessWidget {
  const _TitleBadge({required this.title});

  final String title;

  /// Cartoon logotype: white outer halo, dark inner outline, solid fill.
  static Widget _word(String text, Color fill, Color line) {
    const style = TextStyle(
      fontFamily: _kUiFont,
      fontSize: 68,
      height: 1.0,
      fontWeight: FontWeight.w800,
    );
    Paint stroke(double w, Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: stroke(18, Colors.white),
            shadows: const [
              Shadow(
                color: Color(0x40000000),
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        Text(text, style: style.copyWith(foreground: stroke(7, line))),
        Text(text, style: style.copyWith(color: fill)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _word(
              'Greetings',
              const Color(0xFF26A146),
              const Color(0xFF0D5222),
            ),
            const SizedBox(width: 14),
            _word('Match', const Color(0xFFFF9A1F), const Color(0xFF9A4A00)),
          ],
        ),
        Transform.translate(
          offset: const Offset(0, -8),
          child: CustomPaint(
            painter: const _RibbonPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(64, 8, 64, 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: _kUiFont,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Color(0x80093A16), offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Green banner with folded-back swallowtail ends and a gold rim.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const tail = 34.0;
    const inset = 14.0;
    const fold = 10.0;
    const dark = Color(0xFF145E2A);
    const rim = Color(0xFFF2C94C);

    // Tails sit lower and behind the band.
    for (final left in [true, false]) {
      final x0 = left ? inset + tail : w - inset - tail;
      final xOut = left ? 0.0 : w;
      final notch = left ? tail * 0.45 : w - tail * 0.45;
      final path = Path()
        ..moveTo(x0, fold)
        ..lineTo(xOut, fold)
        ..lineTo(notch, fold + (h - fold) / 2)
        ..lineTo(xOut, h + fold)
        ..lineTo(x0, h + fold)
        ..close();
      canvas.drawPath(path, Paint()..color = dark);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..color = rim,
      );
    }

    final band = RRect.fromLTRBR(
      inset,
      0,
      w - inset,
      h,
      const Radius.circular(10),
    );
    canvas.drawRRect(
      band.shift(const Offset(0, 4)),
      Paint()..color = const Color(0x40000000),
    );
    canvas.drawRRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF36B257), Color(0xFF1C7A36)],
        ).createShader(band.outerRect),
    );
    canvas.drawRRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = rim,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StarsBar extends StatelessWidget {
  const _StarsBar({required this.total, required this.results});

  final int total;

  /// Room for the label at full size plus one 70px slot per star.
  static double widthFor(int total) => 330 + total * 70.0;

  /// Answered questions so far: true = gold, false = red; the rest empty.
  final List<bool> results;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 32, right: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFFFF6DE)],
        ),
        borderRadius: BorderRadius.circular(42),
        border: Border.all(color: const Color(0xFFE9C766), width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Greeting Stars',
                style: TextStyle(
                  fontFamily: _kUiFont,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          for (var i = 0; i < total; i++)
            TweenAnimationBuilder<double>(
              key: Key('greeting-star-$i-${_StarKind.of(results, i).name}'),
              tween: Tween(begin: i < results.length ? 0.55 : 1.0, end: 1.0),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _StarImage(kind: _StarKind.of(results, i), size: 64),
              ),
            ),
        ],
      ),
    );
  }
}

enum _StarKind {
  gold,
  red,
  empty;

  static _StarKind of(List<bool> results, int i) => i >= results.length
      ? empty
      : results[i]
      ? gold
      : red;
}

/// The Greeting Star art: gold (right), red (wrong), grey (not yet / not
/// earned).
class _StarImage extends StatelessWidget {
  const _StarImage({required this.kind, required this.size});

  final _StarKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/greeting_match/star_${kind.name}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.question, required this.buttons});

  final GreetingQuestion question;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE9D3A0),
        borderRadius: BorderRadius.circular(48),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(26, 46, 26, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF6), Color(0xFFFBF1DA)],
          ),
          borderRadius: BorderRadius.circular(42),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Column(
          children: [
            Text(
              question.arabic,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: _kArabicFont,
                fontSize: 54,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E1D0B),
              ),
            ),
            Text(
              '(${question.meaning.tr})',
              style: const TextStyle(
                fontFamily: _kUiFont,
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B4A22),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 30),
                    Expanded(child: buttons[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.choice,
    required this.state,
    required this.onTap,
  });

  final GreetingChoice choice;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (palette, ink, shadow) = switch (state) {
      _ChoiceState.correct => (
        _Palette.green,
        Colors.white,
        const Color(0x800B4A12),
      ),
      _ChoiceState.wrong => (
        _Palette.red,
        Colors.white,
        const Color(0x806E0E0B),
      ),
      _ChoiceState.idle => (
        _Palette.gold,
        const Color(0xFF4A2A05),
        const Color(0x66FFFFFF),
      ),
    };
    final shadows = [Shadow(color: shadow, offset: const Offset(0, 2))];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: _GlossyButton(
            palette: palette,
            radius: 34,
            depth: 9,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      choice.arabic,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: _kArabicFont,
                        fontSize: 52,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        shadows: shadows,
                      ),
                    ),
                    Text(
                      '(${choice.meaning.tr})',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _kUiFont,
                        fontSize: 32,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: ink,
                        shadows: shadows,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Check / cross so the result never relies on colour alone.
        if (state != _ChoiceState.idle)
          Positioned(
            right: -10,
            top: -14,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: palette.edge, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                state == _ChoiceState.correct
                    ? Icons.check_rounded
                    : Icons.close_rounded,
                size: 42,
                color: palette.bottom,
              ),
            ),
          ),
      ],
    );
  }
}

class _MumtazBadge extends StatelessWidget {
  const _MumtazBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/greeting_match/start_rays.png',
          width: 58,
          height: 66,
        ),
        const SizedBox(width: 8),
        const SizedBox(
          width: 360,
          height: 104,
          child: _GlossyButton(
            palette: _Palette.gold,
            radius: 52,
            depth: 8,
            outline: Colors.white,
            child: _IconLabel(
              icon: Icons.star_rounded,
              label: 'Mumtaz!',
              color: Color(0xFF6E3A08),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Transform.flip(
          flipX: true,
          child: Image.asset(
            'assets/images/greeting_match/start_rays.png',
            width: 58,
            height: 66,
          ),
        ),
      ],
    );
  }
}

/// Soft blurred oval that grounds a standing mascot on the floor.
class _FloorShadow extends StatelessWidget {
  const _FloorShadow();

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 6),
      child: const DecoratedBox(
        decoration: ShapeDecoration(
          shape: OvalBorder(),
          color: Color(0x963A2410),
        ),
      ),
    );
  }
}

// Home / Back / Music image buttons (art: assets/images/greeting_match/
// btn_<name>_up.png and _down.png, swapped while pressed).
Widget _homeButton(Key key, VoidCallback onTap) => _Enter(
  delay: 450,
  from: Offset.zero,
  scale: 0.7,
  curve: Curves.easeOutBack,
  child: _ImageButton(key: key, name: 'home', onTap: onTap),
);

Widget _backButton(Key key, VoidCallback onTap) => _Enter(
  delay: 450,
  from: Offset.zero,
  scale: 0.7,
  curve: Curves.easeOutBack,
  child: _ImageButton(key: key, name: 'back', onTap: onTap),
);

class _ImageButton extends StatefulWidget {
  const _ImageButton({super.key, required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  State<_ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<_ImageButton> {
  bool _down = false;

  void _setDown(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final state = _down ? 'down' : 'up';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapCancel: () => _setDown(false),
      onTapUp: (_) => _setDown(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutQuart,
        child: Image.asset(
          'assets/images/greeting_match/btn_${widget.name}_$state.png',
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class _MutedSlashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final a = Offset(size.width * 0.24, size.height * 0.24);
    final b = Offset(size.width * 0.76, size.height * 0.76);
    canvas.drawLine(
      a,
      b,
      paint
        ..color = Colors.white
        ..strokeWidth = size.width * 0.13,
    );
    canvas.drawLine(
      a,
      b,
      paint
        ..color = const Color(0xFFE2372F)
        ..strokeWidth = size.width * 0.08,
    );
  }

  @override
  bool shouldRepaint(_MutedSlashPainter oldDelegate) => false;
}

/// How to Play step: numbered cream card with a glossy icon disc.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.palette,
    required this.title,
    required this.text,
  });

  final int number;
  final IconData icon;
  final _Palette palette;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: _CreamCard(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
            child: Column(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: _GlossyButton(
                    palette: palette,
                    radius: 75,
                    depth: 8,
                    outline: Colors.white,
                    child: Icon(
                      icon,
                      size: 84,
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Color(0x59000000), offset: Offset(0, 3)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: _kUiFont,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _kUiFont,
                      fontSize: 29,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B4A22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: -14,
          top: -18,
          width: 76,
          height: 76,
          child: _GlossyButton(
            palette: _Palette.gold,
            radius: 38,
            depth: 6,
            outline: Colors.white,
            child: Text(
              '$number',
              style: const TextStyle(
                fontFamily: _kUiFont,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6E3A08),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Parchment card used by the prompt, How to Play and results panels.
class _CreamCard extends StatelessWidget {
  const _CreamCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE9D3A0),
        borderRadius: BorderRadius.circular(48),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF6), Color(0xFFFBF1DA)],
          ),
          borderRadius: BorderRadius.circular(42),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: child,
      ),
    );
  }
}

/// Ending summary: star rating, round stats and every greeting pair the
/// learner matched (prompt -> reply, with the reply's meaning).
class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.rating,
    required this.results,
    required this.accuracyPct,
    required this.xp,
    required this.questions,
  });

  final int rating;
  final List<bool> results;
  final double accuracyPct;
  final int xp;
  final List<GreetingQuestion> questions;

  @override
  Widget build(BuildContext context) {
    return _CreamCard(
      padding: const EdgeInsets.fromLTRB(34, 18, 34, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                _Enter(
                  delay: 700 + i * 200,
                  duration: 600,
                  from: Offset.zero,
                  scale: 0.2,
                  curve: Curves.elasticOut,
                  child: Padding(
                    key: Key('greeting-end-star-$i-${i < rating ? 'on' : 'off'}'),
                    padding: EdgeInsets.fromLTRB(8, i == 1 ? 0 : 14, 8, 0),
                    child: _StarImage(
                      kind: i < rating ? _StarKind.gold : _StarKind.empty,
                      size: i == 1 ? 104 : 84,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'You got ${results.where((r) => r).length} of ${questions.length} right!',
              style: const TextStyle(
                fontFamily: _kUiFont,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatPill(
                icon: Icons.track_changes_rounded,
                label: 'Accuracy ${accuracyPct.round()}%',
              ),
              const SizedBox(width: 16),
              _StatPill(icon: Icons.bolt_rounded, label: '+$xp XP'),
            ],
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Greetings you learned',
              style: TextStyle(
                fontFamily: _kUiFont,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A5A1E),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: questions.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 6, color: Color(0xFFEBD9AE)),
              itemBuilder: (_, i) {
                final q = questions[i];
                final reply = q.choices.firstWhere((c) => c.correct);
                return Row(
                  key: Key('greeting-end-row-$i'),
                  children: [
                    _StarImage(
                      kind: _StarKind.of(results, i),
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          q.arabic,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontFamily: _kArabicFont,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E1D0B),
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 30,
                        color: Color(0xFF2BAA35),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: reply.arabic,
                                style: const TextStyle(
                                  fontFamily: _kArabicFont,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16701E),
                                ),
                              ),
                              TextSpan(
                                text: '  (${reply.meaning.tr})',
                                style: const TextStyle(
                                  fontFamily: _kUiFont,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B4A22),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1C9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9C766), width: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: const Color(0xFFC06A00)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: _kUiFont,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// Entrance motion: fades in while easing from [from] (a fraction of the
/// child's own size) and [scale] to rest, after [delay] ms. Plays once per
/// element, so it runs when its screen (or keyed parent) appears. Skipped
/// when the device asks to reduce motion.
class _Enter extends StatefulWidget {
  const _Enter({
    super.key,
    required this.child,
    this.delay = 0,
    this.duration = 550,
    this.from = const Offset(0, 0.2),
    this.scale = 1,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final int delay;
  final int duration;
  final Offset from;
  final double scale;
  final Curve curve;

  @override
  State<_Enter> createState() => _EnterState();
}

class _EnterState extends State<_Enter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.duration),
  );
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _start?.cancel();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = widget.curve.transform(_c.value);
        final fade = Curves.easeOut.transform((_c.value * 1.8).clamp(0.0, 1.0));
        return Opacity(
          opacity: fade,
          child: FractionalTranslation(
            translation: widget.from * (1 - t),
            child: Transform.scale(
              scale: widget.scale + (1 - widget.scale) * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
