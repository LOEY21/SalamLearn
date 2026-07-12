import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/curriculum/curriculum_models.dart';
import '../../logic/learner/learner_xp_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';
import 'activities/flashcard_activity.dart';
import 'activities/match_activity.dart';
import 'activities/quiz_activity.dart';
import 'activities/sort_activity.dart';
import 'activities/story_activity.dart';
import 'lesson_complete_screen.dart';

/// Parses the model's `#RRGGBB` hex strings into a [Color] — same
/// convention as `destination_levels_sheet.dart`'s `_hexColor`.
Color _hexColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

/// Ported from Wireframe 0.3's `LessonPlayer.tsx` — full-screen lesson
/// runner: top bar (close, progress bar, XP badge), activity title row,
/// and the current activity's widget filling the rest of the screen.
///
/// Auto-advances the instant an activity's `onComplete` fires — there is
/// no "start next activity" confirmation step anywhere, matching the
/// source's `handleActivityComplete` exactly. On the final activity's
/// completion, this screen has no parent to bubble
/// `onComplete(lessonId, xp)` up to (unlike the source), so it directly
/// awards XP/streak/badge via the same providers
/// `module_placeholder_screen.dart`'s DFD simulation calls, then shows
/// [LessonCompleteScreen] — silently, with no narrated multi-step flow.
class LessonPlayerScreen extends ConsumerStatefulWidget {
  const LessonPlayerScreen({
    super.key,
    required this.lesson,
    required this.onClose,
  });

  final Lesson lesson;
  final VoidCallback onClose;

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  int _activityIndex = 0;
  int _xpEarned = 0;
  bool _finished = false;

  Activity get _activity => widget.lesson.activities[_activityIndex];

  void _handleActivityComplete(int xp) {
    final next = _xpEarned + xp;
    if (_activityIndex + 1 >= widget.lesson.activities.length) {
      ref.read(learnerXpProvider.notifier).addXp(next);
      ref.read(learnerStreakProvider.notifier).increment();
      ref
          .read(unlockedBadgesProvider.notifier)
          .unlockBadge('${widget.lesson.title} Master');
      setState(() {
        _xpEarned = next;
        _finished = true;
      });
    } else {
      setState(() {
        _xpEarned = next;
        _activityIndex += 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return LessonCompleteScreen(
        lesson: widget.lesson,
        xpEarned: _xpEarned,
        onContinue: widget.onClose,
      );
    }

    final lessonColor = _hexColor(widget.lesson.color);
    final totalXp = widget.lesson.activities.fold<int>(
      0,
      (sum, activity) => sum + activity.xp,
    );
    final progress = widget.lesson.activities.isEmpty
        ? 0.0
        : _activityIndex / widget.lesson.activities.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E9),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(lessonColor, progress, totalXp),
            _buildActivityTitleRow(),
            Expanded(child: _buildActivityContent(lessonColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color lessonColor, double progress, int totalXp) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0EDE8), width: 2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '✕',
                style: TextStyle(fontSize: 18, color: Color(0xFF666666)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    Container(color: const Color(0xFFF0EDE8)),
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [lessonColor, AppColors.gold],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECC8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$totalXp XP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTitleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(_activity.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            _activity.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const Spacer(),
          Text(
            '${_activityIndex + 1}/${widget.lesson.activities.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCCCCCC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityContent(Color lessonColor) {
    final activity = _activity;
    // `key: ValueKey(activity.id)` matters here, not just style: two
    // consecutive activities of the same type (e.g. two flashcard
    // activities back to back) are the same widget type at the same tree
    // position, so without a distinct key Flutter reuses the previous
    // activity's State — its flip/card-index/done-set — instead of
    // starting the new activity fresh.
    return switch (activity.type) {
      ActivityType.flashcard => FlashcardActivity(
        key: ValueKey(activity.id),
        cards: activity.cards!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
      ),
      ActivityType.quiz => QuizActivity(
        key: ValueKey(activity.id),
        questions: activity.questions!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
      ),
      ActivityType.story => StoryActivity(
        key: ValueKey(activity.id),
        panels: activity.panels!,
        xp: activity.xp,
        onComplete: _handleActivityComplete,
      ),
      ActivityType.match => MatchActivity(
        key: ValueKey(activity.id),
        pairs: activity.pairs!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
      ),
      ActivityType.sort => SortActivity(
        key: ValueKey(activity.id),
        items: activity.items!,
        bucketA: activity.bucketA!,
        bucketB: activity.bucketB!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
      ),
    };
  }
}
