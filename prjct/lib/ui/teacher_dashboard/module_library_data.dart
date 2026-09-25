import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../theme/app_colors.dart';

/// One selectable entry in the Module Library grid — an [Activity] plus
/// enough of its parent [Destination]/[Lesson] to display and to encode
/// back into a [LessonFolder.itemRefs] string. Built once from
/// `curriculum_data.dart`'s `curriculum` list, the same "pre-existing game
/// modules" pool the five core modules already play out of, rather than
/// duplicating any content for the builder.
class ModuleRef {
  const ModuleRef({
    required this.destinationId,
    required this.destinationName,
    required this.lessonId,
    required this.lessonTitle,
    required this.activity,
  });

  final int destinationId;
  final String destinationName;
  final String lessonId;
  final String lessonTitle;
  final Activity activity;

  /// `"destinationId|lessonId|activityId"` — [LessonFolder.itemRefs]'
  /// on-disk shape. Kept a plain delimited string (not a nested Hive
  /// adapter) since it's only ever parsed back against the in-memory
  /// [allModuleRefs] list, never queried.
  String get ref => '$destinationId|$lessonId|${activity.id}';
}

/// Every activity across every destination/lesson, flattened once at
/// startup — the full pool the builder's Module Library grid picks from.
final List<ModuleRef> allModuleRefs = [
  for (final destination in curriculum)
    for (final lesson in destination.lessons)
      for (final activity in lesson.activities)
        ModuleRef(
          destinationId: destination.id,
          destinationName: destination.name,
          lessonId: lesson.id,
          lessonTitle: lesson.title,
          activity: activity,
        ),
];

final Map<String, ModuleRef> _moduleRefsByRef = {
  for (final m in allModuleRefs) m.ref: m,
};

/// Resolves a stored `itemRefs` entry back to its [ModuleRef], or `null` if
/// the underlying curriculum content was ever removed/renumbered (a saved
/// folder shouldn't crash just because one activity id no longer exists —
/// the builder/detail UI simply skips it, same "dangling id" defensiveness
/// `SessionNotifier.build()` uses for stored account ids).
ModuleRef? resolveModuleRef(String ref) => _moduleRefsByRef[ref];

/// Icon/label/color per [ActivityType] — reuses `AppColors` tokens only
/// (no new palette entries), rotating the same accents the rest of the app
/// already uses for tinted icon chips.
class ActivityTypeStyle {
  const ActivityTypeStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
}

const Map<ActivityType, ActivityTypeStyle> activityTypeStyles = {
  ActivityType.trace: ActivityTypeStyle(
    label: 'Trace',
    icon: Icons.edit_outlined,
    color: AppColors.teal,
    bg: AppColors.mint,
  ),
  ActivityType.pronounce: ActivityTypeStyle(
    label: 'Pronounce',
    icon: Icons.record_voice_over_outlined,
    color: AppColors.gold,
    bg: AppColors.goldTint,
  ),
  ActivityType.quranSync: ActivityTypeStyle(
    label: "Qur'an Sync",
    icon: Icons.menu_book_outlined,
    color: AppColors.coral,
    bg: AppColors.coralTint,
  ),
  ActivityType.sirahStory: ActivityTypeStyle(
    label: 'Sirah Story',
    icon: Icons.nights_stay_outlined,
    color: AppColors.ink,
    bg: AppColors.neutralTint,
  ),
  ActivityType.quranEtiquette: ActivityTypeStyle(
    label: "Qur'an Etiquette",
    icon: Icons.menu_book_outlined,
    color: AppColors.teal,
    bg: AppColors.mint,
  ),
  ActivityType.fivePillars: ActivityTypeStyle(
    label: 'The Five Pillars',
    icon: Icons.mosque_outlined,
    color: AppColors.teal,
    bg: AppColors.mint,
  ),
  ActivityType.goodDeedTree: ActivityTypeStyle(
    label: 'The Good Deed Tree',
    icon: Icons.park_outlined,
    color: AppColors.mintGreen,
    bg: AppColors.mint,
  ),
  ActivityType.taharahAdventure: ActivityTypeStyle(
    label: 'Taharah Adventure',
    icon: Icons.clean_hands_outlined,
    color: AppColors.coral,
    bg: AppColors.coralTint,
  ),
  ActivityType.story: ActivityTypeStyle(
    label: 'Story',
    icon: Icons.auto_stories_outlined,
    color: AppColors.ink,
    bg: AppColors.neutralTint,
  ),
  ActivityType.fiqhDrag: ActivityTypeStyle(
    label: 'Fiqh Sort',
    icon: Icons.mosque_outlined,
    color: AppColors.mintGreen,
    bg: AppColors.mint,
  ),
  ActivityType.quiz: ActivityTypeStyle(
    label: 'Quiz',
    icon: Icons.quiz_outlined,
    color: AppColors.gold,
    bg: AppColors.goldTint,
  ),
  ActivityType.harakatPop: ActivityTypeStyle(
    label: 'Harakat Pop',
    icon: Icons.bubble_chart_outlined,
    color: AppColors.teal,
    bg: AppColors.mint,
  ),
};
