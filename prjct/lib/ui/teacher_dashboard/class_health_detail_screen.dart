import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/child_profile_form.dart' show displayText, scaledExtent;
import '../widgets/hub_kit.dart';
import '../widgets/soft_card.dart';
import 'teacher_dashboard_screen.dart'
    show MasteryPill, masteryBarColor, masteryBg, masteryFg;

/// Full-screen drill-in for the Classroom tab's Class Health Index card
/// (FR-6.2) — reached via that card's "See details" row. Shows every
/// module's full stat breakdown plus the health-index methodology, which
/// the compact card has no room for. Built on the hub kit's sub-page
/// frame; two columns (games | methodology) from tablet-landscape widths.
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

    return HubSubpage(
      header: HubSubpageHeader(
        title: 'Class Health Index',
        subtitle:
            'Classroom Mode only — games played on the Hot Seat '
            'during live Cast sessions.',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: HubTabBody(
        left: [
          _OverallSummaryCard(overall: overall, moduleCount: active.length),
          const HubSectionLabel('Games'),
          for (final module in modules)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModuleDetailCard(
                module: module,
                tier: _tierFor(module.healthIndex),
              ),
            ),
        ],
        right: const [
          HubSectionLabel('How this is calculated'),
          _MethodologyCard(),
        ],
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

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overall class health', style: displayText(19)),
        const SizedBox(height: 4),
        Text(
          overall == null
              ? 'No classroom activity recorded yet.'
              : 'Average across $moduleCount active game'
                    '${moduleCount == 1 ? '' : 's'} this class has '
                    'practiced in Classroom Mode.',
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.inkSoft,
            height: 1.4,
          ),
        ),
        if (tier != null) ...[
          const SizedBox(height: 10),
          MasteryPill(mastery: tier, dotted: true),
        ],
      ],
    );

    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.all(20),
      child: overall == null
          ? text
          : LayoutBuilder(
              builder: (context, constraints) {
                final ring = _HealthRing(score: overall!, tier: tier!);
                // Ring above the text when there's no room beside it.
                if (scaledExtent(context, constraints.maxWidth) < 300) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [ring, const SizedBox(height: 14), text],
                  );
                }
                return Row(
                  children: [
                    ring,
                    const SizedBox(width: 18),
                    Expanded(child: text),
                  ],
                );
              },
            ),
    );
  }
}

/// Bigger, more legible ring than the module cards' — this is the one
/// number on the screen a teacher should read first.
class _HealthRing extends StatelessWidget {
  const _HealthRing({required this.score, required this.tier});

  final int score;
  final String tier;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: (score / 100).clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 10,
                  color: AppColors.creamDark,
                ),
              ),
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: val,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  color: masteryBarColor(tier),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(val * 100).round()}',
                        style: displayText(
                          28,
                          weight: 800,
                          color: AppColors.tealDark,
                          height: 1,
                        ),
                      ),
                      const Text(
                        '/ 100',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
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
    final title = '${module.icon}  ${module.moduleName}'.trim();
    if (!module.hasActivity) {
      return SoftCard(
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.ink,
              ),
            ),
            const Text(
              'No activity yet',
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
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

    final stats = [
      _StatColumn(
        label: 'Completion',
        value: '${(module.completionRate * 100).round()}%',
      ),
      _StatColumn(
        label: 'Avg accuracy',
        value: '${module.avgAccuracy.round()}%',
      ),
      _StatColumn(
        label: 'Avg errors',
        value: module.avgErrors.toStringAsFixed(1),
      ),
    ];

    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: masteryBarColor(tier),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              MasteryPill(mastery: tier),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Health index ${module.healthIndex}/100',
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: module.completionRate),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutQuart,
              builder: (context, val, child) {
                return LinearProgressIndicator(
                  value: val,
                  minHeight: 8,
                  backgroundColor: AppColors.creamDark,
                  color: masteryBarColor(tier),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              // Three across when there's room, stacked when narrow.
              if (scaledExtent(context, constraints.maxWidth) < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, s) in stats.indexed) ...[
                      if (i > 0) const SizedBox(height: 8),
                      s,
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final s in stats) Expanded(child: s)],
              );
            },
          ),
          if (trendLabel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  trend! > 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 18,
                  color: trendColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    trendLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: trendColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
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
        Text(value, style: displayText(20, weight: 800, height: 1.1)),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
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
      radius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Each game\'s health index is a weighted blend of three '
            'Classroom Mode signals — solo Student Hub practice at home '
            'never counts toward it:',
            style: TextStyle(fontSize: 14, color: AppColors.ink, height: 1.45),
          ),
          const SizedBox(height: 14),
          const _WeightSegmentBar(),
          const SizedBox(height: 14),
          const _WeightRow(
            color: AppColors.teal,
            weight: '40%',
            label: 'Completion rate',
            detail: 'share of the roster who played this game on the Hot Seat',
          ),
          const _WeightRow(
            color: AppColors.gold,
            weight: '40%',
            label: 'Average accuracy',
            detail: 'mean score across every classroom play',
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
          Text('Tiers', style: displayText(16)),
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
            'prior week and only appear once a game has at least one '
            'record in both. Solo Student Hub practice at home never '
            'counts here — see Home Mode Insights for that.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              height: 1.45,
            ),
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
      borderRadius: BorderRadius.circular(999),
      child: const SizedBox(
        height: 14,
        child: Row(
          children: [
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
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.ink,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$weight $label — ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: detail,
                    style: const TextStyle(color: AppColors.inkSoft),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: masteryBg(tier),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$tier · $range',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: masteryFg(tier),
        ),
      ),
    );
  }
}
