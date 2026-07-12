import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The five core educational engines (FR-4.1 … FR-4.5).
/// Placeholder phase: routes and identity only, no content yet.
class ModuleInfo {
  const ModuleInfo({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    required this.color,
    required this.onColor,
    this.illustrationAsset,
  });

  final String id;
  final String title;
  final IconData icon;
  final String description;
  final Color color;
  final Color onColor;

  /// Optional hand-illustrated mascot scene shown in place of the plain
  /// icon chip on the Student Hub tile. Null until an illustration has
  /// been produced for that module.
  final String? illustrationAsset;
}

/// Tile colors follow the Student Hub mockup (Figure 4.3):
/// teal, gold, light gold, mint green — coral reserved for the fifth.
const coreModules = [
  ModuleInfo(
    id: 'tracing',
    title: 'Tracing',
    icon: Icons.draw_outlined,
    description: 'Learn Arabic letters step by step',
    color: AppColors.teal,
    onColor: Colors.white,
    illustrationAsset: 'assets/images/mascot_tracing.png',
  ),
  ModuleInfo(
    id: 'flashcards',
    title: 'Sounds',
    icon: Icons.volume_up_outlined,
    description: 'Tap flashcards to hear pronunciation',
    color: AppColors.coral,
    onColor: Colors.white,
    illustrationAsset: 'assets/images/mascot_flashcards.png',
  ),
  ModuleInfo(
    id: 'recitation',
    title: "Qur'an & Hadith",
    icon: Icons.menu_book_outlined,
    description: "Learn and understand Qur'an & Hadith",
    color: AppColors.gold,
    onColor: AppColors.ink,
    illustrationAsset: 'assets/images/mascot_recitation.png',
  ),
  ModuleInfo(
    id: 'stories',
    title: 'Stories',
    icon: Icons.auto_stories_outlined,
    description: 'Enjoy Islamic stories and lessons',
    color: Color(0xFF2B6CB0),
    onColor: Colors.white,
    illustrationAsset: 'assets/images/mascot_stories.png',
  ),
  ModuleInfo(
    id: 'sorting',
    title: 'Sort & Match',
    icon: Icons.extension_outlined,
    description: 'Fun activities to test your knowledge',
    color: Color(0xFF805AD5),
    onColor: Colors.white,
    illustrationAsset: 'assets/images/mascot_sorting.png',
  ),
];
