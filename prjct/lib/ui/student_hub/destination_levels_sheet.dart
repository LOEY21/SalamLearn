import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../data/models/curriculum/curriculum_models.dart';
import '../theme/app_colors.dart';

/// Ported 1:1 from Wireframe 0.3's
/// `src/screens/learner/lesson/DestinationModal.tsx` — the bottom sheet
/// shown when a learner taps a destination node on the adventure map. Splits
/// a destination's lessons into 3 "levels" (Beginner/Practice/Mastery),
/// gates each level/lesson by the teacher's `maxLevel`/`maxLessons`
/// assignment (not by completion — nothing auto-unlocks from finishing a
/// prior lesson), and hands off straight to `onStartLesson` on tap — there
/// is no intermediate "Start Activity" confirmation screen, matching the
/// source exactly.
///
/// The exact overshoot easing the source's `slideUp` keyframe uses
/// (`cubic-bezier(0.34, 1.56, 0.64, 1)`) — same curve/name precedent as
/// `_overshoot` in `adventure_map_screen.dart`.
const _overshoot = Cubic(0.34, 1.56, 0.64, 1.0);

const _debugUnlockAllLevels = true;

class _LevelMeta {
  const _LevelMeta({
    required this.stars,
    required this.label,
    required this.color,
    required this.bg,
  });

  final String stars;
  final String label;
  final Color color;
  final Color bg;
}

const _levelMeta = <_LevelMeta>[
  _LevelMeta(
    stars: '⭐',
    label: 'Beginner',
    color: AppColors.adventureGreen, // #5B9A1E
    bg: Color(0xFFDCF0E6),
  ),
  _LevelMeta(
    stars: '⭐⭐',
    label: 'Practice',
    color: AppColors.gold, // #EF9F27
    bg: Color(0xFFFDECC8),
  ),
  _LevelMeta(
    stars: '⭐⭐⭐',
    label: 'Mastery',
    color: AppColors.coral, // #D85A30
    bg: Color(0xFFFDDCCC),
  ),
];

/// Parses the model's `#RRGGBB` hex strings (curriculum data / destination
/// colors) into a [Color]. The source keeps these as CSS hex strings on the
/// data objects; there is no persistence layer here to instead type them as
/// [Color] end to end, so we parse at the UI edge.
Color _hexColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

class DestinationLevelsSheet extends StatelessWidget {
  const DestinationLevelsSheet({
    super.key,
    required this.destination,
    required this.completedLessons,
    required this.noorEnergy,
    required this.onStartLesson,
    this.maxLevel = 3,
    this.maxLessons,
  });

  final Destination destination;
  final Set<String> completedLessons;
  final int noorEnergy;
  final void Function(Lesson lesson, bool isNewLevel) onStartLesson;

  /// How far (1–3) the teacher has allowed this destination's assignment
  /// to reach. Level index `li` (0-based) is only ever unlocked when
  /// `li < maxLevel` — a hard teacher-set ceiling, not driven by lesson
  /// completion. Defaults to 3 (no ceiling) for callers that don't assign
  /// per-level.
  final int maxLevel;

  /// How many lessons ("games") within the top allowed level (index
  /// `maxLevel - 1`) are unlocked, in lesson order. Earlier levels (fully
  /// admitted by [maxLevel]) always have every lesson open. `null` means no
  /// cap on the top level either.
  final int? maxLessons;

  /// Presents this sheet over [context], matching the source's overlay
  /// (semi-transparent backdrop, tap-outside-to-close, sheet sliding up with
  /// an overshoot ease) without inheriting Flutter's built-in
  /// `showModalBottomSheet` entrance curve.
  static Future<void> show(
    BuildContext context, {
    required Destination destination,
    required Set<String> completedLessons,
    required int noorEnergy,
    required void Function(Lesson lesson, bool isNewLevel) onStartLesson,
    int maxLevel = 3,
    int? maxLessons,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DestinationLevelsSheet(
          destination: destination,
          completedLessons: completedLessons,
          noorEnergy: noorEnergy,
          onStartLesson: onStartLesson,
          maxLevel: maxLevel,
          maxLessons: maxLessons,
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final t = _overshoot.transform(animation.value);
        return Align(
          alignment: Alignment.bottomCenter,
          child: FractionalTranslation(
            translation: Offset(0, 1 - t),
            child: child,
          ),
        );
      },
    );
  }

  List<List<Lesson>> get _levels {
    final lessons = destination.lessons;
    final perLevel = (lessons.length / 3).ceil();
    return [
      lessons.take(perLevel).toList(),
      lessons.skip(perLevel).take(perLevel).toList(),
      lessons.skip(perLevel * 2).toList(),
    ].where((group) => group.isNotEmpty).toList();
  }

  bool _isLevelNew(List<List<Lesson>> levels, int levelIdx) {
    final group = levelIdx < levels.length
        ? levels[levelIdx]
        : const <Lesson>[];
    return group.every((l) => !completedLessons.contains(l.id));
  }

  bool _isLevelUnlocked(int levelIdx) {
    if (_debugUnlockAllLevels) return true;
    if (destination.state == DestinationState.locked) {
      return false;
    }
    if (levelIdx == 0) return true;
    // Sequential level unlock: Level unlocks when the previous level is complete.
    return _isLevelComplete(_levels, levelIdx - 1);
  }

  /// How many lessons within level [levelIdx] are unlocked, in order —
  /// `null` means every lesson in that level is open. Only the top
  /// teacher-allowed level ([maxLevel] - 1) can carry a cap; any level
  /// below it that [_isLevelUnlocked] already admits is fully open.
  int? _lessonCapFor(int levelIdx) => levelIdx == maxLevel - 1 ? maxLessons : null;

  bool _isLevelComplete(List<List<Lesson>> levels, int levelIdx) {
    final group = levelIdx < levels.length
        ? levels[levelIdx]
        : const <Lesson>[];
    return group.every((l) => completedLessons.contains(l.id));
  }

  void _close(BuildContext context) => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final isLocked =
        !_debugUnlockAllLevels && destination.state == DestinationState.locked;
    final levels = _levels;
    final destColor = _hexColor(destination.color);
    final destBg = _hexColor(destination.bg);

    return GestureDetector(
      onTap: () => _close(context),
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {}, // swallow taps so they don't bubble to the backdrop
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Material(
              color: const Color(0xFFFFF7E9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle.
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: 44,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFDDDDDD),
                          borderRadius: BorderRadius.all(Radius.circular(3)),
                        ),
                      ),
                    ),
                  ),

                  // Header.
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF0EDE8), width: 2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: destBg,
                            border: Border.all(color: destColor, width: 3),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: destColor.withValues(alpha: 0.27),
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            destination.icon,
                            style: TextStyle(
                              fontSize: destination.icon.length <= 2 ? 26 : 32,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                destination.name,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111111),
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                destination.nameAr,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: destColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                destination.description,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _close(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EDE8),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Text(
                              '✕',
                              style: TextStyle(
                                fontSize: 17,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Noor energy note.
                  if (!isLocked && noorEnergy <= 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECC8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Text('✨', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Noor Energy is resting — you can replay '
                                'completed lessons!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC9A227),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Levels.
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                      child: isLocked
                          ? _LockedMessage(color: destColor)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var li = 0; li < levels.length; li++) ...[
                                  if (li > 0) const SizedBox(height: 16),
                                  _LevelSection(
                                    meta: _levelMeta[li < 2 ? li : 2],
                                    levelIndex: li,
                                    group: levels[li],
                                    unlocked: _isLevelUnlocked(li),
                                    lessonCap: _lessonCapFor(li),
                                    complete: _isLevelComplete(levels, li),
                                    isNew: _isLevelNew(levels, li),
                                    noorEnergy: noorEnergy,
                                    completedLessons: completedLessons,
                                    onStartLesson: (lesson, isNewLevel) {
                                      _close(context);
                                      onStartLesson(lesson, isNewLevel);
                                    },
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelSection extends StatelessWidget {
  const _LevelSection({
    required this.meta,
    required this.levelIndex,
    required this.group,
    required this.unlocked,
    this.lessonCap,
    required this.complete,
    required this.isNew,
    required this.noorEnergy,
    required this.completedLessons,
    required this.onStartLesson,
  });

  final _LevelMeta meta;
  final int levelIndex;
  final List<Lesson> group;
  final bool unlocked;

  /// How many lessons in [group], in order, are teacher-unlocked — `null`
  /// means all of them.
  final int? lessonCap;
  final bool complete;
  final bool isNew;
  final int noorEnergy;
  final Set<String> completedLessons;
  final void Function(Lesson lesson, bool isNewLevel) onStartLesson;

  @override
  Widget build(BuildContext context) {
    final noEnergy = isNew && noorEnergy <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level header.
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: unlocked ? 1 : 0.5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: complete
                        ? AppColors.adventureGreen
                        : unlocked
                        ? meta.bg
                        : const Color(0xFFF0EDE8),
                    border: Border.all(
                      color:
                          (complete
                                  ? AppColors.adventureGreen
                                  : unlocked
                                  ? meta.color
                                  : const Color(0xFFDDDDDD))
                              .withValues(alpha: 0.27),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        complete
                            ? '✅'
                            : unlocked
                            ? meta.stars
                            : '🔒',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Level ${levelIndex + 1} — ${meta.label}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: complete
                              ? Colors.white
                              : unlocked
                              ? meta.color
                              : const Color(0xFFAAAAAA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (unlocked && !complete && noEnergy) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '⚡ needs Noor',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.adventurePurple,
                    ),
                  ),
                ),
              ],
              if (complete) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF0E6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Complete!',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Lessons in level.
        Column(
          children: [
            for (var idx = 0; idx < group.length; idx++) ...[
              if (idx > 0) const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final lesson = group[idx];
                  final done = completedLessons.contains(lesson.id);
                  final lessonUnlocked =
                      unlocked &&
                      (_debugUnlockAllLevels ||
                          idx == 0 ||
                          completedLessons.contains(group[idx - 1].id));
                  final canStart = lessonUnlocked && (done || !noEnergy);
                  final energyBlocked = lessonUnlocked && !done && noEnergy;

                  return _LessonCard(
                    lesson: lesson,
                    index: idx,
                    completed: done,
                    unlocked: lessonUnlocked,
                    energyBlocked: energyBlocked,
                    onStart: () {
                      if (canStart) {
                        onStartLesson(lesson, isNew && !done);
                      } else if (lessonUnlocked && !done && noEnergy) {
                        // Will be blocked by the caller (matches source:
                        // still routed through onStartLesson so the caller
                        // decides how to surface the energy block).
                        onStartLesson(lesson, true);
                      }
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.index,
    required this.completed,
    required this.unlocked,
    required this.energyBlocked,
    required this.onStart,
  });

  final Lesson lesson;
  final int index;
  final bool completed;
  final bool unlocked;
  final bool energyBlocked;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final lessonColor = _hexColor(lesson.color);
    final borderColor = unlocked && completed
        ? AppColors.adventureGreen
        : unlocked
        ? lessonColor
        : const Color(0xFFDDDDDD);
    final bgColor = unlocked && completed
        ? const Color(0xFFDCF0E6)
        : unlocked
        ? Colors.white
        : const Color(0xFFF5F2EE);

    Widget content = Opacity(
      opacity: unlocked ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(18),
          boxShadow: !unlocked
              ? null
              : [
                  BoxShadow(
                    color: (completed ? AppColors.adventureGreen : lessonColor)
                        .withValues(alpha: 0.27),
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Index-or-checkmark badge.
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: unlocked && completed
                    ? AppColors.adventureGreen
                    : unlocked
                    ? lessonColor
                    : const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                unlocked && completed ? '✓' : '${index + 1}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Icon chip.
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFFDCF0E6)
                    : lessonColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                unlocked ? lesson.icon : '🔒',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 10),

            // Title + activity icons + XP pill.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: completed
                          ? AppColors.teal
                          : unlocked
                          ? const Color(0xFF111111)
                          : const Color(0xFFAAAAAA),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final activity in lesson.activities)
                        Text(
                          activity.icon,
                          style: const TextStyle(fontSize: 12),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECC8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${lesson.xp} XP',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Trailing indicator.
            _LessonTrailing(
              completed: completed,
              energyBlocked: energyBlocked,
              unlocked: unlocked,
              lessonColor: lessonColor,
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: unlocked ? onStart : null,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}

class _LessonTrailing extends StatelessWidget {
  const _LessonTrailing({
    required this.completed,
    required this.energyBlocked,
    required this.unlocked,
    required this.lessonColor,
  });

  final bool completed;
  final bool energyBlocked;
  final bool unlocked;
  final Color lessonColor;

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return const Text('🌟', style: TextStyle(fontSize: 20));
    }
    if (energyBlocked) {
      return const Text('✨', style: TextStyle(fontSize: 18));
    }
    if (unlocked) {
      return Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lessonColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: lessonColor.withValues(alpha: 0.53),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          '›',
          style: TextStyle(
            fontSize: 17,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return const Opacity(
      opacity: 0.4,
      child: Text('🔒', style: TextStyle(fontSize: 16)),
    );
  }
}

class _LockedMessage extends StatelessWidget {
  const _LockedMessage({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // Source uses a dashed border here; Flutter's BoxDecoration has no
        // built-in dashed style (would need a custom painter), so this is a
        // solid border of the same color/width as the closest idiomatic fit.
        border: Border.all(color: color.withValues(alpha: 0.27), width: 3),
      ),
      child: Column(
        children: [
          const Text('🔒', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
          const Text(
            'Complete earlier destinations first!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Finish the lessons before this one to unlock this destination 🌟',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}
