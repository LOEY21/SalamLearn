import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/progress_repository.dart';
import '../auth/session.dart';

/// Real replacement for the Parent Dashboard's hardcoded 82%/24m/3-error/
/// 5-day-streak numbers (FR-5.1). Until Module 4's core learning engines
/// exist and write [ProgressRecord]s, a freshly-created learner correctly
/// shows all-zero metrics and an empty trend — that's the honest current
/// state, not a bug.
class MetricTrend {
  const MetricTrend({required this.text, required this.up});

  /// Arrow + delta, e.g. `'▲ 4%'` — empty string when there isn't enough
  /// history yet to compare against (no fabricated trend is shown).
  final String text;

  /// Whether the change is *good* (not just "went up") — an error-count
  /// increase is a bad trend even though the number went up.
  final bool up;

  static const none = MetricTrend(text: '', up: true);
}

class ParentKpis {
  const ParentKpis({
    required this.accuracyPct,
    required this.accuracyTrend,
    required this.timeOnTaskMinutes,
    required this.timeOnTaskTrend,
    required this.errorCount,
    required this.errorTrend,
    required this.streak,
  });

  final double accuracyPct;
  final MetricTrend accuracyTrend;
  final int timeOnTaskMinutes;
  final MetricTrend timeOnTaskTrend;
  final int errorCount;
  final MetricTrend errorTrend;
  final int streak;

  static const empty = ParentKpis(
    accuracyPct: 0,
    accuracyTrend: MetricTrend.none,
    timeOnTaskMinutes: 0,
    timeOnTaskTrend: MetricTrend.none,
    errorCount: 0,
    errorTrend: MetricTrend.none,
    streak: 0,
  );
}

MetricTrend _trend(
  num current,
  num previous, {
  required String Function(num delta) format,
  bool higherIsBetter = true,
}) {
  if (current == 0 && previous == 0) return MetricTrend.none;
  final delta = current - previous;
  if (delta == 0) return MetricTrend.none;
  final wentUp = delta > 0;
  final isGood = higherIsBetter ? wentUp : !wentUp;
  return MetricTrend(text: '${wentUp ? '▲' : '▼'} ${format(delta.abs())}', up: isGood);
}

final parentKpiProvider = Provider<ParentKpis>((ref) {
  final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
  if (learnerId == null) return ParentKpis.empty;

  final repo = ProgressRepository();
  final now = DateTime.now();
  final thisWeek = repo.summaryForRange(learnerId, now.subtract(const Duration(days: 7)), now);
  final lastWeek = repo.summaryForRange(
    learnerId,
    now.subtract(const Duration(days: 14)),
    now.subtract(const Duration(days: 7)),
  );

  return ParentKpis(
    accuracyPct: thisWeek.accuracyPct,
    accuracyTrend: _trend(
      thisWeek.accuracyPct,
      lastWeek.accuracyPct,
      format: (d) => '${d.round()}%',
    ),
    timeOnTaskMinutes: thisWeek.timeOnTaskMinutes,
    timeOnTaskTrend: _trend(
      thisWeek.timeOnTaskMinutes,
      lastWeek.timeOnTaskMinutes,
      format: (d) => '${d.round()}m',
    ),
    errorCount: thisWeek.errorCount,
    errorTrend: _trend(
      thisWeek.errorCount,
      lastWeek.errorCount,
      format: (d) => '${d.round()}',
      higherIsBetter: false,
    ),
    streak: repo.currentStreak(learnerId),
  );
});

/// FR-5.1 weekly activity chart data (one normalized value per weekday).
final parentWeeklyChartProvider = Provider<Map<String, double>>((ref) {
  final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
  if (learnerId == null) return const {};
  return ProgressRepository().weeklyChartData(learnerId);
});

/// FR-5.2 curriculum-aligned practice suggestions.
final parentSuggestionsProvider = Provider<List<String>>((ref) {
  final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
  if (learnerId == null) return const [];
  return ProgressRepository().latestSuggestions(learnerId);
});
