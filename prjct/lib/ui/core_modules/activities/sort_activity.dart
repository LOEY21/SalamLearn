import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

class _DoneEntry {
  const _DoneEntry(this.item, this.correct);
  final SortItem item;
  final bool correct;
}

/// Ported from Wireframe 0.3's `SortActivity.tsx` — bucket-sorting
/// activity: a shuffled queue of items, sort each into `bucketA`
/// (`SortItem.bucket == 0`) or `bucketB` (`bucket == 1`), with a streak
/// counter and a recent-results strip.
///
/// Simplification: the source's `correctPop`/`wrongWobble` keyframes are
/// skipped — the current-item card only swaps color/border/emoji-overlay
/// on feedback, with no scale-pop or rotate-wobble motion.
class SortActivity extends StatefulWidget {
  const SortActivity({
    super.key,
    required this.items,
    required this.bucketA,
    required this.bucketB,
    required this.xp,
    required this.color,
    required this.onComplete,
  });

  final List<SortItem> items;
  final String bucketA;
  final String bucketB;
  final int xp;
  final Color color;
  final void Function(int xp) onComplete;

  @override
  State<SortActivity> createState() => _SortActivityState();
}

class _SortActivityState extends State<SortActivity> {
  late List<SortItem> _queue;
  final List<_DoneEntry> _done = [];
  String? _feedback; // 'correct' | 'wrong' | null
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    final shuffled = List<SortItem>.of(widget.items);
    final rnd = math.Random();
    for (var i = shuffled.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = tmp;
    }
    _queue = shuffled;
  }

  SortItem? get _current => _queue.isNotEmpty ? _queue.first : null;

  void _handleSort(int bucket) {
    final current = _current;
    if (current == null || _feedback != null) return;
    final isCorrect = current.bucket == bucket;
    final queueLenAtCall = _queue.length;
    final doneCorrectAtCall = _done.where((d) => d.correct).length;

    setState(() {
      _feedback = isCorrect ? 'correct' : 'wrong';
      _streak = isCorrect ? _streak + 1 : 0;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _done.add(_DoneEntry(current, isCorrect));
        _queue.removeAt(0);
        _feedback = null;
      });
      if (queueLenAtCall <= 1) {
        final correctCount = doneCorrectAtCall + (isCorrect ? 1 : 0);
        final earned = (widget.xp * correctCount / widget.items.length).round();
        widget.onComplete(math.max((widget.xp * 0.4).round(), earned));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    if (current == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎊', style: TextStyle(fontSize: 72)),
              SizedBox(height: 12),
              Text(
                'All sorted! Finishing up... ⭐',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F6E56),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Progress bar.
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        Container(color: const Color(0xFFF0EDE8)),
                        FractionallySizedBox(
                          widthFactor: _done.length / widget.items.length,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [widget.color, const Color(0xFF5B9A1E)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_done.length}/${widget.items.length}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: Color(0xFFAAAAAA),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_streak >= 3) ...[
                const SizedBox(width: 8),
                Text(
                  '🔥 $_streak!',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 14,
                    color: Color(0xFFEF9F27),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Current card.
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _feedback == 'correct'
                    ? const Color(0xFFDCF0E6)
                    : _feedback == 'wrong'
                    ? const Color(0xFFFDDCCC)
                    : Colors.white,
                border: Border.all(
                  color: _feedback == 'correct'
                      ? const Color(0xFF5B9A1E)
                      : _feedback == 'wrong'
                      ? const Color(0xFFD85A30)
                      : const Color(0xFFF0EDE8),
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_feedback == 'correct')
                    const Text('✅', style: TextStyle(fontSize: 42))
                  else if (_feedback == 'wrong')
                    const Text('❌', style: TextStyle(fontSize: 42))
                  else
                    Text(current.emoji, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 10),
                  Text(
                    current.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF222222),
                      height: 1.2,
                    ),
                  ),
                  if (current.labelAr != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      current.labelAr!,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                  if (_feedback == 'correct') ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Correct! صَحِيح! 🌟',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        color: Color(0xFF5B9A1E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (_feedback == 'wrong') ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Not quite! حاوِل مرّة أخرى 💪',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        color: Color(0xFFD85A30),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Which group does this belong to?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 12),
          // Bucket buttons.
          Row(
            children: [
              Expanded(
                child: _BucketButton(
                  label: widget.bucketA,
                  color: const Color(0xFF5B9A1E),
                  bg: const Color(0xFFDCF0E6),
                  disabled: _feedback != null,
                  onTap: () => _handleSort(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BucketButton(
                  label: widget.bucketB,
                  color: const Color(0xFFD85A30),
                  bg: const Color(0xFFFDDCCC),
                  disabled: _feedback != null,
                  onTap: () => _handleSort(1),
                ),
              ),
            ],
          ),
          if (_done.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final d
                    in _done.length > 8
                        ? _done.sublist(_done.length - 8)
                        : _done)
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: d.correct
                          ? const Color(0xFFDCF0E6)
                          : const Color(0xFFFDDCCC),
                      border: Border.all(
                        color: d.correct
                            ? const Color(0xFF5B9A1E)
                            : const Color(0xFFD85A30),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      d.item.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BucketButton extends StatelessWidget {
  const _BucketButton({
    required this.label,
    required this.color,
    required this.bg,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color bg;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(0x55),
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
