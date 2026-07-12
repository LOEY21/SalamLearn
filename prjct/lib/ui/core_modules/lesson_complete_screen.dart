import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/curriculum/curriculum_models.dart';
import '../theme/app_colors.dart';

class _Celebration {
  const _Celebration({
    required this.top,
    required this.ar,
    required this.sub,
    required this.ar2,
  });

  final String top;
  final String ar;
  final String sub;
  final String ar2;
}

/// Ported verbatim from Wireframe 0.3's `LessonComplete.tsx` `CELEBRATIONS`
/// — short original celebration phrases the project owner wrote for their
/// own app.
const _celebrations = <_Celebration>[
  _Celebration(
    top: 'Mabrook! 🎉',
    ar: 'مَبْرُوك!',
    sub: 'You aced it!',
    ar2: 'أتقنتها!',
  ),
  _Celebration(
    top: 'Amazing! 🌟',
    ar: 'رَائِع!',
    sub: 'Keep going, superstar!',
    ar2: 'واصل يا نجم!',
  ),
  _Celebration(
    top: 'Masha Allah! ✨',
    ar: 'مَا شَاءَ اللّٰه!',
    sub: 'You are unstoppable!',
    ar2: 'لا يوقفك شيء!',
  ),
  _Celebration(
    top: 'Wonderful! 🏆',
    ar: 'رَائِع جِدًّا!',
    sub: "You're on a roll!",
    ar2: 'أنت في تقدّم مستمر!',
  ),
];

const _confettiEmoji = ['⭐', '🌟', '✨', '💫', '🎉', '🎊'];

/// Parses the model's `#RRGGBB` hex strings into a [Color] — same
/// convention as `destination_levels_sheet.dart`'s `_hexColor`.
Color _hexColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

/// Ported from Wireframe 0.3's `LessonComplete.tsx` — full-screen
/// celebration shown after a lesson's last activity finishes: a floating
/// star/confetti background, a gently-floating trophy, the lesson's icon
/// in a translucent badge, a randomly-picked (held-for-lifetime)
/// celebration headline, a "Lesson Complete" badge card, an XP-earned
/// pill, and a Continue button.
///
/// Simplification: the source staggers each of its 12 confetti stars on
/// its own CSS `starFloat` keyframe (per-item duration/delay). Here a
/// single repeating [AnimationController] drives all 12 via a phase
/// offset (`i / 12`) instead of 12 independent timers — visually
/// equivalent staggered looping motion, not pixel-exact per the task
/// brief.
class LessonCompleteScreen extends StatefulWidget {
  const LessonCompleteScreen({
    super.key,
    required this.lesson,
    required this.xpEarned,
    required this.onContinue,
  });

  final Lesson lesson;
  final int xpEarned;
  final VoidCallback onContinue;

  @override
  State<LessonCompleteScreen> createState() => _LessonCompleteScreenState();
}

class _LessonCompleteScreenState extends State<LessonCompleteScreen>
    with TickerProviderStateMixin {
  late final _Celebration _celebration =
      _celebrations[math.Random().nextInt(_celebrations.length)];

  late final AnimationController _confettiController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  late final AnimationController _trophyController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _confettiController.dispose();
    _trophyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonColor = _hexColor(widget.lesson.color);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lessonColor, AppColors.teal],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  for (var i = 0; i < 12; i++)
                    _buildConfettiStar(i, constraints),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 32,
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTrophy(),
                            const SizedBox(height: 6),
                            _buildLessonIcon(),
                            const SizedBox(height: 20),
                            Text(
                              _celebration.top,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    color: Color(0x33000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _celebration.ar,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_celebration.sub} · ${_celebration.ar2}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(height: 28),
                            _buildLessonCompleteBadge(),
                            const SizedBox(height: 28),
                            _buildXpPill(),
                            const SizedBox(height: 28),
                            _buildContinueButton(lessonColor),
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
      ),
    );
  }

  Widget _buildConfettiStar(int i, BoxConstraints constraints) {
    final left = constraints.maxWidth * ((8 + (i * 8.5) % 90) / 100);
    final baseBottom = constraints.maxHeight * ((10 + (i * 13) % 50) / 100);

    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, child) {
        final phase = (_confettiController.value + i / 12) % 1.0;
        return Positioned(
          left: left,
          bottom: baseBottom + phase * 100,
          child: Opacity(
            opacity: (1 - phase) * 0.8,
            child: Transform.rotate(angle: phase * 2 * math.pi, child: child),
          ),
        );
      },
      child: Text(
        _confettiEmoji[i % _confettiEmoji.length],
        style: TextStyle(fontSize: 18.0 + (i % 3) * 8),
      ),
    );
  }

  Widget _buildTrophy() {
    return AnimatedBuilder(
      animation: _trophyController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -12 * _trophyController.value),
          child: child,
        );
      },
      child: const Text('🏆', style: TextStyle(fontSize: 90)),
    );
  }

  Widget _buildLessonIcon() {
    return Container(
      width: 70,
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 3,
        ),
      ),
      child: Text(widget.lesson.icon, style: const TextStyle(fontSize: 38)),
    );
  }

  Widget _buildLessonCompleteBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'LESSON COMPLETE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.lesson.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              widget.lesson.titleAr,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Text(
            '+${widget.xpEarned} XP',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(Color lessonColor) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: widget.onContinue,
        child: Container(
          padding: const EdgeInsets.all(18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x26000000), offset: Offset(0, 6)),
            ],
          ),
          child: Text(
            'Continue → Next Lesson!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: lessonColor,
            ),
          ),
        ),
      ),
    );
  }
}
