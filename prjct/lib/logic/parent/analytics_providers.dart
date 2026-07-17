import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/repositories/progress_repository.dart';
import '../auth/session.dart';

/// Bump counter so KPI/chart/breakdown providers below recompute after
/// `SyncManager` pulls remote progress into Hive — plain `Provider`s cache
/// on `sessionProvider`'s learner id and don't otherwise notice a Hive box
/// changing underneath them (same pattern as the teacher side's
/// `rosterRefreshProvider`).
class ParentProgressRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final parentProgressRefreshProvider =
    NotifierProvider<ParentProgressRefreshNotifier, int>(
      ParentProgressRefreshNotifier.new,
    );

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
  ref.watch(parentProgressRefreshProvider);
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

/// FR-5.1 activity chart data (one normalized value per day), keyed by
/// window length in days so the "7 days"/"30 days"/"Term" range pills each
/// get their own cached result.
final parentWeeklyChartProvider = Provider.family<List<ChartPoint>, int>((ref, windowDays) {
  ref.watch(parentProgressRefreshProvider);
  final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
  if (learnerId == null) return const [];
  return ProgressRepository().weeklyChartData(learnerId, windowDays: windowDays);
});

/// Every lesson id this learner has completed — backs the adventure detail
/// dialog's per-level/per-game breakdown. Lesson-granularity is the real
/// tracked unit ([ProgressRecord.lessonId]); there is no per-game telemetry
/// below that (see `_TrendChartCardState`'s honesty note in the dashboard).
final parentCompletedLessonsProvider = Provider<Set<String>>((ref) {
  ref.watch(parentProgressRefreshProvider);
  final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
  if (learnerId == null) return const {};
  return ProgressRepository().completedLessonIds(learnerId);
});

/// One adventure's (destination's) rollup — the Telemetry Visualization
/// component's per-module breakdown (FR-5.1), read straight from the
/// `ProgressBox` records [LessonPlayerScreen] writes on lesson completion.
class AdventureProgress {
  const AdventureProgress({
    required this.destination,
    required this.accuracyPct,
    required this.errorCount,
    required this.sessionCount,
  });

  final Destination destination;
  final double accuracyPct;
  final int errorCount;
  final int sessionCount;
}

/// FR-5.1 per-adventure breakdown, weakest-accuracy-first — backs the
/// Parent Dashboard's adventure ring grid. Destinations with no recorded
/// activity this window are simply absent (nothing to show yet), not
/// zero-filled.
final parentAdventureBreakdownProvider = Provider<List<AdventureProgress>>((ref) {
  ref.watch(parentProgressRefreshProvider);
  final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
  if (learnerId == null) return const [];

  final byModule = ProgressRepository().summaryByModule(learnerId);
  final result = <AdventureProgress>[];
  for (final module in byModule) {
    final destId = int.tryParse(module.moduleId);
    if (destId == null) continue;
    Destination? destination;
    for (final d in curriculum) {
      if (d.id == destId) {
        destination = d;
        break;
      }
    }
    if (destination == null) continue;
    result.add(AdventureProgress(
      destination: destination,
      accuracyPct: module.accuracyPct,
      errorCount: module.errorCount,
      sessionCount: module.sessionCount,
    ));
  }
  result.sort((a, b) => a.accuracyPct.compareTo(b.accuracyPct));
  return result;
});

/// A single rule-based home-practice prescription (FR-5.2's Mediation
/// Prompts Engine) targeting the weakest adventure.
class MediationPrompt {
  const MediationPrompt({required this.destination, required this.routine});

  final Destination destination;
  final String routine;
}

/// Curriculum-aligned home practice routine per adventure — the rule-based
/// benchmark bank the Mediation Prompts Engine renders against, one entry
/// per destination's core skill (FR-4.1–FR-4.5).
const Map<int, String> _adventureRoutines = {
  1: 'Sit together for 5 minutes and practice the daily greetings out '
      'loud — "As-salamu alaykum" / "Wa alaykum as-salam" — taking turns '
      'starting the exchange.',
  2: 'Trace 3 Arabic letters together on paper, saying each sound aloud. '
      'Focus on stroke direction (right-to-left), not speed.',
  3: 'Pick 3 vocabulary cards from this week and use each word in a short '
      'sentence together at home.',
  4: 'Retell one Sirah story from this week in your own words, then ask '
      'your child to retell it back to you.',
  5: 'Walk through the movements of one salah step together, naming each '
      'position out loud.',
  6: "Talk about one of the Pillars of Iman together and give a real-life "
      'example of it as a family.',
  7: 'Listen to one recited ayah together and have your child repeat it '
      'phrase by phrase.',
};

/// FR-5.2 — a single actionable prescription for the weakest adventure,
/// only surfaced when there is an actual weak point (low accuracy or
/// logged errors), not a generic tip with nothing behind it.
final parentMediationPromptProvider = Provider<MediationPrompt?>((ref) {
  final breakdown = ref.watch(parentAdventureBreakdownProvider);
  if (breakdown.isEmpty) return null;
  final weakest = breakdown.first;
  if (weakest.errorCount == 0 && weakest.accuracyPct >= 80) return null;
  final routine = _adventureRoutines[weakest.destination.id];
  if (routine == null) return null;
  return MediationPrompt(destination: weakest.destination, routine: routine);
});
