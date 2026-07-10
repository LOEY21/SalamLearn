import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';

typedef _Badge = ({
  String name,
  String description,
  IconData icon,
  Color color,
});

const _badges = <_Badge>[
  (
    name: 'First Steps',
    description: 'Started your learning journey',
    icon: Icons.child_care_rounded,
    color: AppColors.teal,
  ),
  (
    name: 'Active Learner',
    description: 'Earned a 5-day learning streak',
    icon: Icons.local_fire_department,
    color: AppColors.gold,
  ),
  (
    name: 'TRACING Master',
    description: 'Completed the Tracing activity',
    icon: Icons.draw_outlined,
    color: AppColors.mintGreen,
  ),
  (
    name: 'FLASHCARDS Master',
    description: 'Listened to all Alphabet Sounds',
    icon: Icons.volume_up_outlined,
    color: AppColors.coral,
  ),
  (
    name: 'RECITATION Master',
    description: 'Completed Pronunciation class',
    icon: Icons.menu_book_outlined,
    color: Colors.blue,
  ),
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
  int _selectedTab = 0; // 0 = Badges, 1 = Gear

  @override
  Widget build(BuildContext context) {
    final unlockedBadges = ref.watch(unlockedBadgesProvider);
    final earnedCount = _badges.where((b) => unlockedBadges.contains(b.name)).length;

    return Scaffold(
      backgroundColor: AppColors.neutralTint,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Hero Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              sliver: SliverToBoxAdapter(
                child: _buildHeroHeader(earnedCount),
              ),
            ),

            // Tab Selector
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              sliver: SliverToBoxAdapter(
                child: _buildTabSelector(),
              ),
            ),

            // Dynamic Tab Contents
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              sliver: _selectedTab == 0
                  ? _buildBadgesGrid(unlockedBadges)
                  : _buildGearGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(int earnedCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.tealDark, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0A4F3E),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background blobs
          Positioned(
            right: -30,
            top: -30,
            child: CircleAvatar(
              radius: 70,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -40,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withValues(alpha: 0.03),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🎒', style: TextStyle(fontSize: 24)),
                  ),
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
                      color: AppColors.coral,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$earnedCount of ${_badges.length} badges earned',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamBorder, width: 1.5),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 16,
                      color: _selectedTab == 0 ? Colors.white : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Badges',
                      style: TextStyle(
                        color: _selectedTab == 0 ? Colors.white : AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.backpack_rounded,
                      size: 16,
                      color: _selectedTab == 1 ? Colors.white : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Inventory',
                      style: TextStyle(
                        color: _selectedTab == 1 ? Colors.white : AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final badge = _badges[index];
          final earned = unlockedBadges.contains(badge.name);
          return _buildBadgeCard(badge, earned);
        },
        childCount: _badges.length,
      ),
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
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = _gearItems[index];
          return _buildGearCard(item);
        },
        childCount: _gearItems.length,
      ),
    );
  }

  Widget _buildBadgeCard(_Badge badge, bool earned) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
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
                        color: earned
                            ? badge.color
                            : const Color(0xFFCFC7B4),
                        width: 2.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Icon(
                        earned ? badge.icon : Icons.lock_outline_rounded,
                        color: earned ? badge.color : const Color(0xFFB9B2A2),
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
                    color: earned
                        ? AppColors.mint
                        : AppColors.neutralTint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    earned ? 'Earned' : 'Locked',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color:
                          earned ? AppColors.teal : AppColors.textMuted,
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: unlocked
              ? AppColors.mintBorder
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
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showGearDetails(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: unlocked
                          ? AppColors.mint.withValues(alpha: 0.5)
                          : AppColors.neutralTint,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: unlocked
                            ? AppColors.mintBorder
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
        final scale = Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        );
        final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: anim1, curve: Curves.easeOut),
        );

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
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                                      color: badge.color.withValues(alpha: 0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Icon(
                            earned
                                ? badge.icon
                                : Icons.lock_outline_rounded,
                            color: earned
                                ? badge.color
                                : const Color(0xFFB9B2A2),
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
        final scale = Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        );
        final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: anim1, curve: Curves.easeOut),
        );

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
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: unlocked
                            ? AppColors.mint.withValues(alpha: 0.5)
                            : AppColors.neutralTint,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: unlocked
                              ? AppColors.mintBorder
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
                        color: unlocked ? AppColors.mint : AppColors.neutralTint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        unlocked ? 'EQUIPPED' : 'IN PROGRESS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: unlocked ? AppColors.teal : AppColors.textMuted,
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
