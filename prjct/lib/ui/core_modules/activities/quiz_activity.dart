import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';

enum _QuizState { answering, correct, wrong }

/// Ported from Wireframe 0.3's `QuizActivity.tsx` — hearts + question
/// counter, a question card with correct/wrong feedback coloring, a 2x2
/// answer grid, and a Next/Finish button.
///
/// Simplification: the source defines `shake`/`popCorrect`/
/// `confettiBurst` keyframes for the question card on answer. These are
/// skipped in favor of the plain color/border state change (no motion) —
/// the state machine and feedback colors are ported exactly, but the
/// shake/pop punch itself is not.
class QuizActivity extends StatefulWidget {
  const QuizActivity({
    super.key,
    required this.questions,
    required this.xp,
    required this.color,
    required this.onComplete,
  });

  final List<QuizQ> questions;
  final int xp;
  final Color color;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  @override
  State<QuizActivity> createState() => _QuizActivityState();
}

class _QuizActivityState extends State<QuizActivity> {
  static const _optionColors = [
    AppColors.coral,
    Color(0xFF2A7FCC),
    AppColors.adventureGreen,
    AppColors.adventurePurple,
  ];

  int _qi = 0;
  int? _selected;
  _QuizState _state = _QuizState.answering;
  int _hearts = 3;
  int _score = 0;
  int _errors = 0;

  QuizQ get _q => widget.questions[_qi];

  static final _arabicRe = RegExp(r'[؀-ۿ]');

  String _optionLabel(String opt) => opt.replaceAll(' ✓', '');

  void _handleAnswer(int optIdx) {
    if (_state != _QuizState.answering) return;
    setState(() {
      _selected = optIdx;
      if (optIdx == _q.correct) {
        _state = _QuizState.correct;
        _score += 1;
      } else {
        _state = _QuizState.wrong;
        _hearts = math.max(0, _hearts - 1);
        _errors += 1;
      }
    });
  }

  void _handleNext() {
    if (_qi + 1 >= widget.questions.length) {
      final correctCount =
          _score + (_state == _QuizState.correct ? 1 : 0);
      final finalXp =
          (widget.xp * correctCount / widget.questions.length).round();
      final accuracyPct = correctCount / widget.questions.length * 100;
      widget.onComplete(
        math.max((widget.xp * 0.4).round(), finalXp),
        accuracyPct,
        _errors,
      );
    } else {
      setState(() {
        _qi += 1;
        _selected = null;
        _state = _QuizState.answering;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _qi + 1 >= widget.questions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Hearts + progress.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i != 0) const SizedBox(width: 4),
                    Opacity(
                      opacity: i < _hearts ? 1 : 0.25,
                      child: const Text('❤️', style: TextStyle(fontSize: 22)),
                    ),
                  ],
                ],
              ),
              Text(
                'Question ${_qi + 1} / ${widget.questions.length}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Question card.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: _state == _QuizState.correct
                  ? const Color(0xFFDCF0E6)
                  : _state == _QuizState.wrong
                  ? const Color(0xFFFDDCCC)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _state == _QuizState.correct
                    ? AppColors.adventureGreen
                    : _state == _QuizState.wrong
                    ? AppColors.coral
                    : const Color(0xFFF0EDE8),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _state == _QuizState.correct
                      ? AppColors.adventureGreen.withAlpha(0x44)
                      : _state == _QuizState.wrong
                      ? AppColors.coral.withAlpha(0x44)
                      : Colors.black.withValues(alpha: 0.07),
                  offset: _state == _QuizState.answering
                      ? const Offset(0, 4)
                      : const Offset(0, 6),
                  blurRadius: _state == _QuizState.answering ? 16 : 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _q.emoji,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 64,
                    height: 1,
                    fontFamily: _q.emoji.length > 2 ? 'Cairo' : null,
                    fontWeight: _q.emoji.length > 2 ? FontWeight.w700 : null,
                  ),
                ),
                const SizedBox(height: 12),
                if (_state == _QuizState.correct)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('✅', style: TextStyle(fontSize: 36)),
                  ),
                if (_state == _QuizState.wrong)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('❌', style: TextStyle(fontSize: 36)),
                  ),
                Text(
                  _q.question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                    height: 1.3,
                  ),
                ),
                if (_q.questionAr != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _q.questionAr!,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
                if (_state == _QuizState.correct) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Mabrook! مَبْرُوك! 🌟',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.adventureGreen,
                    ),
                  ),
                  if (_q.tip != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _q.tip!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
                if (_state == _QuizState.wrong && _selected != null) ...[
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        color: AppColors.coral,
                      ),
                      children: [
                        const TextSpan(text: 'The right answer is: '),
                        TextSpan(
                          text: _optionLabel(_q.options[_q.correct]),
                          style: const TextStyle(fontFamily: 'Fredoka'),
                        ),
                      ],
                    ),
                  ),
                  if (_q.tip != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _q.tip!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Answer options / answered state.
          Expanded(
            child: SingleChildScrollView(
              child: _state == _QuizState.answering
                  ? _buildOptionsGrid()
                  : _buildAnsweredGrid(),
            ),
          ),
          if (_state != _QuizState.answering) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _handleNext,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _state == _QuizState.correct
                        ? AppColors.adventureGreen
                        : AppColors.gold,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _state == _QuizState.correct
                          ? AppColors.adventureGreen
                          : AppColors.gold,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_state == _QuizState.correct
                                    ? AppColors.adventureGreen
                                    : AppColors.gold)
                                .withAlpha(0x88),
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    isLast ? '✓ Finish!' : 'Next Question →',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return _grid(
      List.generate(_q.options.length, (i) {
        final label = _optionLabel(_q.options[i]);
        final isArabic = _arabicRe.hasMatch(label);
        final optColor = _optionColors[i % _optionColors.length];
        return GestureDetector(
          onTap: () => _handleAnswer(i),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: optColor.withAlpha(0x22),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: optColor.withAlpha(0x55), width: 3),
              boxShadow: [
                BoxShadow(
                  color: optColor.withAlpha(0x33),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontFamily: isArabic ? 'Cairo' : 'Fredoka',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF222222),
                height: 1.2,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAnsweredGrid() {
    return _grid(
      List.generate(_q.options.length, (i) {
        final isCorrect = i == _q.correct;
        final isSelected = i == _selected;
        final label = _optionLabel(_q.options[i]);
        final isArabic = _arabicRe.hasMatch(label);
        return Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCorrect
                ? const Color(0xFF5B9A1E).withAlpha(0x22)
                : (isSelected && !isCorrect)
                ? AppColors.coral.withAlpha(0x22)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCorrect
                  ? AppColors.adventureGreen
                  : isSelected
                  ? AppColors.coral
                  : const Color(0xFFE0E0E0),
              width: 3,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCorrect || isSelected)
                Text(
                  isCorrect ? '✓ ' : '✗ ',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCorrect
                        ? AppColors.adventureGreen
                        : AppColors.coral,
                  ),
                ),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  textDirection: isArabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Fredoka',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCorrect
                        ? AppColors.adventureGreen
                        : isSelected
                        ? AppColors.coral
                        : const Color(0xFFAAAAAA),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _grid(List<Widget> tiles) {
    return Column(
      children: [
        for (var row = 0; row < tiles.length; row += 2) ...[
          if (row != 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: tiles[row]),
              if (row + 1 < tiles.length) ...[
                const SizedBox(width: 10),
                Expanded(child: tiles[row + 1]),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
