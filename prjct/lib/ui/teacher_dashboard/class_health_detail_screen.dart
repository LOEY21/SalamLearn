import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/soft_card.dart';
import 'teacher_dashboard_screen.dart'
    show MasteryPill, masteryBarColor, masteryBg, masteryFg;

/// Full-screen drill-in for the Classroom tab's Class Health Index card
/// (FR-6.2) — reached via that card's "See details" button. Shows every
/// module's full stat breakdown plus the health-index methodology, which
/// the compact card has no room for.
///
/// Flat appbar + white surface, matching `ClassDetailScreen`/
/// `ClassroomManagementScreen`/`HomeModeDashboardScreen` — no gradient hero
/// banner, per this codebase's standing "flat appbar ... rather than the
/// old teal-gradient hero" design decision.
class ClassHealthDetailScreen extends ConsumerWidget {
  const ClassHealthDetailScreen({super.key, required this.classId});

  final String classId;

  static String _tierFor(int healthIndex) {
    if (healthIndex >= 80) return 'High';
    if (healthIndex >= 50) return 'Medium';
    return 'Needs help';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(classHealthIndexProvider(classId));
    final active = modules.where((m) => m.hasActivity).toList();
    final overall = active.isEmpty
        ? null
        : (active.map((m) => m.healthIndex).reduce((a, b) => a + b) /
                  active.length)
              .round();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _ClassHealthAppBar(onBack: () => Navigator.of(context).pop()),
            const Divider(height: 1, color: AppColors.creamBorder),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                children: [
                  _OverallSummaryCard(overall: overall, moduleCount: active.length),
                  const SizedBox(height: 18),
                  const _SectionHeading('MODULES'),
                  const SizedBox(height: 10),
                  for (final module in modules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ModuleDetailCard(
                        module: module,
                        tier: _tierFor(module.healthIndex),
                      ),
                    ),
                  const SizedBox(height: 6),
                  const _SectionHeading('HOW THIS IS CALCULATED'),
                  const SizedBox(height: 10),
                  const _MethodologyCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same shape as `ClassroomManagementScreen`'s `_ManagementAppBar` /
/// `HomeModeDashboardScreen`'s `_HomeModeAppBar` — neutral-tint back
/// button, uppercase eyebrow, bold title.
class _ClassHealthAppBar extends StatelessWidget {
  const _ClassHealthAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),
      child: Row(
        children: [
          Material(
            color: AppColors.neutralTint,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onBack,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CLASSROOM TAB',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  'Class Health Index',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _OverallSummaryCard extends StatelessWidget {
  const _OverallSummaryCard({required this.overall, required this.moduleCount});

  final int? overall;
  final int moduleCount;

  @override
  Widget build(BuildContext context) {
    final tier = overall == null
        ? null
        : ClassHealthDetailScreen._tierFor(overall!);

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          if (overall != null) ...[
            _HealthRing(score: overall!, tier: tier!),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall class health',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  overall == null
                      ? 'No classroom activity recorded yet.'
                      : 'Average across $moduleCount active module'
                            '${moduleCount == 1 ? '' : 's'} this class has '
                            'practiced in Classroom Mode.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
                if (tier != null) ...[
                  const SizedBox(height: 8),
                  MasteryPill(mastery: tier, dotted: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bigger, more legible version of the module cards' ring — this is the
/// one number on the screen a teacher should read first.
class _HealthRing extends StatelessWidget {
  const _HealthRing({required this.score, required this.tier});

  final int score;
  final String tier;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: (score / 100).clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 8,
                  color: AppColors.creamDark,
                ),
              ),
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: val,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  color: masteryBarColor(tier),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(val * 100).round()}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tealDark,
                      height: 1,
                    ),
                  ),
                  const Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModuleDetailCard extends StatelessWidget {
  const _ModuleDetailCard({required this.module, required this.tier});

  final ModuleHealth module;
  final String tier;

  @override
  Widget build(BuildContext context) {
    if (!module.hasActivity) {
      return SoftCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                module.moduleName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            const Text(
              'No activity yet',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final trend = module.trend;
    String? trendLabel;
    Color? trendColor;
    if (trend != null && trend != 0) {
      final sign = trend > 0 ? '+' : '';
      trendLabel = '$sign${trend.toStringAsFixed(1)} pts vs. last week';
      trendColor = trend > 0 ? AppColors.teal : AppColors.coral;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.creamBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mastery-colored rail — a scan cue that doesn't require
              // reading the pill text, matching the redesign mock.
              Container(width: 5, color: masteryBarColor(tier)),
              Expanded(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              module.moduleName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ),
                          MasteryPill(mastery: tier),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Health index ${module.healthIndex}/100',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: module.completionRate),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) {
                            return LinearProgressIndicator(
                              value: val,
                              minHeight: 7,
                              backgroundColor: AppColors.creamDark,
                              color: masteryBarColor(tier),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatColumn(
                              label: 'Completion',
                              value: '${(module.completionRate * 100).round()}%',
                            ),
                          ),
                          Expanded(
                            child: _StatColumn(
                              label: 'Avg accuracy',
                              value: '${module.avgAccuracy.round()}%',
                            ),
                          ),
                          Expanded(
                            child: _StatColumn(
                              label: 'Avg errors',
                              value: module.avgErrors.toStringAsFixed(1),
                            ),
                          ),
                        ],
                      ),
                      if (trendLabel != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              trend! > 0
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 15,
                              color: trendColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trendLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _MethodologyCard extends StatelessWidget {
  const _MethodologyCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Each module\'s health index is a weighted blend of three '
            'Classroom Mode signals — solo Student Hub practice at home '
            'never counts toward it:',
            style: TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.4),
          ),
          const SizedBox(height: 14),
          const _WeightSegmentBar(),
          const SizedBox(height: 14),
          const _WeightRow(
            color: AppColors.teal,
            weight: '40%',
            label: 'Completion rate',
            detail: 'share of the roster who practiced this module in class',
          ),
          const _WeightRow(
            color: AppColors.gold,
            weight: '40%',
            label: 'Average accuracy',
            detail: 'mean stroke accuracy across every classroom attempt',
          ),
          const _WeightRow(
            color: AppColors.coral,
            weight: '20%',
            label: 'Sequencing errors',
            detail: 'fewer average errors per session scores higher',
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.creamDark),
          const SizedBox(height: 14),
          const Text(
            'Tiers',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TierChip(tier: 'High', range: '80–100'),
              _TierChip(tier: 'Medium', range: '50–79'),
              _TierChip(tier: 'Needs help', range: '0–49'),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Trend arrows compare this week\'s average accuracy to the '
            'prior week and only appear once a module has at least one '
            'record in both. Solo Student Hub practice at home never '
            'counts here — see Home Mode Insights for that.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Visual stand-in for the 40/40/20 weighting — a proportional stacked
/// bar reads faster than three separate percentage labels.
class _WeightSegmentBar extends StatelessWidget {
  const _WeightSegmentBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 14,
        child: Row(
          children: const [
            Expanded(flex: 40, child: ColoredBox(color: AppColors.teal)),
            Expanded(flex: 40, child: ColoredBox(color: AppColors.gold)),
            Expanded(flex: 20, child: ColoredBox(color: AppColors.coral)),
          ],
        ),
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({
    required this.color,
    required this.weight,
    required this.label,
    required this.detail,
  });

  final Color color;
  final String weight;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 4, right: 8),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.35),
                children: [
                  TextSpan(
                    text: '$weight $label — ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: detail,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier, required this.range});

  final String tier;
  final String range;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: masteryBg(tier),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${tier.toUpperCase()} $range',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: masteryFg(tier),
        ),
      ),
    );
  }
}
