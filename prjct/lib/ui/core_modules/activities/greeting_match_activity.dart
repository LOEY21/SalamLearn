import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/soft_card.dart';

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
    _wobbleController = AnimationController(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
          const SizedBox(height: 18),
          Transform.translate(
            offset: Offset(_wobble, 0),
            child: GestureDetector(
              onTap: _playPhrase,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.color, width: 2.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔊', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      _question.phrase,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _question.choices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final choice = _question.choices[i];
                final revealed = _answeredCorrectly && choice.correct;
                return SoftCard(
                  color: revealed ? AppColors.mint : AppColors.surface,
                  borderColor: revealed ? AppColors.adventureGreen : null,
                  onTap: () => _handleChoice(choice),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              choice.translit,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              choice.meaning,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (revealed)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.adventureGreen,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
