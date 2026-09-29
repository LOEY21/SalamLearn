import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';
import 'greeting_match_audio.dart';

enum _Screen { start, play }

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
  int _correctCount = 0;
  int _errors = 0;
  double _wobble = 0.0;
  bool _playDown = false;
  int? _correctIdx;
  int? _wrongIdx;
  Timer? _wrongTimer;
  Timer? _nextTimer;
  Timer? _promptTimer;
  Timer? _revealTimer;

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
    _wobbleController.dispose();
    _idleController.dispose();
    _cheerController.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  void _startGame() {
    _idleController.stop();
    HapticFeedback.mediumImpact();
    setState(() => _screen = _Screen.play);
    _queuePrompt();
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

  void _handleChoice(int i) {
    if (_correctIdx != null || !_revealed) return;
    final choice = _question.choices[i];
    if (choice.correct) {
      HapticFeedback.lightImpact();
      _wrongTimer?.cancel();
      setState(() {
        _correctIdx = i;
        _wrongIdx = null;
        _correctCount++;
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
      setState(() {
        _errors++;
        _wrongIdx = i;
      });
      if (!MediaQuery.of(context).disableAnimations) {
        _wobbleController.forward(from: 0);
      }
      unawaited(_audio.play([GreetingMatchAudio.tryAgain]));
      _wrongTimer?.cancel();
      _wrongTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _wrongIdx = null);
      });
    }
  }

  void _next() {
    if (!mounted) return;
    if (_idx + 1 >= _questions.length) {
      final totalAttempts = _correctCount + _errors;
      final accuracyPct = totalAttempts == 0
          ? 100.0
          : _correctCount / totalAttempts * 100;
      widget.onComplete(widget.xp, accuracyPct, _errors);
    } else {
      setState(() {
        _idx++;
        _correctIdx = null;
        _wrongIdx = null;
      });
      _queuePrompt();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_screen == _Screen.start) {
      return _buildStartScreen();
    }
    return _buildPlayScreen();
  }

  // ─── START SCREEN ────────────────────────────────────────────────────────────

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

                      // Back Button (if provided)
                      if (widget.onBack != null)
                        Positioned(
                          top: 24,
                          left: 24,
                          child: GestureDetector(
                            onTap: widget.onBack,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.creamBorder,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                size: 30,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
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
                        child: Image.asset(
                          'assets/images/greeting_match/start_girl.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        left: 1165,
                        top: 253,
                        width: 413,
                        height: 550,
                        child: Image.asset(
                          'assets/images/greeting_match/start_boy.png',
                          fit: BoxFit.contain,
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
                            child: child!,
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

                      // Ray bursts either side of Play
                      Positioned(
                        left: 628,
                        top: 572,
                        width: 56,
                        height: 64,
                        child: Image.asset(
                          'assets/images/greeting_match/start_rays.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        left: 1186,
                        top: 572,
                        width: 56,
                        height: 64,
                        child: Transform.flip(
                          flipX: true,
                          child: Image.asset(
                            'assets/images/greeting_match/start_rays.png',
                            fit: BoxFit.contain,
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
            child: Image.asset(
              question.scenarioImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
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
                      left: (canvasW - 640) / 2,
                      top: 20,
                      width: 640,
                      height: 84,
                      child: _reveal(
                        _StarsBar(
                          total: _questions.length,
                          earned: _correctCount,
                        ),
                        dy: -0.6,
                      ),
                    ),
                    if (widget.onBack != null)
                      Positioned(
                        right: 32,
                        top: 14,
                        width: 104,
                        height: 104,
                        child: _GlossyButton(
                          key: const Key('greeting-home'),
                          palette: _Palette.gold,
                          radius: 52,
                          depth: 7,
                          outline: Colors.white,
                          onTap: widget.onBack,
                          child: const Icon(
                            Icons.home_rounded,
                            size: 58,
                            color: Color(0xFF6E3A08),
                          ),
                        ),
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
                                  state: _correctIdx == i
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
  const _StarsBar({required this.total, required this.earned});

  final int total;
  final int earned;

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
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Greeting Stars',
                style: TextStyle(
                  fontFamily: _kUiFont,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
            ),
          ),
          const Spacer(),
          for (var i = 0; i < total; i++)
            TweenAnimationBuilder<double>(
              key: Key('greeting-star-$i-${i < earned ? 'on' : 'off'}'),
              tween: Tween(begin: i < earned ? 0.55 : 1.0, end: 1.0),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutQuart,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: CustomPaint(
                  size: const Size(62, 62),
                  painter: _StarPainter(filled: i < earned),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rounded five-point star: gold with a gloss when [filled], stone grey
/// otherwise.
class _StarPainter extends CustomPainter {
  const _StarPainter({required this.filled});

  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.53);
    final outer = size.width * 0.46;
    final inner = outer * 0.5;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();

    final bounds = path.getBounds();
    final line = filled ? const Color(0xFFC06A00) : const Color(0xFF8F8878);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 7
      ..color = line;
    canvas.drawPath(path.shift(const Offset(0, 3)), stroke);
    canvas.drawPath(path, stroke);
    canvas.drawPath(
      path,
      Paint()
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: filled
              ? const [Color(0xFFFFEE70), Color(0xFFFFB400)]
              : const [Color(0xFFE4E0D6), Color(0xFFB8B2A4)],
        ).createShader(bounds),
    );
    if (filled) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(-outer * 0.22, -outer * 0.3),
          width: outer * 0.36,
          height: outer * 0.2,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.filled != filled;
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
