import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../logic/auth/session.dart';
import '../../logic/recent_module_provider.dart';
import '../core_modules/module_registry.dart';
import '../theme/app_colors.dart';
import 'notifications_sheet.dart';
import '../widgets/learner_avatar.dart';

// ─── Badge data ──────────────────────────────────────────────────────────────

/// Each badge the learner can earn. [icon] uses emoji for kid-facing delight,
/// [color] is the filled bg tint, [lockedColor] the greyed-out version.
class _BadgeDef {
  const _BadgeDef({
    required this.id,
    required this.icon,
    required this.label,
    required this.color,
  });
  final String id;
  final String icon;
  final String label;
  final Color color;
}

const _allBadges = [
  _BadgeDef(
    id: 'first_steps',
    icon: '👣',
    label: 'First Steps',
    color: Color(0xFF5BC4A0),
  ),
  _BadgeDef(
    id: 'active_learner',
    icon: '⚡',
    label: 'Active Learner',
    color: Color(0xFFEF9F27),
  ),
  _BadgeDef(
    id: 'streak_3',
    icon: '🔥',
    label: '3-Day Streak',
    color: Color(0xFFD85A30),
  ),
  _BadgeDef(
    id: 'perfect_score',
    icon: '⭐',
    label: 'Perfect Score',
    color: AppColors.adventurePurple,
  ),
  _BadgeDef(
    id: 'bookworm',
    icon: '📚',
    label: 'Bookworm',
    color: Color(0xFF0F6E56),
  ),
  _BadgeDef(
    id: 'champion',
    icon: '🏆',
    label: 'Champion',
    color: Color(0xFFE64E6A),
  ),
];

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

    // Map unlocked badge IDs (case-insensitive label match) for badge strip.
    final unlockedIds = unlockedBadges
        .map((b) => b.toLowerCase().replaceAll(' ', '_'))
        .toSet();

    return Scaffold(
      backgroundColor: AppColors.neutralTint,
      body: SafeArea(
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
                    badgeCount: unlockedBadges.length,
                  ),
                ),
              ),
            ),

            // ── Badge showcase ───────────────────────────────────────────────
            _StaggerFadeIn(
              delay: const Duration(milliseconds: 160),
              child: _BadgeShowcase(unlockedIds: unlockedIds),
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

            // ── Action rows ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
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
                      icon: Icons.lock_rounded,
                      label: 'Parent Settings',
                      sublabel: 'Requires PIN',
                      iconBg: AppColors.teal,
                      onTap: () {
                        ref
                            .read(sessionProvider.notifier)
                            .selectRole(UserRole.parent);
                        context.go('/settings?from=hub');
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

class _ProfileHero extends StatefulWidget {
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
  State<_ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends State<_ProfileHero>
    with TickerProviderStateMixin {
  // Entrance: avatar pops in with playful overshoot.
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  late final _avatarScale = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOutBack,
  );
  late final _avatarFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0, 0.45, curve: Curves.easeOut),
  );
  late final _nameFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.4, 1, curve: Curves.easeOut),
  );
  late final _nameSlide = Tween<Offset>(
    begin: const Offset(0, 0.25),
    end: Offset.zero,
  ).animate(_nameFade);

  // Ambient: slow breathing glow behind the avatar.
  late final _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  // XP ring continuous gentle spin.
  late final _ringRotate = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _entrance.dispose();
    _breathe.dispose();
    _ringRotate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 62),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D7A60), AppColors.tealDark],
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
          AnimatedBuilder(
            animation: _breathe,
            builder: (_, __) {
              final t = Curves.easeInOut.transform(_breathe.value);
              return Positioned(
                top: -20 + t * 14,
                right: -28,
                child: Opacity(
                  opacity: 0.16 + t * 0.10,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _breathe,
            builder: (_, __) {
              final t = Curves.easeInOut.transform(_breathe.value);
              return Positioned(
                bottom: -30 - t * 10,
                left: -20,
                child: Opacity(
                  opacity: 0.10 + t * 0.08,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
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
            child: FadeTransition(
              opacity: _nameFade,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.streakDays} day streak',
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
          ),

          // ── Central content ────────────────────────────────────────────
          Column(
            children: [
              // Avatar with spinning XP ring
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Celebration burst (one-shot)
                    IgnorePointer(
                      child: Lottie.asset(
                        'assets/lottie/milestone_burst.json',
                        repeat: false,
                        width: 130,
                        height: 130,
                      ),
                    ),

                    // Slowly-rotating XP arc ring
                    AnimatedBuilder(
                      animation: _ringRotate,
                      builder: (_, __) => Transform.rotate(
                        angle: _ringRotate.value * 2 * math.pi,
                        child: CustomPaint(
                          size: const Size(110, 110),
                          painter: _XpRingPainter(progress: 0.72),
                        ),
                      ),
                    ),

                    // Avatar circle
                    ScaleTransition(
                      scale: _avatarScale,
                      child: FadeTransition(
                        opacity: _avatarFade,
                        child: LearnerAvatar(avatar: widget.avatar, size: 88),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Name + level
              FadeTransition(
                opacity: _nameFade,
                child: SlideTransition(
                  position: _nameSlide,
                  child: Column(
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.age != null) ...[
                            _HeroPill(
                              label: 'Age ${widget.age}',
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
                ),
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

    // Progress arc — gold fill
    final progressPaint = Paint()
      ..color = AppColors.gold
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.creamBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A2C2C2A),
            offset: Offset(0, 6),
            blurRadius: 16,
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
              emoji: '✅',
              color: const Color(0xFF5BC4A0),
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
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ─── Badge showcase ───────────────────────────────────────────────────────────

class _BadgeShowcase extends StatelessWidget {
  const _BadgeShowcase({required this.unlockedIds});
  final Set<String> unlockedIds;

  @override
  Widget build(BuildContext context) {
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
                '${unlockedIds.length}/${_allBadges.length} earned',
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
          height: 102,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: _allBadges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final badge = _allBadges[i];
              // Match by badge label normalisation.
              final labelKey = badge.label.toLowerCase().replaceAll(' ', '_');
              final isUnlocked =
                  unlockedIds.contains(labelKey) ||
                  unlockedIds.contains(badge.id);
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
  final _BadgeDef badge;
  final bool isUnlocked;

  @override
  State<_BadgeChip> createState() => _BadgeChipState();
}

class _BadgeChipState extends State<_BadgeChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.isUnlocked;
    return GestureDetector(
      onTapDown: unlocked ? (_) => setState(() => _pressed = true) : null,
      onTapUp: unlocked ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: unlocked ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Container(
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: unlocked
                ? widget.badge.color.withValues(alpha: 0.12)
                : const Color(0xFFF0EDE8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unlocked
                  ? widget.badge.color.withValues(alpha: 0.35)
                  : AppColors.creamBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: unlocked
                          ? widget.badge.color.withValues(alpha: 0.18)
                          : const Color(0xFFE8E4DC),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    unlocked ? widget.badge.icon : '🔒',
                    style: TextStyle(
                      fontSize: 20,
                      color: unlocked ? null : const Color(0xFFBBB5A8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.badge.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: unlocked
                      ? widget.badge.color
                      : const Color(0xFFBBB5A8),
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
                    fontWeight: FontWeight.w800,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.sublabel,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
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
