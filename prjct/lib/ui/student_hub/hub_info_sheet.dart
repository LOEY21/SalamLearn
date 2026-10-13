import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/learner/learner_xp_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/streak_tracker.dart';
import 'hub_world.dart';

/// One "how it works" line on a [HubInfoSheet].
class InfoRule {
  const InfoRule({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

/// Read-only explainer opened from a top-bar pill (Noor Energy, streak,
/// stars): the stat's own art, title and status chips, then the rules on
/// parchment — the Hub's wood-frame + gold-trim build from `hub_world.dart`.
class HubInfoSheet extends StatelessWidget {
  const HubInfoSheet({
    super.key,
    required this.title,
    required this.hero,
    required this.chips,
    required this.rules,
  });

  final String title;
  final Widget hero;
  final List<Widget> chips;
  final List<InfoRule> rules;

  static Future<void> show(BuildContext context, Widget sheet) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: HubWorld.wood,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x334A3A1E),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: Container(
              color: HubWorld.parchment,
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(27),
                border: Border.all(color: AppColors.goldSoft, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                    child: Column(
                      children: [
                        hero,
                        const SizedBox(height: 10),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: hubText(28, HubWorld.wood, height: 1.1),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: chips,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1.5, color: AppColors.goldSoft),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < rules.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          _RuleRow(rule: rules[i]),
                        ],
                        const SizedBox(height: 22),
                        ChunkyButton(
                          onTap: () => Navigator.of(context).pop(),
                          face: AppColors.teal,
                          edge: AppColors.tealDark,
                          radius: 18,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          semanticLabel: 'Got it!'.tr,
                          child: Center(
                            child: Text(
                              'Got it!',
                              style: hubText(19, Colors.white, height: 1.1),
                            ),
                          ),
                        ),
                      ],
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

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule});

  final InfoRule rule;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: rule.color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(rule.icon, size: 24, color: rule.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rule.title, style: hubText(17, AppColors.ink, height: 1.15)),
              const SizedBox(height: 2),
              Text(
                rule.body,
                style: hubText(
                  14,
                  HubWorld.inkSoft,
                  weight: 600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Big art for a sheet's scene band, with a warm glow under it.
class GlowArt extends StatelessWidget {
  const GlowArt({super.key, required this.child, this.glow = true});

  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    if (!glow) return child;
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Color(0x99F7C86F), blurRadius: 24, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

void showStreakInfoSheet(BuildContext context) =>
    HubInfoSheet.show(context, const _StreakInfoSheet());

class _StreakInfoSheet extends ConsumerWidget {
  const _StreakInfoSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(learnerStreakProvider);
    return HubInfoSheet(
      title: 'Day Streak',
      hero: GlowArt(
        glow: streak > 0,
        child: StreakFlame(lit: streak > 0, size: 76),
      ),
      chips: [
        WoodChip(
          label: streak > 0 ? '$streak day streak' : 'No streak yet',
        ),
      ],
      rules: const [
        InfoRule(
          icon: Icons.local_fire_department_rounded,
          color: AppColors.coral,
          title: 'Learn every day',
          body: 'Finish a lesson each day and your streak grows by 1.',
        ),
        InfoRule(
          icon: Icons.event_busy_rounded,
          color: AppColors.teal,
          title: 'Don\'t skip a day',
          body: 'If you miss a whole day, your streak starts again.',
        ),
        InfoRule(
          icon: Icons.emoji_events_rounded,
          color: HubWorld.goldDeep,
          title: 'Earn streak badges',
          body: 'Reach 3, 7 and 30 days in a row to win special badges!',
        ),
      ],
    );
  }
}

void showStarsInfoSheet(BuildContext context) =>
    HubInfoSheet.show(context, const _StarsInfoSheet());

class _StarsInfoSheet extends ConsumerWidget {
  const _StarsInfoSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xp = ref.watch(learnerXpProvider);
    return HubInfoSheet(
      title: 'Stars',
      hero: GlowArt(
        child: Image.asset(
          'assets/images/xp_star.webp',
          width: 76,
          height: 76,
          excludeFromSemantics: true,
        ),
      ),
      chips: [WoodChip(label: '$xp stars earned')],
      rules: const [
        InfoRule(
          icon: Icons.star_rounded,
          color: HubWorld.goldDeep,
          title: 'Finish a lesson, get stars',
          body: 'Every lesson gives you stars when you finish it.',
        ),
        InfoRule(
          icon: Icons.replay_rounded,
          color: AppColors.teal,
          title: 'First finish counts',
          body: 'You get a lesson\'s stars the first time. Replaying is just '
              'for fun!',
        ),
        InfoRule(
          icon: Icons.map_rounded,
          color: AppColors.adventurePurple,
          title: 'Collect them all',
          body: 'Lessons give different amounts of stars. Try them all!',
        ),
      ],
    );
  }
}
