import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';

typedef _Badge = ({
  String name,
  String description,
  IconData icon,
  Color color,
  int xp,
});

const _badges = <_Badge>[
  (
    name: 'First Steps',
    description: 'Started your learning journey',
    icon: Icons.child_care_rounded,
    color: AppColors.teal,
    xp: 50,
  ),
  (
    name: 'Active Learner',
    description: 'Earned a 5-day learning streak',
    icon: Icons.local_fire_department,
    color: AppColors.gold,
    xp: 100,
  ),
  (
    name: 'TRACING Master',
    description: 'Completed the Tracing activity',
    icon: Icons.draw_outlined,
    color: AppColors.mintGreen,
    xp: 150,
  ),
  (
    name: 'FLASHCARDS Master',
    description: 'Listened to all Alphabet Sounds',
    icon: Icons.volume_up_outlined,
    color: AppColors.coral,
    xp: 150,
  ),
  (
    name: 'RECITATION Master',
    description: 'Completed Pronunciation class',
    icon: Icons.menu_book_outlined,
    color: Colors.blue,
    xp: 200,
  ),
];

typedef _Sticker = ({
  String emoji,
  String name,
  bool unlocked,
  String unlockDesc,
});

const _stickers = <_Sticker>[
  (emoji: '🌙', name: 'Moon', unlocked: true, unlockDesc: 'Complete any lesson'),
  (emoji: '⭐', name: 'Star', unlocked: true, unlockDesc: 'Complete any lesson'),
  (emoji: '🕌', name: 'Masjid', unlocked: true, unlockDesc: 'Reach Cleanliness & Character'),
  (emoji: '🌸', name: 'Flower', unlocked: true, unlockDesc: 'Reach A Growing Muslim'),
  (emoji: '🐢', name: 'Turtle', unlocked: true, unlockDesc: 'Start your journey'),
  (emoji: '🌴', name: 'Palm', unlocked: false, unlockDesc: 'Complete Exploring Our World'),
  (emoji: '🦋', name: 'Butterfly', unlocked: false, unlockDesc: 'Finish A Growing Muslim'),
  (emoji: '🌊', name: 'Wave', unlocked: false, unlockDesc: 'Finish Stories & Letters'),
  (emoji: '🏔️', name: 'Mountain', unlocked: false, unlockDesc: 'Reach The Path of the Prophet'),
  (emoji: '📖', name: 'Book', unlocked: false, unlockDesc: 'Finish The Good Deed Hero'),
];

typedef _GearItem = ({
  String name,
  String description,
  String emoji,
  double progress,
  String unlockDesc,
});

const _gearItems = <_GearItem>[
  (
    name: 'Travel Prayer Mat',
    description: 'A soft, portable rug for prayers.',
    emoji: '🕋',
    progress: 1.0,
    unlockDesc: 'Unlocked via Streak Star',
  ),
  (
    name: 'Olive Wood Miswak',
    description: 'Traditional natural toothbrush.',
    emoji: '🪵',
    progress: 0.6,
    unlockDesc: 'Complete 3 Sound lessons',
  ),
  (
    name: 'Zamzam Flask',
    description: 'Keep your blessed water cool.',
    emoji: '🍶',
    progress: 0.4,
    unlockDesc: 'Complete 5 Tracing exercises',
  ),
  (
    name: 'Quran Pointer (Siba)',
    description: 'Beautiful carved pointer for reading.',
    emoji: '✏️',
    progress: 0.0,
    unlockDesc: 'Complete Qur\'an Explorer',
  ),
];

class BackpackScreen extends ConsumerStatefulWidget {
  const BackpackScreen({super.key});

  @override
  ConsumerState<BackpackScreen> createState() => _BackpackScreenState();
}

class _BackpackScreenState extends ConsumerState<BackpackScreen> {
  int _selectedTab = 0; // 0 = Badges, 1 = Gear, 2 = Stickers

  @override
  void initState() {
    super.initState();
    // Clears the bottom nav's "something new" dot — this screen is what
    // that dot points at, so opening it counts as having seen everything
    // currently earned.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final count = ref.read(unlockedBadgesProvider).length;
      ref.read(seenBadgeCountProvider.notifier).markSeen(count);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unlockedBadges = ref.watch(unlockedBadgesProvider);
    final earnedCount = _badges
        .where((b) => unlockedBadges.contains(b.name))
        .length;

    return Scaffold(
      backgroundColor: AppColors.neutralTint,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            // Hero Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 38, 18, 0),
              sliver: SliverToBoxAdapter(child: _buildHeroHeader(earnedCount)),
            ),

            // Tab Selector
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              sliver: SliverToBoxAdapter(child: _buildTabSelector()),
            ),

            // Dynamic Tab Contents
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              sliver: switch (_selectedTab) {
                0 => _buildBadgesGrid(unlockedBadges),
                1 => _buildGearGrid(),
                _ => _buildStickersGrid(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(int earnedCount) {
    final gradientColors = _tabGradient(_selectedTab);
    return AnimatedContainer(
      key: const Key('backpack-hero-tile'),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background blobs
          Positioned(
            right: -30,
            top: -30,
            child: CircleAvatar(
              radius: 70,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -40,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _IdleTiltChest(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Digital Backpack',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'Level 3 Explorer',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.adventurePurple,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '$earnedCount / ${_badges.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '$earnedCount of ${_badges.length} badges earned',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '800 / 1000 XP',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  // Drifting coins/sparkles rising from the open chest.
                  const Positioned(
                    left: 20,
                    bottom: -4,
                    child: _FloatingCoin(
                      emoji: '🪙',
                      dx: -14,
                      delay: Duration.zero,
                    ),
                  ),
                  const Positioned(
                    left: 110,
                    bottom: -4,
                    child: _FloatingCoin(
                      emoji: '🪙',
                      dx: 10,
                      delay: Duration(milliseconds: 1100),
                    ),
                  ),
                  const Positioned(
                    left: 170,
                    bottom: -4,
                    child: _FloatingCoin(
                      emoji: '✨',
                      dx: -6,
                      delay: Duration(milliseconds: 2200),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: 0.8,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surface, AppColors.cream],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.creamBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x154A3A1E),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          // Sliding indicator background pill
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(-1.0 + _selectedTab * 1.0, 0.0),
              duration: const Duration(milliseconds: 320),
              curve: const Cubic(0.34, 1.56, 0.64, 1.0), // Playful overshoot bounce
              child: FractionallySizedBox(
                widthFactor: 0.32,
                heightFactor: 0.95,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _tabGradient(_selectedTab)),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _tabGradient(_selectedTab).first.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The tabs Row
          Row(
            children: [
              _buildTabItem(0, Icons.workspace_premium_rounded, 'Badges'),
              _buildTabItem(1, Icons.backpack_rounded, 'Inventory'),
              _buildTabItem(2, Icons.auto_awesome_rounded, 'Stickers'),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _tabGradient(int tab) => switch (tab) {
    0 => const [AppColors.teal, AppColors.mintGreen],
    1 => const [AppColors.adventureBlue, AppColors.adventurePurple],
    _ => const [AppColors.gold, AppColors.coral],
  };

  Widget _buildTabItem(int index, IconData icon, String label) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          color: Colors.transparent, // Expand tap target
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: active ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: active ? Colors.white : AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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

  Widget _buildBadgesGrid(List<String> unlockedBadges) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final badge = _badges[index];
        final earned = unlockedBadges.contains(badge.name);
        return _buildBadgeCard(badge, earned);
      }, childCount: _badges.length),
    );
  }

  Widget _buildGearGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = _gearItems[index];
        return _buildGearCard(item);
      }, childCount: _gearItems.length),
    );
  }

  Widget _buildStickersGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final sticker = _stickers[index];
        return _buildStickerCard(sticker);
      }, childCount: _stickers.length),
    );
  }

  Widget _buildStickerCard(_Sticker sticker) {
    final unlocked = sticker.unlocked;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: unlocked
              ? AppColors.gold.withValues(alpha: 0.35)
              : AppColors.creamBorder,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x062C2C2A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showStickerDetails(context, sticker),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: unlocked
                          ? AppColors.gold.withValues(alpha: 0.12)
                          : AppColors.creamDark.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: unlocked ? AppColors.gold : const Color(0xFFCFC7B4),
                        width: 2.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: unlocked
                          ? _buildLottieForSticker(sticker, size: 48)
                          : const Text(
                              '🔒',
                              style: TextStyle(fontSize: 28),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  sticker.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: unlocked ? AppColors.goldTint : AppColors.neutralTint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    unlocked ? 'Earned' : 'Locked',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: unlocked ? AppColors.gold : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(_Badge badge, bool earned) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: earned
              ? badge.color.withValues(alpha: 0.35)
              : AppColors.creamBorder,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x062C2C2A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showBadgeDetails(context, badge, earned),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: earned
                          ? badge.color.withValues(alpha: 0.12)
                          : AppColors.creamDark.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: earned ? badge.color : const Color(0xFFCFC7B4),
                        width: 2.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: earned
                          ? _buildLottieForBadge(badge, size: 48)
                          : const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFFB9B2A2),
                              size: 28,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: earned ? AppColors.mint : AppColors.neutralTint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    earned ? 'Earned' : 'Locked',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: earned ? AppColors.teal : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGearCard(_GearItem item) {
    final unlocked = item.progress >= 1.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: unlocked
              ? AppColors.adventureGreen.withValues(alpha: 0.35)
              : AppColors.creamBorder,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x062C2C2A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showGearDetails(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: unlocked
                          ? AppColors.adventureGreen.withValues(alpha: 0.12)
                          : AppColors.neutralTint,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: unlocked
                            ? AppColors.adventureGreen
                            : const Color(0xFFCFC7B4),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        unlocked ? item.emoji : '🔒',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked ? 'Equipped' : item.unlockDesc,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    // Text (not just a decorative fill) needs AA contrast —
                    // adventureGreen is ~3.45:1 on white, below the 4.5:1
                    // normal-text threshold at this size, so labels keep
                    // teal (~6.2:1) while the icon/border accents above use
                    // adventureGreen freely as pure graphic elements.
                    color: unlocked ? AppColors.teal : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 5,
                    backgroundColor: AppColors.neutralTint,
                    valueColor: AlwaysStoppedAnimation(
                      unlocked ? AppColors.teal : AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, _Badge badge, bool earned) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'BadgeDetails',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = Tween<double>(
          begin: 0.85,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack));
        final opacity = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut));

        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: opacity,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (earned)
                          _CelebratingGlow(color: badge.color)
                        else
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: AppColors.neutralTint,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: earned
                                ? badge.color.withValues(alpha: 0.15)
                                : AppColors.creamDark,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: earned
                                  ? badge.color
                                  : const Color(0xFFCFC7B4),
                              width: 3.5,
                            ),
                            boxShadow: earned
                                ? [
                                    BoxShadow(
                                      color: badge.color.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: earned
                              ? Center(child: _buildLottieForBadge(badge, size: 68))
                              : const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Color(0xFFB9B2A2),
                                  size: 44,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      badge.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badge.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    if (!earned) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.goldTint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+${badge.xp} XP reward',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: earned ? AppColors.mint : AppColors.neutralTint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        earned ? 'EARNED' : 'LOCKED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: earned ? AppColors.teal : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGearDetails(BuildContext context, _GearItem item) {
    final unlocked = item.progress >= 1.0;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'GearDetails',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = Tween<double>(
          begin: 0.85,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack));
        final opacity = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut));

        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: opacity,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: unlocked
                            ? AppColors.adventureGreen.withValues(alpha: 0.12)
                            : AppColors.neutralTint,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: unlocked
                              ? AppColors.adventureGreen
                              : const Color(0xFFCFC7B4),
                          width: 3.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unlocked ? item.emoji : '🔒',
                        style: const TextStyle(fontSize: 44),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!unlocked) ...[
                      Text(
                        'Unlock rule: ${item.unlockDesc}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.coral,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: unlocked
                            ? AppColors.adventureGreen.withValues(alpha: 0.14)
                            : AppColors.neutralTint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        unlocked ? 'EQUIPPED' : 'IN PROGRESS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          // Text stays teal for AA contrast — see the
                          // matching note above on the badge-card label.
                          color: unlocked
                              ? AppColors.teal
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showStickerDetails(BuildContext context, _Sticker sticker) {
    final unlocked = sticker.unlocked;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'StickerDetails',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = Tween<double>(
          begin: 0.85,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack));
        final opacity = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut));

        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: opacity,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: unlocked
                            ? AppColors.gold.withValues(alpha: 0.15)
                            : AppColors.creamDark,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: unlocked ? AppColors.gold : const Color(0xFFCFC7B4),
                          width: 3.5,
                        ),
                        boxShadow: unlocked
                            ? [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: unlocked
                          ? _buildLottieForSticker(sticker, size: 68)
                          : const Text(
                              '🔒',
                              style: TextStyle(fontSize: 44),
                            ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      sticker.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    if (!unlocked) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gold, width: 1.6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'HOW TO UNLOCK',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.gold,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sticker.unlockDesc,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: unlocked ? AppColors.goldTint : AppColors.neutralTint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        unlocked ? 'EARNED' : 'LOCKED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: unlocked ? AppColors.gold : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLottieForBadge(_Badge badge, {double size = 48}) {
    final String assetPath;
    switch (badge.name) {
      case 'First Steps':
        assetPath = 'assets/lottie/xp_star.json';
        break;
      case 'Active Learner':
        assetPath = 'assets/lottie/flame_streak.json';
        break;
      case 'TRACING Master':
        assetPath = 'assets/lottie/goal_target.json';
        break;
      case 'FLASHCARDS Master':
        assetPath = 'assets/lottie/cast_ripple.json';
        break;
      case 'RECITATION Master':
        assetPath = 'assets/lottie/milestone_burst.json';
        break;
      default:
        return Icon(badge.icon, color: badge.color, size: size);
    }
    return Lottie.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  Widget _buildLottieForSticker(_Sticker sticker, {double size = 48}) {
    final String assetPath;
    switch (sticker.emoji) {
      case '⭐':
        assetPath = 'assets/lottie/xp_star.json';
        break;
      case '🌙':
        assetPath = 'assets/lottie/noor_glow.json';
        break;
      case '🕌':
        assetPath = 'assets/lottie/milestone_burst.json';
        break;
      case '🌸':
        assetPath = 'assets/lottie/milestone_burst.json';
        break;
      case '🐢':
        assetPath = 'assets/lottie/owl_idle.json';
        break;
      case '🌴':
        assetPath = 'assets/lottie/flame_streak.json';
        break;
      case '🦋':
        assetPath = 'assets/lottie/cast_ripple.json';
        break;
      case '🌊':
        assetPath = 'assets/lottie/cast_ripple.json';
        break;
      case '🏔️':
        assetPath = 'assets/lottie/goal_target.json';
        break;
      case '📖':
        assetPath = 'assets/lottie/practice_complete.json';
        break;
      default:
        return Text(sticker.emoji, style: TextStyle(fontSize: size * 0.6));
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Lottie.asset(
          assetPath,
          width: size * 1.5,
          height: size * 1.5,
          fit: BoxFit.contain,
        ),
        if (sticker.emoji != '⭐')
          Text(
            sticker.emoji,
            style: TextStyle(fontSize: size * 0.58),
          ),
      ],
    );
  }
}

/// The chest emoji badge, idle-tilting ±4° on the shared 3400ms ambient
/// rhythm used across the Adventure Map's current-destination node.
class _IdleTiltChest extends StatefulWidget {
  const _IdleTiltChest();

  @override
  State<_IdleTiltChest> createState() => _IdleTiltChestState();
}

class _IdleTiltChestState extends State<_IdleTiltChest>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.rotate(angle: (t * 2 - 1) * 0.07, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: const Text('🧰', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

/// A single coin/sparkle drifting up out of the chest and fading, looping
/// forever with a per-instance start delay — same rhythm family as the
/// Adventure Map's `_Sparkle`.
class _FloatingCoin extends StatefulWidget {
  const _FloatingCoin({
    required this.emoji,
    required this.dx,
    required this.delay,
  });

  final String emoji;
  final double dx;
  final Duration delay;

  @override
  State<_FloatingCoin> createState() => _FloatingCoinState();
}

class _FloatingCoinState extends State<_FloatingCoin>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _startTimer = Timer(widget.delay, () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final opacity = t < 0.15
              ? t / 0.15
              : t < 0.85
              ? 1.0
              : (1 - t) / 0.15;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0) * 0.85,
            child: Transform.translate(
              offset: Offset(widget.dx * t, -70 * t),
              child: Transform.rotate(
                angle: t * 3.5,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CelebratingGlow extends StatefulWidget {
  const _CelebratingGlow({required this.color});
  final Color color;

  @override
  State<_CelebratingGlow> createState() => _CelebratingGlowState();
}

class _CelebratingGlowState extends State<_CelebratingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Transform.rotate(
          angle: _c.value * 2 * math.pi,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  widget.color.withValues(alpha: 0.0),
                  widget.color.withValues(alpha: 0.35),
                  widget.color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
