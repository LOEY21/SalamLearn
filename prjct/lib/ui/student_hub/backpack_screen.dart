import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/student_badges.dart';
import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';
import 'hub_world.dart';

/// The learner's badge collection: a slice of the Adventure Map as the
/// header, then the badges standing on wooden shelves in a cabinet —
/// earned ones in full colour, locked ones as greyed silhouettes.
class BackpackScreen extends ConsumerStatefulWidget {
  const BackpackScreen({super.key});

  @override
  ConsumerState<BackpackScreen> createState() => _BackpackScreenState();
}

class _BackpackScreenState extends ConsumerState<BackpackScreen> {
  BadgeCategory _category = BadgeCategory.milestone;

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
    final unlocked = ref.watch(unlockedBadgesProvider);
    final earnedCount = allStudentBadges
        .where((b) => isBadgeUnlocked(b, unlocked))
        .length;
    final shelfBadges = _category == BadgeCategory.milestone
        ? milestoneBadges
        : streakBadges;

    return Scaffold(
      backgroundColor: HubWorld.parchment,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _BackpackHeader(
              earned: earnedCount,
              total: allStudentBadges.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            sliver: SliverToBoxAdapter(
              child: _CategoryTabs(
                selected: _category,
                onSelect: (c) => setState(() => _category = c),
              ),
            ),
          ),
          SliverPadding(
            // Clears the floating bottom nav (HubShell uses extendBody).
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
            sliver: SliverToBoxAdapter(
              child: _BadgeCabinet(
                badges: shelfBadges,
                unlocked: unlocked,
                onOpen: (badge, earned) =>
                    showBadgeDetailSheet(context, badge, earned: earned),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _BackpackHeader extends StatelessWidget {
  const _BackpackHeader({required this.earned, required this.total});

  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (earned / total).clamp(0.0, 1.0);
    return MapSceneHeader(
      height: 236,
      image: HubWorld.backpackArt,
      focusX: 0.35,
      focusY: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const _BobbingBackpack(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Digital Backpack',
                        style: hubText(
                          26,
                          Colors.white,
                          height: 1.1,
                          shadows: hubTextShadow,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$earned of $total badges earned',
                        style: hubText(
                          15,
                          HubWorld.onScene,
                          weight: 600,
                          shadows: hubTextShadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _WoodProgressBar(value: progress),
          ],
        ),
      ),
    );
  }
}

/// The nav's backpack art, gently bobbing like the map's current node.
class _BobbingBackpack extends StatefulWidget {
  const _BobbingBackpack();

  @override
  State<_BobbingBackpack> createState() => _BobbingBackpackState();
}

class _BobbingBackpackState extends State<_BobbingBackpack>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (hubMotionOn(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

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
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -4 * t),
          child: Transform.rotate(angle: (t - 0.5) * 0.08, child: child),
        );
      },
      child: Image.asset(
        'assets/images/adventure_map/tab_backpack.png',
        width: 78,
        height: 78,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _WoodProgressBar extends StatelessWidget {
  const _WoodProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: HubWorld.wood,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.goldSoft, width: 1.2),
      ),
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutQuart,
              width: value == 0 ? 0 : math.max(10, c.maxWidth * value),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [HubWorld.goldLight, AppColors.gold],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category tabs ───────────────────────────────────────────────────────────

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onSelect});

  final BadgeCategory selected;
  final ValueChanged<BadgeCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget tab(BadgeCategory c, IconData icon, String label) {
      final active = c == selected;
      return Expanded(
        child: ChunkyButton(
          onTap: active ? null : () => onSelect(c),
          face: active ? AppColors.gold : Colors.white,
          edge: active ? HubWorld.goldDeep : HubWorld.edge,
          border: active ? null : AppColors.creamBorder,
          radius: 18,
          depth: active ? 4 : 5,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          semanticLabel: label,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? HubWorld.wood : HubWorld.inkSoft,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: hubText(
                    16,
                    active ? HubWorld.wood : HubWorld.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(BadgeCategory.milestone, Icons.emoji_events_rounded, 'Milestones'),
        const SizedBox(width: 12),
        tab(BadgeCategory.streak, Icons.local_fire_department_rounded, 'Streaks'),
      ],
    );
  }
}

// ─── Cabinet + shelves ───────────────────────────────────────────────────────

class _BadgeCabinet extends StatelessWidget {
  const _BadgeCabinet({
    required this.badges,
    required this.unlocked,
    required this.onOpen,
  });

  final List<BadgeItem> badges;
  final List<String> unlocked;
  final void Function(BadgeItem badge, bool earned) onOpen;

  @override
  Widget build(BuildContext context) {
    return QuestPanel(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          final perShelf = c.maxWidth >= 720
              ? 5
              : c.maxWidth >= 520
              ? 4
              : 3;
          final shelves = <List<BadgeItem>>[
            for (var i = 0; i < badges.length; i += perShelf)
              badges.sublist(i, math.min(i + perShelf, badges.length)),
          ];
          return Column(
            children: [
              for (final shelf in shelves) ...[
                // Equal-height slots: medals line up along the top and
                // "Earned/Locked" along the bottom, whatever the name length.
                IntrinsicHeight(
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < perShelf; i++)
                      Expanded(
                        child: i < shelf.length
                            ? _ShelfBadge(
                                badge: shelf[i],
                                earned: isBadgeUnlocked(shelf[i], unlocked),
                                onTap: () => onOpen(
                                  shelf[i],
                                  isBadgeUnlocked(shelf[i], unlocked),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                  ),
                ),
                const _ShelfPlank(),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ShelfPlank extends StatelessWidget {
  const _ShelfPlank();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 10,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [HubWorld.woodLight, HubWorld.woodMid],
            ),
          ),
        ),
        Container(
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            color: HubWorld.wood,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
            boxShadow: [
              BoxShadow(
                color: Color(0x404A3A1E),
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShelfBadge extends StatefulWidget {
  const _ShelfBadge({
    required this.badge,
    required this.earned,
    required this.onTap,
  });

  final BadgeItem badge;
  final bool earned;
  final VoidCallback onTap;

  @override
  State<_ShelfBadge> createState() => _ShelfBadgeState();
}

class _ShelfBadgeState extends State<_ShelfBadge> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final earned = widget.earned;
    return Semantics(
      button: true,
      label: '${widget.badge.shortName.tr}, ${earned ? 'Earned'.tr : 'Locked'.tr}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.93 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                BadgeMedallion(badge: widget.badge, earned: earned, size: 74),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    widget.badge.shortName,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: hubText(
                      13.5,
                      earned ? AppColors.ink : HubWorld.inkSoft,
                      weight: 750,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      earned ? Icons.check_circle_rounded : Icons.lock_rounded,
                      size: 13,
                      color: earned ? AppColors.teal : HubWorld.inkSoft,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        earned ? 'Earned' : 'Locked',
                        overflow: TextOverflow.ellipsis,
                        style: hubText(
                          12,
                          earned ? AppColors.teal : HubWorld.inkSoft,
                          weight: 700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A badge's illustrated medal: full colour when earned, a faded grey
/// silhouette with a padlock when still locked.
class BadgeMedallion extends StatelessWidget {
  const BadgeMedallion({
    super.key,
    required this.badge,
    required this.earned,
    required this.size,
  });

  final BadgeItem badge;
  final bool earned;
  final double size;

  static const _greyscale = ColorFilter.matrix([
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final art = Image.asset(
      badge.artAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: badge.name,
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (earned)
            _GlowingArt(badge: badge, size: size, art: art)
          else
            Opacity(
              opacity: 0.4,
              child: ColorFiltered(colorFilter: _greyscale, child: art),
            ),
          if (!earned)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  color: HubWorld.wood,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldSoft, width: 1.5),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: size * 0.19,
                  color: AppColors.goldSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An earned medal lit like real metal: a soft halo in the badge's own
/// colour cast from its silhouette and breathing slowly, the art lifted a
/// touch brighter, and a streak of light gleaming across it every few
/// seconds (each badge on its own beat). Static halo only when the OS asks
/// for reduced motion.
class _GlowingArt extends StatefulWidget {
  const _GlowingArt({
    required this.badge,
    required this.size,
    required this.art,
  });

  final BadgeItem badge;
  final double size;
  final Widget art;

  @override
  State<_GlowingArt> createState() => _GlowingArtState();
}

class _GlowingArtState extends State<_GlowingArt>
    with SingleTickerProviderStateMixin {
  // One 5s cycle: the halo breathes through it, the gleam crosses in its
  // first ~0.9s.
  late final _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
    value: (widget.badge.id.hashCode % 97) / 97,
  );

  static const _brighten = ColorFilter.matrix([
    1.08, 0, 0, 0, 8, //
    0, 1.08, 0, 0, 8, //
    0, 0, 1.08, 0, 8, //
    0, 0, 0, 1, 0,
  ]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (hubMotionOn(context)) {
      if (!_cycle.isAnimating) _cycle.repeat();
    } else {
      _cycle.stop();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final glow = Color.lerp(widget.badge.color, AppColors.goldSoft, 0.45)!;
    final halo = ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: size * 0.11, sigmaY: size * 0.11),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(glow, BlendMode.srcIn),
        child: widget.art,
      ),
    );
    final lit = ColorFiltered(colorFilter: _brighten, child: widget.art);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _cycle,
        builder: (context, _) {
          final t = _cycle.value;
          final breath = 0.5 + 0.5 * math.sin(t * math.pi * 2);
          final gleam = t < 0.18 ? t / 0.18 : null;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1.12,
                child: Opacity(opacity: 0.55 + 0.3 * breath, child: halo),
              ),
              if (gleam == null)
                lit
              else
                // Light only lands where the medal is painted (srcATop).
                ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment(-1.0 + 4 * gleam - 1, -1),
                    end: Alignment(1.0 + 4 * gleam - 1, 1),
                    colors: const [
                      Color(0x00FFFFFF),
                      Color(0x8CFFFBE8),
                      Color(0x00FFFFFF),
                    ],
                    stops: const [0.35, 0.5, 0.65],
                  ).createShader(rect),
                  child: lit,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Detail sheet ────────────────────────────────────────────────────────────

/// Bottom sheet explaining one badge: what it is, how to earn it, and its
/// reward. Shared by the Backpack shelves.
Future<void> showBadgeDetailSheet(
  BuildContext context,
  BadgeItem badge, {
  required bool earned,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => _BadgeDetailSheet(badge: badge, earned: earned),
  );
}

class _BadgeDetailSheet extends StatelessWidget {
  const _BadgeDetailSheet({required this.badge, required this.earned});

  final BadgeItem badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: QuestPanel(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: HubWorld.lockedRim,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (earned && hubMotionOn(context))
                          _RotatingGlow(color: badge.color),
                        BadgeMedallion(
                          badge: badge,
                          earned: earned,
                          size: 112,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    style: hubText(23, AppColors.ink, height: 1.15),
                  ),
                  const SizedBox(height: 8),
                  WoodChip(label: badge.category.title),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.creamBorder, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to earn it',
                          style: hubText(14, HubWorld.woodMid),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge.requirement,
                          style: hubText(
                            15.5,
                            AppColors.ink,
                            weight: 600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        earned ? Icons.check_circle_rounded : Icons.star_rounded,
                        color: earned ? AppColors.teal : AppColors.gold,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          earned ? 'Earned' : '+${badge.xp} XP Reward',
                          style: hubText(
                            17,
                            earned ? AppColors.teal : HubWorld.goldDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ChunkyButton(
                      onTap: () => Navigator.of(context).pop(),
                      face: AppColors.teal,
                      edge: AppColors.tealDark,
                      radius: 18,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Center(
                        child: Text('Close', style: hubText(18, Colors.white)),
                      ),
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

class _RotatingGlow extends StatefulWidget {
  const _RotatingGlow({required this.color});

  final Color color;

  @override
  State<_RotatingGlow> createState() => _RotatingGlowState();
}

class _RotatingGlowState extends State<_RotatingGlow>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              widget.color.withValues(alpha: 0),
              AppColors.gold.withValues(alpha: 0.45),
              widget.color.withValues(alpha: 0),
              AppColors.gold.withValues(alpha: 0.45),
              widget.color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
