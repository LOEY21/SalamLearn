import 'package:flutter/material.dart' hide Text, TextSpan;

enum BadgeCategory {
  milestone(
    title: 'Milestone & Completion',
    subtitle: 'Game-Specific',
    description:
        'Unlocked when a child completes all sessions or master levels within a specific educational module.',
  ),
  streak(
    title: 'Streak & Habit',
    subtitle: 'Active Learner',
    description:
        'Encourages consistency and regular app usage (ideal for daily check-ins or classroom habits).',
  );

  const BadgeCategory({
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final String title;
  final String subtitle;
  final String description;
}

class BadgeItem {
  const BadgeItem({
    required this.id,
    required this.name,
    required this.requirement,
    required this.category,
    required this.icon,
    required this.emoji,
    required this.color,
    required this.xp,
    this.lottieAsset,
  });

  final String id;
  final String name;
  final String requirement;
  final BadgeCategory category;
  final IconData icon;
  final String emoji;
  final Color color;
  final int xp;
  final String? lottieAsset;

  String get shortName => name.replaceAll(' Badge', '');
}

/// All 16 student badges across Milestone and Streak categories.
const allStudentBadges = <BadgeItem>[
  // ─── 1. Milestone & Completion Badges (Game-Specific) ───────────────
  BadgeItem(
    id: 'desert_calligrapher',
    name: 'Desert Calligrapher Badge',
    requirement:
        'Complete all 4 sessions of The Magic Sand Tracer (mastering all 28 Arabic letters with correct right-to-left stroke direction).',
    category: BadgeCategory.milestone,
    icon: Icons.brush_rounded,
    emoji: '🏜️',
    color: Color(0xFFE5A93B),
    xp: 150,
    lottieAsset: 'assets/lottie/goal_target.json',
  ),
  BadgeItem(
    id: 'sound_detective_star',
    name: 'Sound Detective Star Badge',
    requirement:
        'Finish all 4 sessions of Arabic Sound Detective with a 100% correct audio-matching score.',
    category: BadgeCategory.milestone,
    icon: Icons.hearing_rounded,
    emoji: '🔍',
    color: Color(0xFF26A69A),
    xp: 150,
    lottieAsset: 'assets/lottie/cast_ripple.json',
  ),
  BadgeItem(
    id: 'vocabulary_master',
    name: 'Vocabulary Master Badge',
    requirement:
        'Successfully complete all 3 sessions of the SalamLearn Label Maker (Home, Body Parts, Classroom).',
    category: BadgeCategory.milestone,
    icon: Icons.style_rounded,
    emoji: '🏷️',
    color: Color(0xFF3B82F6),
    xp: 150,
    lottieAsset: 'assets/lottie/milestone_burst.json',
  ),
  BadgeItem(
    id: 'greeting_ambassador',
    name: 'Greeting Ambassador Badge',
    requirement:
        'Complete both sessions of The Greeting Match by correctly pairing daily and classroom Islamic greetings.',
    category: BadgeCategory.milestone,
    icon: Icons.handshake_rounded,
    emoji: '🤝',
    color: Color(0xFF10B981),
    xp: 100,
    lottieAsset: 'assets/lottie/noor_glow.json',
  ),
  BadgeItem(
    id: 'nature_explorer',
    name: 'Nature Explorer Badge',
    requirement:
        'Find all items created by Allah across the 3 landscapes in Allah’s Creation Hunt.',
    category: BadgeCategory.milestone,
    icon: Icons.explore_rounded,
    emoji: '🌿',
    color: Color(0xFF059669),
    xp: 120,
    lottieAsset: 'assets/lottie/xp_star.json',
  ),
  BadgeItem(
    id: 'quran_listener',
    name: 'Qur\'an Listener Badge',
    requirement:
        'Complete the scenario choices in The Qur’an Etiquette modules.',
    category: BadgeCategory.milestone,
    icon: Icons.auto_stories_rounded,
    emoji: '📖',
    color: Color(0xFF8B5CF6),
    xp: 100,
    lottieAsset: 'assets/lottie/practice_complete.json',
  ),
  BadgeItem(
    id: 'ayah_builder',
    name: 'Ayah Builder Badge',
    requirement:
        'Successfully assemble all 7 short Surah and Basmalah puzzles in the Ayah Builder.',
    category: BadgeCategory.milestone,
    icon: Icons.extension_rounded,
    emoji: '🧩',
    color: Color(0xFF0284C7),
    xp: 150,
    lottieAsset: 'assets/lottie/goal_target.json',
  ),
  BadgeItem(
    id: 'sirah_storyteller',
    name: 'Sirah Storyteller Badge',
    requirement:
        'Complete all 4 storytelling sessions about the Prophet’s (ﷺ) childhood and character.',
    category: BadgeCategory.milestone,
    icon: Icons.history_edu_rounded,
    emoji: '📜',
    color: Color(0xFFD97706),
    xp: 150,
    lottieAsset: 'assets/lottie/milestone_burst.json',
  ),
  BadgeItem(
    id: 'classroom_hero',
    name: 'Classroom Hero Badge',
    requirement:
        'Complete all 4 values modules (Respect, Kindness, Responsibility, Teamwork) and completely fill the Classroom Hero Meter.',
    category: BadgeCategory.milestone,
    icon: Icons.shield_rounded,
    emoji: '🦸',
    color: Color(0xFFEC4899),
    xp: 200,
    lottieAsset: 'assets/lottie/milestone_burst.json',
  ),
  BadgeItem(
    id: 'purification_pro',
    name: 'Purification Pro Badge',
    requirement:
        'Complete the hygiene sorting game and master both parts of the Wudhu Sequence.',
    category: BadgeCategory.milestone,
    icon: Icons.water_drop_rounded,
    emoji: '💧',
    color: Color(0xFF06B6D4),
    xp: 150,
    lottieAsset: 'assets/lottie/cast_ripple.json',
  ),
  BadgeItem(
    id: 'pillar_builder',
    name: 'Pillar Builder Badge',
    requirement:
        'Successfully build the mosque foundation by ordering and naming all Five Pillars of Islam.',
    category: BadgeCategory.milestone,
    icon: Icons.account_balance_rounded,
    emoji: '🕌',
    color: Color(0xFF7C3AED),
    xp: 200,
    lottieAsset: 'assets/lottie/goal_target.json',
  ),
  BadgeItem(
    id: 'blooming_garden',
    name: 'Blooming Garden Badge',
    requirement:
        'Fully bloom The Good Deed Tree from bare roots to golden fruits across both sorting sessions.',
    category: BadgeCategory.milestone,
    icon: Icons.local_florist_rounded,
    emoji: '🌸',
    color: Color(0xFF10B981),
    xp: 150,
    lottieAsset: 'assets/lottie/noor_glow.json',
  ),

  // ─── 2. Streak & Habit Badges (Active Learner) ───────────────────────
  BadgeItem(
    id: 'first_steps',
    name: 'First Steps Badge',
    requirement:
        'Complete your very first learning session on day one.',
    category: BadgeCategory.streak,
    icon: Icons.directions_walk_rounded,
    emoji: '👣',
    color: Color(0xFF5BC4A0),
    xp: 50,
    lottieAsset: 'assets/lottie/xp_star.json',
  ),
  BadgeItem(
    id: 'curious_spark',
    name: 'Curious Spark Badge (3-Day Streak)',
    requirement:
        'Log in and complete at least one session for 3 consecutive days.',
    category: BadgeCategory.streak,
    icon: Icons.bolt_rounded,
    emoji: '✨',
    color: Color(0xFFF59E0B),
    xp: 100,
    lottieAsset: 'assets/lottie/flame_streak.json',
  ),
  BadgeItem(
    id: 'dedicated_learner',
    name: 'Dedicated Learner Badge (7-Day Streak)',
    requirement:
        'Maintain a 7-day learning streak without missing a day.',
    category: BadgeCategory.streak,
    icon: Icons.local_fire_department,
    emoji: '🔥',
    color: Color(0xFFEF4444),
    xp: 200,
    lottieAsset: 'assets/lottie/flame_streak.json',
  ),
  BadgeItem(
    id: 'monthly_star_seeker',
    name: 'Monthly Star Seeker (30-Day Milestone)',
    requirement:
        'Accumulate a total of 30 active learning days across the term.',
    category: BadgeCategory.streak,
    icon: Icons.stars_rounded,
    emoji: '🌟',
    color: Color(0xFF8B5CF6),
    xp: 500,
    lottieAsset: 'assets/lottie/milestone_burst.json',
  ),
];

/// Milestone badges only.
List<BadgeItem> get milestoneBadges =>
    allStudentBadges.where((b) => b.category == BadgeCategory.milestone).toList();

/// Streak badges only.
List<BadgeItem> get streakBadges =>
    allStudentBadges.where((b) => b.category == BadgeCategory.streak).toList();

/// Check if a badge is unlocked against a list of unlocked badge strings.
bool isBadgeUnlocked(BadgeItem badge, List<String> unlockedList) {
  final nameNorm = badge.name.toLowerCase().trim();
  final idNorm = badge.id.toLowerCase().trim();
  final shortNorm = badge.shortName.toLowerCase().trim();
  final idUnderscores = badge.id.toLowerCase().replaceAll('-', '_');

  for (final item in unlockedList) {
    final itemNorm = item.toLowerCase().trim();
    if (itemNorm == nameNorm ||
        itemNorm == idNorm ||
        itemNorm == shortNorm ||
        itemNorm == idUnderscores ||
        itemNorm.replaceAll(' ', '_') == idUnderscores ||
        itemNorm.replaceAll(' ', '_') == nameNorm.replaceAll(' ', '_')) {
      return true;
    }
  }
  return false;
}

/// Helper to map a lesson or activity title to its corresponding badge.
BadgeItem? badgeForLessonTitle(String title) {
  final t = title.toLowerCase();
  if (t.contains('sand tracer') || t.contains('trace') || t.contains('magic sand')) {
    return allStudentBadges.firstWhere((b) => b.id == 'desert_calligrapher');
  }
  if (t.contains('sound detective') || t.contains('detective') || t.contains('sound')) {
    return allStudentBadges.firstWhere((b) => b.id == 'sound_detective_star');
  }
  if (t.contains('label maker') || t.contains('label')) {
    return allStudentBadges.firstWhere((b) => b.id == 'vocabulary_master');
  }
  if (t.contains('greeting match') || t.contains('greeting')) {
    return allStudentBadges.firstWhere((b) => b.id == 'greeting_ambassador');
  }
  if (t.contains('creation hunt') || t.contains('creation')) {
    return allStudentBadges.firstWhere((b) => b.id == 'nature_explorer');
  }
  if (t.contains('quran etiquette') || t.contains('etiquette')) {
    return allStudentBadges.firstWhere((b) => b.id == 'quran_listener');
  }
  if (t.contains('ayah builder') || t.contains('puzzle') || t.contains('ayah')) {
    return allStudentBadges.firstWhere((b) => b.id == 'ayah_builder');
  }
  if (t.contains('sirah') ||
      t.contains('story') ||
      t.contains('birth in makkah') ||
      t.contains('halimah') ||
      t.contains('cared by family') ||
      t.contains('al-amin')) {
    return allStudentBadges.firstWhere((b) => b.id == 'sirah_storyteller');
  }
  if (t.contains('classroom hero') ||
      t.contains('respecting teachers') ||
      t.contains('showing kindness') ||
      t.contains('being responsible') ||
      t.contains('working together')) {
    return allStudentBadges.firstWhere((b) => b.id == 'classroom_hero');
  }
  if (t.contains('wudhu') ||
      t.contains('taharah') ||
      t.contains('purification') ||
      t.contains('hygiene')) {
    return allStudentBadges.firstWhere((b) => b.id == 'purification_pro');
  }
  if (t.contains('five pillars') || t.contains('pillar')) {
    return allStudentBadges.firstWhere((b) => b.id == 'pillar_builder');
  }
  if (t.contains('good deed tree') || t.contains('deed tree') || t.contains('blooming')) {
    return allStudentBadges.firstWhere((b) => b.id == 'blooming_garden');
  }
  return null;
}

