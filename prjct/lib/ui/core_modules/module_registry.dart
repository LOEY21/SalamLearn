import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';

/// One Adventure Map node's tile identity, derived from a [Destination] in
/// `curriculum_data.dart`. Was 5 fixed placeholder "core modules"
/// (tracing/flashcards/recitation/stories/sorting) before the Wireframe 0.3
/// curriculum port replaced that placeholder content with the 7 real
/// destinations — kept as a thin `ModuleInfo` wrapper (rather than using
/// `Destination` directly everywhere) since the map/node rendering code
/// only needs a handful of display fields, not the full lesson tree.
class ModuleInfo {
  const ModuleInfo({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    required this.color,
    required this.onColor,
    required this.destinationId,
    this.illustrationAsset,
  });

  final String id;
  final String title;
  final IconData icon;
  final String description;
  final Color color;
  final Color onColor;

  /// Looks this module back up in `curriculum.firstWhere((d) => d.id == ...)`.
  final int destinationId;

  /// Optional hand-illustrated mascot scene shown in place of the plain
  /// icon chip on the Student Hub tile. Null until an illustration has
  /// been produced for that module.
  final String? illustrationAsset;
}

Color _hexColor(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

/// Built from `curriculum_data.dart`'s 7 destinations rather than hand-typed,
/// so the map's node identity and the lesson content it opens into can never
/// drift out of sync. `IconData` (Material icon) per node is a rough
/// thematic stand-in for the destination's own emoji glyph, since map-node
/// rendering (`_MapNode` in `adventure_map_screen.dart`) needs an `IconData`
/// for its locked/available icon fallback.
final coreModules = [
  for (final d in curriculum)
    ModuleInfo(
      id: _slugFor(d.id),
      title: d.name,
      icon: _iconFor(d.id),
      description: d.description,
      color: _hexColor(d.color),
      onColor: Colors.white,
      destinationId: d.id,
    ),
];

String _slugFor(int destinationId) => switch (destinationId) {
  1 => 'village-of-salaam',
  2 => 'desert-of-letters',
  3 => 'garden-of-words',
  4 => 'river-of-sirah',
  5 => 'masjid-of-salah',
  6 => 'mountain-of-iman',
  7 => 'quran-corner',
  _ => 'destination-$destinationId',
};

IconData _iconFor(int destinationId) => switch (destinationId) {
  1 => Icons.home_outlined, // Welcome to Madrasah — greetings/expressions
  2 => Icons.draw_outlined, // Exploring Our World — letters/creation
  3 => Icons.local_florist_outlined, // A Growing Muslim — vocabulary/etiquette
  4 => Icons.menu_book_outlined, // Stories & Letters — Sirah/tracing
  5 => Icons.mosque_outlined, // Cleanliness & Character — wudu/kindness
  6 => Icons.terrain_outlined, // The Path of the Prophet — Sirah/wudu/pillars
  7 => Icons.auto_stories_outlined, // The Good Deed Hero — final review
  _ => Icons.explore_outlined,
};

/// Every game the Student Hub offers (one per curriculum lesson), in map
/// order — what a teacher picks from when assigning a learning module.
final allGames = [
  for (final d in curriculum)
    for (final l in d.lessons) (lesson: l, destination: d),
];

/// The game an assignment's `moduleId` names, or null for older
/// whole-destination assignments (slug or destination number).
({Lesson lesson, Destination destination})? gameForId(String id) {
  for (final game in allGames) {
    if (game.lesson.id == id) return game;
  }
  return null;
}

/// The Adventure Map node an assignment belongs to, or null if [moduleId]
/// names nothing in the curriculum.
ModuleInfo? moduleForAssignment(String moduleId) {
  final destinationId = gameForId(moduleId)?.destination.id;
  return coreModules
      .where(
        (m) => destinationId != null
            ? m.destinationId == destinationId
            : m.id == moduleId || '${m.destinationId}' == moduleId,
      )
      .firstOrNull;
}

/// Display name for an assignment: the game's title, else the destination's.
String assignmentTitle(String moduleId) =>
    gameForId(moduleId)?.lesson.title ??
    moduleForAssignment(moduleId)?.title ??
    moduleId;

/// The lessons an assignment gives the learner: just the game itself, or
/// for a whole-destination assignment every lesson up to
/// [maxLevel]/[maxLessons] (levels are the destination's lessons in thirds).
List<Lesson> assignedLessonsFor(String moduleId, int maxLevel, int? maxLessons) {
  final game = gameForId(moduleId);
  if (game != null) return [game.lesson];
  final destinationId = moduleForAssignment(moduleId)?.destinationId;
  final lessons = [
    for (final d in curriculum)
      if (d.id == destinationId) ...d.lessons,
  ];
  final perLevel = (lessons.length / 3).ceil();
  final levelsList = [
    lessons.take(perLevel).toList(),
    lessons.skip(perLevel).take(perLevel).toList(),
    lessons.skip(perLevel * 2).toList(),
  ].where((group) => group.isNotEmpty).toList();
  final result = <Lesson>[];
  for (var li = 0; li < maxLevel; li++) {
    if (li >= levelsList.length) break;
    final cap = (li == maxLevel - 1) ? maxLessons : null;
    result.addAll(levelsList[li].take(cap ?? levelsList[li].length));
  }
  return result;
}

/// Which game a session belongs to — its title before " - Session …".
String gameNameOf(Lesson lesson) => lesson.title.split(' - ').first;

/// The session part of a lesson's title, e.g. "Session 2 (Sky)".
String sessionLabelOf(Lesson lesson) {
  final rest = lesson.title.substring(gameNameOf(lesson).length);
  return rest.startsWith(' - ') ? rest.substring(3) : lesson.title;
}

/// The Student Hub's games (Greeting Match, Ayah Builder, …), each with its
/// sessions in map order.
final Map<String, List<Lesson>> gameSessions = {
  for (final name in {for (final g in allGames) gameNameOf(g.lesson)})
    name: [
      for (final g in allGames)
        if (gameNameOf(g.lesson) == name) g.lesson,
    ],
};
