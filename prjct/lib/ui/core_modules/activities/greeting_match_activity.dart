import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';

/// One (fill, border, avatar-circle) tint set per grid position — a fixed
/// color per position (not per correctness), matching the classic
/// A/B/C/D quiz-tile convention.
const _choiceTints = [
  (fill: AppColors.mint, border: AppColors.adventureGreen),
  (fill: Color(0xFFE1F1FB), border: AppColors.adventureBlue),
  (fill: Color(0xFFEDEBFB), border: AppColors.adventurePurple),
  (fill: AppColors.goldTint, border: AppColors.gold),
];

/// Greeting Match Home Mode: play a greeting phrase, tap the choice with
/// its correct meaning among 3 other real (but wrong) greeting phrases.
/// Wrong taps wobble and allow a retry on the same question — no penalty
/// beyond the accuracy/error count reported to [onComplete]. Correct taps
/// flash green and auto-advance.
///
/// Plain/default styling for now — this is a structural pass; the visual
/// design (colors, illustrations, animation) is a follow-up once the
/// project owner provides the asset pack.
class GreetingMatchActivity extends StatefulWidget {
  const GreetingMatchActivity({
    super.key,
    required this.questions,
    required this.xp,
    required this.color,
    required this.onComplete,
  });

  final List<GreetingQuestion> questions;
  final int xp;
  final Color color;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  @override
  State<GreetingMatchActivity> createState() => _GreetingMatchActivityState();
}

class _GreetingMatchActivityState extends State<GreetingMatchActivity>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  bool _answeredCorrectly = false;
  int _correctCount = 0;
  int _errors = 0;
  double _wobble = 0.0;
  late final AnimationController _wobbleController;

  GreetingQuestion get _question => widget.questions[_idx];

  @override
  void initState() {
    super.initState();
    _wobbleController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addListener(() {
          final t = _wobbleController.value;
          setState(() {
            _wobble = math.sin(t * math.pi * 3) * 8 * (1 - t);
          });
        });
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  // FIREBASE/HIVE PLUG POINT: plays widget.audioAsset once real greeting
  // recordings exist; currently a no-op since audio is placeholder-phase
  // (see GreetingQuestion.audioAsset doc).
  void _playPhrase() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔊 "${_question.phrase}"',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
        backgroundColor: widget.color,
      ),
    );
  }

  void _handleChoice(GreetingChoice choice) {
    if (_answeredCorrectly) return;
    if (choice.correct) {
      setState(() {
        _answeredCorrectly = true;
        _correctCount++;
      });
      Future.delayed(const Duration(milliseconds: 650), _next);
    } else {
      setState(() => _errors++);
      _wobbleController.forward(from: 0);
    }
  }

  void _next() {
    if (!mounted) return;
    if (_idx + 1 >= widget.questions.length) {
      final totalAttempts = _correctCount + _errors;
      final accuracyPct = totalAttempts == 0
          ? 100.0
          : _correctCount / totalAttempts * 100;
      widget.onComplete(widget.xp, accuracyPct, _errors);
    } else {
      setState(() {
        _idx++;
        _answeredCorrectly = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            'assets/images/greeting_match/greeting_match_bg.png',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Padding(
          // Extra top padding clears the lesson player's floating close
          // button, which floats over this edge-to-edge background rather
          // than reserving its own bar (see `LessonPlayerScreen`'s
          // `ActivityType.pronounce` case).
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.questions.length; i++) ...[
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
              const SizedBox(height: 14),
              Text(
                'Greeting Match',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Listen, then tap what it means',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(_wobble, 0),
                    child: GestureDetector(
                      onTap: _playPhrase,
                      child: Container(
                        width: 300,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 34,
                          vertical: 26,
                        ),
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(
                              'assets/images/greeting_match/phrase_scroll_bg.png',
                            ),
                            fit: BoxFit.fill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔊', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _question.phrase,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: widget.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Choices pinned to the bottom of the screen, wide 2x2 cards
              // (avatar circle + bold title), fixed height so this stays a
              // sane size on both phone-narrow and wide/test viewports.
              SizedBox(
                height: 200,
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.5,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < _question.choices.length; i++)
                      _ChoiceCard(
                        tint: _choiceTints[i % _choiceTints.length],
                        choice: _question.choices[i],
                        revealed:
                            _answeredCorrectly && _question.choices[i].correct,
                        onTap: () => _handleChoice(_question.choices[i]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One answer choice — a wide tinted card with a left avatar circle and
/// bold title, matching the reference layout (2x2 grid, mascot-in-a-circle
/// + colored bold text). No illustration assets yet, so the circle just
/// holds a placeholder wave emoji — swap for real per-choice art later.
/// Ripple + haptic tap feedback; when [revealed] (this choice is the
/// correct one and the question's been answered), it gets a green
/// checkmark badge and a slight pop.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.tint,
    required this.choice,
    required this.revealed,
    required this.onTap,
  });

  final ({Color fill, Color border}) tint;
  final GreetingChoice choice;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: revealed ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tint.fill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tint.border, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: tint.border, width: 2),
                  ),
                  child: const Text('👋', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    choice.translit,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: tint.border,
                    ),
                  ),
                ),
                if (revealed)
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.adventureGreen,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
