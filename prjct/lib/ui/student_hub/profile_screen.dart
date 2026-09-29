import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../data/curriculum_data.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/repositories/progress_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/recent_module_provider.dart';
import '../core_modules/lesson_player_screen.dart';
import '../core_modules/module_registry.dart';
import '../theme/app_colors.dart';
import 'notifications_sheet.dart';
import '../widgets/learner_avatar.dart';

import '../../data/student_badges.dart';

// ─── Main screen ─────────────────────────────────────────────────────────────

/// Redesigned learner profile — Madrasah Classic palette, premium feel,
/// kid-facing delight through badge showcase + celebratory hero animation.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(sessionProvider).learner;
    final streakDays = ref.watch(learnerStreakProvider);
    final completedCount = ref.watch(learnerCompletedTodayProvider);
    final unlockedBadges = ref.watch(unlockedBadgesProvider);
    final earnedCount = allStudentBadges
        .where((b) => isBadgeUnlocked(b, unlockedBadges))
        .length;

    return Scaffold(
      backgroundColor: AppColors.neutralTint,
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Hero ─────────────────────────────────────────────────────────
            _ProfileHero(
              avatar: learner?.avatar ?? '🧒',
              name: learner?.name ?? 'friend',
              age: learner?.age,
              streakDays: streakDays,
            ),

            // ── Stats bento row ──────────────────────────────────────────────
            Transform.translate(
              offset: const Offset(0, -26),
              child: _StaggerFadeIn(
                delay: const Duration(milliseconds: 80),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _StatsBento(
                    streakDays: streakDays,
                    completedCount: completedCount,
                    totalModules: coreModules.length,
                    badgeCount: earnedCount,
                  ),
                ),
              ),
            ),

            // ── Badge showcase ───────────────────────────────────────────────
            _StaggerFadeIn(
              delay: const Duration(milliseconds: 160),
              child: _BadgeShowcase(unlockedBadges: unlockedBadges),
            ),

            const SizedBox(height: 20),

            // ── Owl motivational banner ──────────────────────────────────────
            _StaggerFadeIn(
              delay: const Duration(milliseconds: 220),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _OwlBanner(name: learner?.name ?? 'friend'),
              ),
            ),

            const SizedBox(height: 20),

            _StaggerFadeIn(
              delay: const Duration(milliseconds: 240),
              child: const _AssignedHomeworkButton(),
            ),

            // ── Action rows ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 170),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StaggerFadeIn(
                    delay: const Duration(milliseconds: 270),
                    child: const _SectionLabel(label: 'Settings'),
                  ),
                  const SizedBox(height: 10),
                  _StaggerFadeIn(
                    delay: const Duration(milliseconds: 300),
                    child: _ActionRow(
                      icon: Icons.notifications_rounded,
                      label: 'Notifications',
                      sublabel: 'Manage your alerts',
                      iconBg: AppColors.adventureBlue,
                      onTap: () => NotificationsSheet.show(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StaggerFadeIn(
                    delay: const Duration(milliseconds: 340),
                    child: _ActionRow(
                      icon: Icons.face_retouching_natural_rounded,
                      label: 'My Avatar',
                      sublabel: 'Ask a grown-up to change',
                      iconBg: AppColors.gold,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Ask a grown-up to change your avatar in Settings',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StaggerFadeIn(
                    delay: const Duration(milliseconds: 380),
                    child: _ActionRow(
                      icon: Icons.switch_account_rounded,
                      label: 'Switch Account',
                      sublabel: 'Requires parent PIN',
                      iconBg: AppColors.teal,
                      onTap: () {
                        ref
                            .read(sessionProvider.notifier)
                            .selectRole(UserRole.parent);
                        context.go('/parent?from=hub');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stagger animation wrapper ────────────────────────────────────────────────

class _StaggerFadeIn extends StatefulWidget {
  const _StaggerFadeIn({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_StaggerFadeIn> createState() => _StaggerFadeInState();
}

class _StaggerFadeInState extends State<_StaggerFadeIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final _slide = Tween<Offset>(
    begin: const Offset(0, 0.10),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Profile hero ─────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.avatar,
    required this.name,
    required this.streakDays,
    this.age,
  });
  final String avatar;
  final String name;
  final int? age;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 62),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gold, AppColors.coral], // Orange/Gold gradient matching the tab active color
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Ambient decorative blobs ───────────────────────────────────
          Positioned(
            top: -10,
            right: -20,
            child: Opacity(
              opacity: 0.18,
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -15,
            child: Opacity(
              opacity: 0.12,
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // ── Arabic geometric corner ornament (top-left) ────────────────
          Positioned(
            top: 0,
            left: 0,
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(
                size: const Size(80, 80),
                painter: _GeometricOrnamentPainter(),
              ),
            ),
          ),

          // ── Streak chip (top-right) ────────────────────────────────────
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '$streakDays day streak',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Central content ────────────────────────────────────────────
          Column(
            children: [
              // Avatar with XP ring
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // XP arc ring (White dash ring in orange hero, static)
                    CustomPaint(
                      size: const Size(110, 110),
                      painter: _XpRingPainter(progress: 0.72),
                    ),

                    // Avatar circle
                    LearnerAvatar(avatar: avatar, size: 88),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Name + level
              Column(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (age != null) ...[
                        _HeroPill(
                          label: 'Age $age',
                          icon: Icons.cake_rounded,
                        ),
                        const SizedBox(width: 8),
                      ],
                      const _HeroPill(
                        label: 'Level 3',
                        icon: Icons.workspace_premium_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small pill badge used inside the hero.
class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Geometric ornament painter ──────────────────────────────────────────────

/// Simple Arabic-inspired 8-point star for background decoration.
class _GeometricOrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.46;

    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final innerAngle = angle + math.pi / 8;
      final ox = cx + r * math.cos(angle);
      final oy = cy + r * math.sin(angle);
      final ix = cx + r * 0.42 * math.cos(innerAngle);
      final iy = cy + r * 0.42 * math.sin(innerAngle);
      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, paint);

    // Outer circle
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(_GeometricOrnamentPainter oldDelegate) => false;
}

// ─── XP ring painter ─────────────────────────────────────────────────────────

class _XpRingPainter extends CustomPainter {
  const _XpRingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - 4;

    // Track
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Progress arc — white fill
    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );

    // Small tick marks around ring
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 24; i++) {
      final angle = (i / 24) * 2 * math.pi - math.pi / 2;
      final inner = r - 5;
      final outer = r + 2;
      canvas.drawLine(
        Offset(cx + inner * math.cos(angle), cy + inner * math.sin(angle)),
        Offset(cx + outer * math.cos(angle), cy + outer * math.sin(angle)),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_XpRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─── Stats bento ─────────────────────────────────────────────────────────────

class _StatsBento extends StatelessWidget {
  const _StatsBento({
    required this.streakDays,
    required this.completedCount,
    required this.totalModules,
    required this.badgeCount,
  });
  final int streakDays;
  final int completedCount;
  final int totalModules;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.creamBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A2C2C2A),
            offset: Offset(0, 6),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _BentoStat(
              value: '$streakDays',
              label: 'Day Streak',
              emoji: '🔥',
              color: const Color(0xFFD85A30),
              tint: const Color(0xFFFBEDE8),
            ),
          ),
          _BentoDivider(),
          Expanded(
            child: _BentoStat(
              value: '$completedCount/$totalModules',
              label: 'Modules',
              emoji: '📚',
              color: const Color(0xFF0F6E56),
              tint: const Color(0xFFE3F7EF),
            ),
          ),
          _BentoDivider(),
          Expanded(
            child: _BentoStat(
              value: '$badgeCount',
              label: 'Badges',
              emoji: '🏅',
              color: AppColors.gold,
              tint: AppColors.goldTint,
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.creamBorder,
    );
  }
}

class _BentoStat extends StatelessWidget {
  const _BentoStat({
    required this.value,
    required this.label,
    required this.emoji,
    required this.color,
    required this.tint,
  });
  final String value;
  final String label;
  final String emoji;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ─── Badge showcase ───────────────────────────────────────────────────────────

class _BadgeShowcase extends StatelessWidget {
  const _BadgeShowcase({required this.unlockedBadges});
  final List<String> unlockedBadges;

  @override
  Widget build(BuildContext context) {
    final earnedCount = allStudentBadges
        .where((b) => isBadgeUnlocked(b, unlockedBadges))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Row(
            children: [
              const _SectionLabel(label: 'My Badges'),
              const Spacer(),
              Text(
                '$earnedCount/${allStudentBadges.length} earned',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: allStudentBadges.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final badge = allStudentBadges[i];
              final isUnlocked = isBadgeUnlocked(badge, unlockedBadges);
              return _BadgeChip(badge: badge, isUnlocked: isUnlocked);
            },
          ),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatefulWidget {
  const _BadgeChip({required this.badge, required this.isUnlocked});
  final BadgeItem badge;
  final bool isUnlocked;

  @override
  State<_BadgeChip> createState() => _BadgeChipState();
}

class _BadgeChipState extends State<_BadgeChip> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _wobbleController;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    if (widget.isUnlocked) {
      _wobbleController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _BadgeChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isUnlocked != widget.isUnlocked) {
      if (widget.isUnlocked) {
        _wobbleController.repeat(reverse: true);
      } else {
        _wobbleController.stop();
        _wobbleController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  void _showDetails() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: widget.isUnlocked
                      ? widget.badge.color.withValues(alpha: 0.16)
                      : AppColors.creamDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isUnlocked
                        ? widget.badge.color
                        : const Color(0xFFCFC7B4),
                    width: 2.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.isUnlocked ? widget.badge.emoji : '🔒',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.badge.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.creamBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REQUIREMENT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: widget.badge.color,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.badge.requirement,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.ink,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.isUnlocked ? AppColors.mint : AppColors.neutralTint,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  widget.isUnlocked ? 'EARNED ✓' : 'LOCKED (+${widget.badge.xp} XP)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: widget.isUnlocked ? AppColors.teal : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.isUnlocked;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _showDetails();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Container(
          width: 82,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: unlocked ? const Color(0xFFFFFDF9) : const Color(0xFFF0EDE8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unlocked ? AppColors.gold : AppColors.creamBorder,
              width: unlocked ? 2.0 : 1.5,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _wobbleController,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_wobbleController.value);
                  final angle = unlocked ? (0.07 * (t - 0.5) * 2) : 0.0;
                  return Transform.rotate(
                    angle: angle,
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: unlocked
                            ? widget.badge.color.withValues(alpha: 0.18)
                            : const Color(0xFFE8E4DC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: unlocked
                              ? widget.badge.color.withValues(alpha: 0.35)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                    ),
                    Text(
                      unlocked ? widget.badge.emoji : '🔒',
                      style: TextStyle(
                        fontSize: 22,
                        color: unlocked ? null : const Color(0xFFBBB5A8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.badge.shortName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.w900,
                  color: unlocked ? const Color(0xFF8A5A12) : const Color(0xFFBBB5A8),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Owl banner ───────────────────────────────────────────────────────────────

class _OwlBanner extends StatelessWidget {
  const _OwlBanner({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mintBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Lottie.asset('assets/lottie/owl_idle.json', repeat: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salam, $name! 👋',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.tealDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You\'re doing amazing! Keep learning to unlock more badges and climb the leaderboard.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.teal,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ─── Action row ───────────────────────────────────────────────────────────────

class _ActionRow extends StatefulWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.iconBg,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sublabel;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.creamBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  // Icon bubble
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.iconBg.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: widget.iconBg.withValues(alpha: 0.4), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.icon, size: 20, color: widget.iconBg),
                  ),
                  const SizedBox(width: 14),

                  // Label + sublabel
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.sublabel,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chevron
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.neutralTint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.creamBorder, width: 1.0),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMuted,
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

class _AssignedHomeworkButton extends ConsumerWidget {
  const _AssignedHomeworkButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(sessionProvider).learner;
    if (learner == null) return const SizedBox.shrink();
    final learnerId = learner.id;
    if (learnerId == null) return const SizedBox.shrink();

    final enrollments = ClassRepository().byLearnerId(learnerId);
    final enrolledClassIds = enrollments.map((e) => e.classId).toSet();

    final List<Map<String, dynamic>> assignedList = [];

    for (final classId in enrolledClassIds) {
      final classAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: null);
      for (final a in classAssignments) {
        assignedList.add({
          'moduleId': a.moduleId,
          'maxLevel': a.maxLevel,
          'maxLessons': a.maxLessons,
        });
      }
      final personalAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: learnerId);
      for (final a in personalAssignments) {
        final existingIdx = assignedList.indexWhere((m) => m['moduleId'] == a.moduleId);
        if (existingIdx != -1) {
          assignedList[existingIdx] = {
            'moduleId': a.moduleId,
            'maxLevel': a.maxLevel,
            'maxLessons': a.maxLessons,
          };
        } else {
          assignedList.add({
            'moduleId': a.moduleId,
            'maxLevel': a.maxLevel,
            'maxLessons': a.maxLessons,
          });
        }
      }
    }

    // Count pending games/lessons
    var pendingCount = 0;
    final completed = ProgressRepository().completedLessonIds(learnerId);

    for (final assignment in assignedList) {
      final moduleId = assignment['moduleId'] as String;
      final maxLevel = assignment['maxLevel'] as int;
      final maxLessons = assignment['maxLessons'] as int?;

      final module = coreModules.firstWhere(
        (m) => m.id == moduleId || m.destinationId.toString() == moduleId,
        orElse: () => coreModules.first,
      );
      final dest = curriculum.firstWhere((d) => d.id == module.destinationId, orElse: () => curriculum.first);

      final lessons = dest.lessons;
      final perLevel = (lessons.length / 3).ceil();
      final levelsList = [
        lessons.take(perLevel).toList(),
        lessons.skip(perLevel).take(perLevel).toList(),
        lessons.skip(perLevel * 2).toList(),
      ].where((group) => group.isNotEmpty).toList();

      final List<Lesson> assignedLessons = [];
      for (var li = 0; li < maxLevel; li++) {
        if (li >= levelsList.length) break;
        final group = levelsList[li];
        final cap = (li == maxLevel - 1) ? maxLessons : null;
        final count = cap ?? group.length;
        assignedLessons.addAll(group.take(count));
      }

      pendingCount += assignedLessons.where((l) => !completed.contains(l.id)).length;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.creamBorder, width: 2),
        ),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AssignedHomeworkScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8E4FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.adventurePurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned Homework',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        assignedList.isEmpty
                            ? 'No homework yet'
                            : pendingCount > 0
                                ? '$pendingCount pending game${pendingCount == 1 ? '' : 's'} to play'
                                : 'All homework completed! 🎉',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: pendingCount > 0 ? AppColors.coral : AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.neutralTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AssignedHomeworkScreen extends ConsumerWidget {
  const AssignedHomeworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(sessionProvider).learner;
    if (learner == null) {
      return const Scaffold(
        body: Center(child: Text('No active profile')),
      );
    }
    final learnerId = learner.id;
    if (learnerId == null) {
      return const Scaffold(
        body: Center(child: Text('No active profile ID')),
      );
    }

    final enrollments = ClassRepository().byLearnerId(learnerId);
    final enrolledClassIds = enrollments.map((e) => e.classId).toSet();

    final List<Map<String, dynamic>> assignedList = [];

    for (final classId in enrolledClassIds) {
      final classAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: null);
      for (final a in classAssignments) {
        assignedList.add({
          'moduleId': a.moduleId,
          'maxLevel': a.maxLevel,
          'maxLessons': a.maxLessons,
          'assignedBy': 'Class Homework',
        });
      }
      final personalAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: learnerId);
      for (final a in personalAssignments) {
        final existingIdx = assignedList.indexWhere((m) => m['moduleId'] == a.moduleId);
        if (existingIdx != -1) {
          assignedList[existingIdx] = {
            'moduleId': a.moduleId,
            'maxLevel': a.maxLevel,
            'maxLessons': a.maxLessons,
            'assignedBy': 'Personal Assignment',
          };
        } else {
          assignedList.add({
            'moduleId': a.moduleId,
            'maxLevel': a.maxLevel,
            'maxLessons': a.maxLessons,
            'assignedBy': 'Personal Assignment',
          });
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.neutralTint,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
        ),
        title: const Text(
          'Assigned Homework',
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.creamBorder),
        ),
      ),
      body: SafeArea(
        child: assignedList.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '🎉',
                      style: TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No homework assigned!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Check back later for new tasks from your teacher.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: assignedList.length,
                itemBuilder: (context, index) {
                  final assignment = assignedList[index];
                  final moduleId = assignment['moduleId'] as String;
                  final maxLevel = assignment['maxLevel'] as int;
                  final maxLessons = assignment['maxLessons'] as int?;

                  // Look up module info
                  final module = coreModules.firstWhere(
                    (m) => m.id == moduleId || m.destinationId.toString() == moduleId,
                    orElse: () => coreModules.first,
                  );

                  // Look up destination
                  final dest = curriculum.firstWhere(
                    (d) => d.id == module.destinationId,
                    orElse: () => curriculum.first,
                  );

                  // Split lessons into levels
                  final lessons = dest.lessons;
                  final perLevel = (lessons.length / 3).ceil();
                  final levelsList = [
                    lessons.take(perLevel).toList(),
                    lessons.skip(perLevel).take(perLevel).toList(),
                    lessons.skip(perLevel * 2).toList(),
                  ].where((group) => group.isNotEmpty).toList();

                  // Gather all assigned lessons
                  final List<Lesson> assignedLessons = [];
                  for (var li = 0; li < maxLevel; li++) {
                    if (li >= levelsList.length) break;
                    final group = levelsList[li];
                    final cap = (li == maxLevel - 1) ? maxLessons : null;
                    final count = cap ?? group.length;
                    assignedLessons.addAll(group.take(count));
                  }

                  final completedLessons = ProgressRepository().completedLessonIds(learnerId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: AppColors.creamBorder, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: module.color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(module.icon, color: module.color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      module.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      assignment['assignedBy'] as String,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.creamBorder),
                          const SizedBox(height: 14),
                          if (assignedLessons.isEmpty)
                            const Text(
                              'No specific games assigned.',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            )
                          else
                            ...assignedLessons.map((lesson) {
                              final done = completedLessons.contains(lesson.id);

                              // Find which level this lesson belongs to
                              var levelName = 'Beginner';
                              for (var li = 0; li < levelsList.length; li++) {
                                if (levelsList[li].any((l) => l.id == lesson.id)) {
                                  levelName = switch (li) {
                                    0 => 'Beginner',
                                    1 => 'Practice',
                                    _ => 'Mastery',
                                  };
                                  break;
                                }
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () {
                                    ref.read(recentModuleProvider.notifier).interactWith(module.id);
                                    Navigator.of(context, rootNavigator: true).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => LessonPlayerScreen(
                                          lesson: lesson,
                                          destinationId: dest.id,
                                          onClose: () {
                                            Navigator.of(context, rootNavigator: true).pop();
                                            // Re-trigger rebuild
                                            ref.invalidate(sessionProvider);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.neutralTint,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: done ? AppColors.mint : Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            done ? '✓' : lesson.icon,
                                            style: TextStyle(
                                              fontSize: done ? 14 : 18,
                                              fontWeight: done ? FontWeight.bold : null,
                                              color: done ? AppColors.adventureGreen : null,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                lesson.title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: done ? AppColors.textMuted : AppColors.ink,
                                                  decoration: done ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                levelName,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          done ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                                          color: done ? AppColors.adventureGreen : AppColors.adventureBlue,
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// Removed old _AssignedHomeworkSection class.
