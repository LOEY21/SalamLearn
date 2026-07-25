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
  1 => Icons.home_outlined, // Village of Salaam — greetings/expressions
  2 => Icons.draw_outlined, // Desert of Letters — Arabic alphabet tracing
  3 => Icons.local_florist_outlined, // Garden of Words — vocabulary
  4 => Icons.menu_book_outlined, // River of Sirah — Prophet's life/hadith
  5 => Icons.mosque_outlined, // Masjid of Salah — prayer/wudu/fiqh
  6 => Icons.terrain_outlined, // Mountain of Iman — aqidah/values
  7 => Icons.auto_stories_outlined, // Qur'an Corner — Qur'an review
  _ => Icons.explore_outlined,
};
