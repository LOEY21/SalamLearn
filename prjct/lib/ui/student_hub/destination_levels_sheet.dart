import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../data/models/curriculum/curriculum_models.dart';
import '../theme/app_colors.dart';
import 'hub_world.dart';

/// Ported 1:1 from Wireframe 0.3's
/// `src/screens/learner/lesson/DestinationModal.tsx` — the bottom sheet
/// shown when a learner taps a destination node on the adventure map. Splits
/// a destination's lessons into 3 "levels" (Beginner/Practice/Mastery),
/// unlocks them in order (a level opens once the previous level is fully
/// complete, and each lesson once the one before it is done), and hands off straight to `onStartLesson` on tap — there
/// is no intermediate "Start Activity" confirmation screen, matching the
/// source exactly.
///
/// The exact overshoot easing the source's `slideUp` keyframe uses
/// (`cubic-bezier(0.34, 1.56, 0.64, 1)`) — same curve/name precedent as
/// `_overshoot` in `adventure_map_screen.dart`.
const _overshoot = Cubic(0.34, 1.56, 0.64, 1.0);

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
    this.unlockAll = false,
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

  /// Opens every level and game regardless of progress — the in-memory
  /// progression override (nothing saved, see `progressionOverrideProvider`).
  final bool unlockAll;

  /// Presents this sheet over [context], matching the source's overlay
  /// (semi-transparent backdrop, tap-outside-to-close, sheet sliding up with
  /// an overshoot ease) without inheriting Flutter's built-in
  /// `showModalBottomSheet` entrance curve. [completedLessons] is live: the
  /// sheet rebuilds the moment a lesson finishes, so its "Completed" mark
  /// shows without closing and reopening the sheet.
  static Future<void> show(
    BuildContext context, {
    required Destination destination,
    required ValueListenable<Set<String>> completedLessons,
    required int noorEnergy,
    required void Function(Lesson lesson, bool isNewLevel) onStartLesson,
    int maxLevel = 3,
    int? maxLessons,
    bool unlockAll = false,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: completedLessons,
          builder: (context, completed, _) => DestinationLevelsSheet(
            destination: destination,
            completedLessons: completed,
            noorEnergy: noorEnergy,
            onStartLesson: onStartLesson,
            maxLevel: maxLevel,
            maxLessons: maxLessons,
            unlockAll: unlockAll,
          ),
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

  /// A level opens once the one before it is complete.
  bool _isLevelUnlocked(int levelIdx) {
    if (unlockAll || levelIdx == 0) return true;
    return _isLevelComplete(_levels, levelIdx - 1);
  }

  /// How many lessons within level [levelIdx] are unlocked, in order —
  /// `null` means every lesson in that level is open. Only the top
  /// teacher-allowed level ([maxLevel] - 1) can carry a cap; any level
  /// below it that [_isLevelUnlocked] already admits is fully open.
  int? _lessonCapFor(int levelIdx) =>
      levelIdx == maxLevel - 1 ? maxLessons : null;

  bool _isLevelComplete(List<List<Lesson>> levels, int levelIdx) {
    final group = levelIdx < levels.length
        ? levels[levelIdx]
        : const <Lesson>[];
    return group.every((l) => completedLessons.contains(l.id));
  }

  void _close(BuildContext context) => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final levels = _levels;
    final total = destination.lessons.length;
    final done = destination.lessons
        .where((l) => completedLessons.contains(l.id))
        .length;

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
              maxHeight: MediaQuery.of(context).size.height * 0.88,
              // Phone-width board on tablets instead of a full-width slab.
              maxWidth: 640,
            ),
            // Same build as the bottom nav / QuestPanel: dark-wood frame,
            // parchment board, thin gold inner line.
            child: Container(
              padding: const EdgeInsets.fromLTRB(3, 3, 3, 0),
              decoration: const BoxDecoration(
                color: HubWorld.wood,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(27),
                ),
                child: Material(
                  color: HubWorld.parchment,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StageHeader(
                        destination: destination,
                        done: done,
                        total: total,
                        onClose: () => _close(context),
                      ),
                      if (noorEnergy <= 0) const _NoorRestingNote(),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            14,
                            16,
                            24 + MediaQuery.of(context).padding.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var li = 0; li < levels.length; li++) ...[
                                if (li > 0) const SizedBox(height: 18),
                                _LevelSection(
                                  meta: _levelMeta[li < 2 ? li : 2],
                                  levelIndex: li,
                                  group: levels[li],
                                  unlocked: _isLevelUnlocked(li),
                                  unlockAll: unlockAll,
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
        ),
      ),
    );
  }
}

/// A band of the map painting with the stage's checkpoint medallion, name,
/// Arabic name and real progress — the sheet opens "inside" the map.
class _StageHeader extends StatelessWidget {
  const _StageHeader({
    required this.destination,
    required this.done,
    required this.total,
    required this.onClose,
  });

  final Destination destination;
  final int done;
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final destColor = _hexColor(destination.color);
    final checkpoint = destination.id >= 1 && destination.id <= 7
        ? 'assets/images/adventure_map/checkpoint_${destination.id}.png'
        : null;

    return MapSceneHeader(
      height: 150,
      // Later stages sit higher up the painted path.
      focusY: (1 - (destination.id - 1) / 3).clamp(-1.0, 1.0),
      child: Stack(
        children: [
          // Drag handle.
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _CloseButton(onTap: onClose),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Checkpoint medallion: the same art as the map node.
                  Container(
                    width: 78,
                    height: 78,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HubWorld.parchment,
                      border: Border.all(color: AppColors.goldSoft, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: destColor.withValues(alpha: 0.55),
                          blurRadius: 16,
                        ),
                        const BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: checkpoint != null
                        ? Image.asset(checkpoint, fit: BoxFit.contain)
                        : Center(
                            child: Text(
                              destination.icon,
                              style: const TextStyle(fontSize: 34),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  // The map band is a fixed height: the text wraps at its
                  // width, then shrinks to fit rather than being cut off.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: SizedBox(
                          width: c.maxWidth,
                          child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          destination.name,
                          style: hubText(
                            22,
                            HubWorld.onScene,
                            height: 1.05,
                            shadows: hubTextShadow,
                          ),
                        ),
                        // Room for the Arabic's tall vowel marks.
                        const SizedBox(height: 8),
                        Text(
                          destination.nameAr,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontFamily: 'ScheherazadeNew',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: HubWorld.goldLight,
                            height: 1.5,
                            shadows: hubTextShadow,
                          ),
                        ),
                        const SizedBox(height: 4),
                        WoodChip(
                          label: '$done / $total games',
                          icon: const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: HubWorld.goldLight,
                          ),
                        ),
                      ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Keeps the text clear of the close button (48 wide,
                  // 10 from the edge) above it.
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 48dp tap target around a 34dp wooden disc.
    return Semantics(
      button: true,
      label: 'Close'.tr,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: HubWorld.wood.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldSoft, width: 1.5),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 19,
                color: HubWorld.onScene,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while every lantern is out: the Noor moon, dimmed, and why.
class _NoorRestingNote extends StatelessWidget {
  const _NoorRestingNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: HubWorld.night,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldSoft, width: 1.2),
      ),
      child: Row(
        children: [
          const Opacity(
            opacity: 0.55,
            child: Image(
              image: AssetImage('assets/images/noor_energy_moon.png'),
              width: 30,
              height: 30,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Noor Energy is resting — come back soon to play again!',
              style: hubText(13, HubWorld.onScene, weight: 700, height: 1.25),
            ),
          ),
        ],
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
    this.unlockAll = false,
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
  final bool unlockAll;

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
    final noEnergy = noorEnergy <= 0;
    final doneCount = group.where((l) => completedLessons.contains(l.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LevelHeader(
          meta: meta,
          levelIndex: levelIndex,
          unlocked: unlocked,
          complete: complete,
          needsNoor: unlocked && !complete && noEnergy,
          doneCount: doneCount,
          total: group.length,
        ),
        const SizedBox(height: 10),
        for (var idx = 0; idx < group.length; idx++) ...[
          if (idx > 0) const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final lesson = group[idx];
              final done = completedLessons.contains(lesson.id);
              // Each game opens once the one before it in its level is done.
              final lessonUnlocked =
                  unlockAll ||
                  (unlocked &&
                      (idx == 0 || completedLessons.contains(group[idx - 1].id)));
              // Out of Noor Energy rests every open game, finished ones too.
              final energyBlocked = lessonUnlocked && noEnergy;

              return _LessonCard(
                lesson: lesson,
                completed: done,
                unlocked: lessonUnlocked,
                energyBlocked: energyBlocked,
                onStart: () {
                  onStartLesson(lesson, isNew && !done);
                },
              );
            },
          ),
        ],
      ],
    );
  }
}

/// "Level 1 — Beginner" signboard: difficulty stars, the level's progress
/// pips, and its state (complete / needs Noor / locked).
class _LevelHeader extends StatelessWidget {
  const _LevelHeader({
    required this.meta,
    required this.levelIndex,
    required this.unlocked,
    required this.complete,
    required this.needsNoor,
    required this.doneCount,
    required this.total,
  });

  final _LevelMeta meta;
  final int levelIndex;
  final bool unlocked;
  final bool complete;
  final bool needsNoor;
  final int doneCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ink = unlocked ? HubWorld.wood : HubWorld.inkSoft;
    return Row(
      children: [
        // Difficulty stars (1–3), greyed while the level is locked.
        for (var s = 0; s <= levelIndex.clamp(0, 2); s++)
          Icon(
            Icons.star_rounded,
            size: 18,
            color: unlocked ? AppColors.gold : HubWorld.lockedRing,
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Level ${levelIndex + 1} — ${meta.label}',
            style: hubText(16, ink, weight: 800, height: 1.2),
          ),
        ),
        const SizedBox(width: 8),
        if (complete)
          _StatusPill(
            label: 'Complete!',
            icon: Icons.check_rounded,
            face: AppColors.adventureGreen,
            ink: Colors.white,
          )
        else if (!unlocked)
          const Icon(Icons.lock_rounded, size: 17, color: HubWorld.inkSoft)
        else if (needsNoor)
          _StatusPill(
            label: '⚡ needs Noor',
            face: HubWorld.night,
            ink: HubWorld.onScene,
          )
        else
          // Progress pips: one per game in this level.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < total; i++)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < doneCount
                        ? AppColors.adventureGreen
                        : HubWorld.parchmentDeep,
                    border: Border.all(
                      color: i < doneCount
                          ? AppColors.adventureGreen
                          : HubWorld.lockedRing,
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        const Spacer(),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.face,
    required this.ink,
    this.icon,
  });

  final String label;
  final Color face;
  final Color ink;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: face,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: ink),
            const SizedBox(width: 3),
          ],
          Text(label, style: hubText(11.5, ink, weight: 750, height: 1.2)),
        ],
      ),
    );
  }
}

/// Game art per activity type (`assets/images/game_icons/`), so a game
/// looks the same in every stage; `null` falls back to the lesson emoji.
String? _gameIconFor(Lesson lesson) {
  if (lesson.activities.isEmpty) return null;
  final name = switch (lesson.activities.first.type) {
    ActivityType.pronounce => 'greeting_match',
    ActivityType.creationHunt => 'creation_hunt',
    ActivityType.trace => 'magic_sand_tracer',
    ActivityType.soundDetective => 'sound_detective',
    ActivityType.quranEtiquette => 'quran_etiquette',
    ActivityType.labelMaker => 'label_maker',
    ActivityType.ayahBuilder => 'ayah_builder',
    ActivityType.sirahStory => 'sirah_story',
    ActivityType.classroomHeroes => 'classroom_heroes',
    ActivityType.taharahAdventure => 'taharah_adventure',
    ActivityType.fivePillars => 'five_pillars',
    ActivityType.goodDeedTree => 'good_deed_tree',
    _ => null,
  };
  return name == null ? null : 'assets/images/game_icons/$name.webp';
}

const _greyscale = ColorFilter.matrix([
  0.33, 0.33, 0.33, 0, 0, //
  0.33, 0.33, 0.33, 0, 0, //
  0.33, 0.33, 0.33, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// One game: big art first (show, don't tell), title, reward, and a state
/// marker. State is carried by fill and marker, never by hue — every brand
/// colour is also some lesson's colour:
/// - finished: solid mint face + green frame + green check seal + star;
/// - ready: parchment face + gold play button;
/// - Noor resting: parchment face + dimmed moon;
/// - locked: sunken face, greyed art, padlock.
class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.completed,
    required this.unlocked,
    required this.energyBlocked,
    required this.onStart,
  });

  final Lesson lesson;
  final bool completed;
  final bool unlocked;
  final bool energyBlocked;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final done = unlocked && completed;
    final iconAsset = _gameIconFor(lesson);

    Widget art = iconAsset != null
        ? Image.asset(iconAsset, width: 64, height: 64, fit: BoxFit.contain)
        : SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: Text(lesson.icon, style: const TextStyle(fontSize: 34)),
            ),
          );
    if (!unlocked) {
      art = Opacity(
        opacity: 0.45,
        child: ColorFiltered(colorFilter: _greyscale, child: art),
      );
    }

    final artWithSeal = Stack(
      clipBehavior: Clip.none,
      children: [
        art,
        if (done)
          Positioned(
            right: -4,
            bottom: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.adventureGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );

    final body = Row(
      children: [
        artWithSeal,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // No line cap: long Filipino titles wrap and the card grows.
              Text(
                lesson.title,
                style: hubText(
                  15.5,
                  done
                      ? AppColors.tealDark
                      : unlocked
                      ? AppColors.ink
                      : HubWorld.inkSoft,
                  weight: 750,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              if (done)
                _StatusPill(
                  label: '✓ Completed',
                  face: AppColors.adventureGreen,
                  ink: Colors.white,
                )
              else
                _StatusPill(
                  label: '+${lesson.xp} XP',
                  face: unlocked ? AppColors.goldTint : HubWorld.parchmentDeep,
                  ink: unlocked ? HubWorld.goldDeep : HubWorld.inkSoft,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _LessonMarker(
          lessonId: lesson.id,
          completed: done,
          // Replays cost Noor too, so resting wins over the done star.
          energyBlocked: energyBlocked,
          unlocked: unlocked,
        ),
      ],
    );

    if (!unlocked) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: HubWorld.parchmentDeep,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HubWorld.lockedRim, width: 2),
        ),
        child: body,
      );
    }

    return ChunkyButton(
      onTap: onStart,
      semanticLabel: lesson.title,
      face: done ? const Color(0xFFDCF0E6) : Colors.white,
      edge: done ? AppColors.adventureGreen : HubWorld.edge,
      border: done ? AppColors.adventureGreen : null,
      radius: 20,
      depth: 5,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: body,
    );
  }
}

class _LessonMarker extends StatelessWidget {
  const _LessonMarker({
    required this.lessonId,
    required this.completed,
    required this.energyBlocked,
    required this.unlocked,
  });

  final String lessonId;
  final bool completed;
  final bool energyBlocked;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    if (energyBlocked) {
      return Opacity(
        key: ValueKey('lesson-noor-$lessonId'),
        opacity: 0.5,
        child: const Image(
          image: AssetImage('assets/images/noor_energy_moon.png'),
          width: 34,
          height: 34,
        ),
      );
    }
    if (completed) {
      return Icon(
        Icons.star_rounded,
        key: ValueKey('lesson-done-$lessonId'),
        size: 34,
        color: AppColors.gold,
        shadows: const [Shadow(color: Color(0x668A5A00), offset: Offset(0, 2))],
      );
    }
    if (unlocked) {
      return Container(
        key: ValueKey('lesson-play-$lessonId'),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HubWorld.goldLight, AppColors.gold],
          ),
          border: Border.all(color: HubWorld.goldDeep, width: 2),
          boxShadow: const [
            BoxShadow(color: HubWorld.goldDeep, offset: Offset(0, 3)),
          ],
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          size: 26,
          color: Colors.white,
        ),
      );
    }
    return Container(
      key: ValueKey('lesson-locked-$lessonId'),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: HubWorld.wood,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.goldSoft, width: 1.5),
      ),
      child: const Icon(
        Icons.lock_rounded,
        size: 17,
        color: AppColors.goldSoft,
      ),
    );
  }
}
