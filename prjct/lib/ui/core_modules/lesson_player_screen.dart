import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/repositories/progress_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/learner/learner_xp_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';
import 'activities/fiqh_drag_activity.dart';
import 'activities/greeting_match_activity.dart';
import 'activities/quiz_activity.dart';
import 'activities/quran_sync_activity.dart';
import 'activities/story_activity.dart';
import 'activities/trace_activity.dart';
import 'activities/ayah_builder_game.dart';
import 'activities/classroom_heroes_game.dart';
import 'activities/creation_hunt_game.dart';
import 'activities/harakat_pop_activity.dart';
import 'activities/quran_etiquette_game.dart';
import 'activities/sirah_story_game.dart';
import 'lesson_complete_screen.dart';

/// Parses the model's `#RRGGBB` hex strings into a [Color] — same
/// convention as `destination_levels_sheet.dart`'s `_hexColor`.
Color _hexColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

/// Ported from Wireframe 0.3's `LessonPlayer.tsx` — full-screen lesson
/// runner: top bar (close, progress bar, XP badge), activity title row,
/// and the current activity's widget filling the rest of the screen.
///
/// Auto-advances the instant an activity's `onComplete` fires — there is
/// no "start next activity" confirmation step anywhere, matching the
/// source's `handleActivityComplete` exactly. On the final activity's
/// completion, this screen has no parent to bubble
/// `onComplete(lessonId, xp)` up to (unlike the source), so it directly
/// awards XP/streak/badge via the same providers
/// `module_placeholder_screen.dart`'s DFD simulation calls, then shows
/// [LessonCompleteScreen] — silently, with no narrated multi-step flow.
class LessonPlayerScreen extends ConsumerStatefulWidget {
  const LessonPlayerScreen({
    super.key,
    required this.lesson,
    required this.destinationId,
    required this.onClose,
  });

  final Lesson lesson;

  /// The adventure/destination this lesson belongs to (FR-5.1's per-module
  /// telemetry grouping) — stored as [ProgressRecord.moduleId] so the
  /// Parent Dashboard can break progress down per adventure.
  final int destinationId;
  final VoidCallback onClose;

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen>
    with WidgetsBindingObserver {
  int _activityIndex = 0;
  int _xpEarned = 0;
  bool _finished = false;

  final Stopwatch _stopwatch = Stopwatch()..start();
  double _accuracySum = 0.0;
  int _accuracyCount = 0;
  int _errorsTotal = 0;

  Activity get _activity => widget.lesson.activities[_activityIndex];

  // Whether this lesson already has a ProgressRecord from a prior playthrough
  // — replays still play normally but don't re-award XP/streak/badge or
  // write another record, so parent/teacher analytics only reflect the
  // learner's first attempt at each lesson.
  late final bool _alreadyCompleted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final learnerId = ref.read(sessionProvider).learner?.id;
    _alreadyCompleted =
        learnerId != null &&
        ProgressRepository()
            .completedLessonIds(learnerId)
            .contains(widget.lesson.id);
  }

  // Pause the stopwatch while backgrounded so time-on-task reflects actual
  // engagement, not idle time with the app off-screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_stopwatch.isRunning) _stopwatch.start();
    } else {
      if (_stopwatch.isRunning) _stopwatch.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopwatch.stop();
    super.dispose();
  }

  void _handleActivityComplete(int xp, double accuracyPct, int errors) {
    final next = _xpEarned + xp;
    _accuracySum += accuracyPct;
    _accuracyCount += 1;
    _errorsTotal += errors;

    if (_activityIndex + 1 >= widget.lesson.activities.length) {
      if (_alreadyCompleted) {
        // Replay of an already-finished lesson — let the learner play
        // through, but don't re-award XP/streak/badge or write another
        // ProgressRecord (only the first try counts toward analytics).
        setState(() {
          _xpEarned = 0;
          _finished = true;
        });
        if (_skipCompleteScreen) widget.onClose();
        return;
      }
      ref.read(learnerXpProvider.notifier).addXp(next);
      ref.read(learnerStreakProvider.notifier).increment();
      ref
          .read(unlockedBadgesProvider.notifier)
          .unlockBadge('${widget.lesson.title} Master');
      _writeProgressRecord();
      setState(() {
        _xpEarned = next;
        _finished = true;
      });
      if (_skipCompleteScreen) widget.onClose();
    } else {
      setState(() {
        _xpEarned = next;
        _activityIndex += 1;
      });
    }
  }

  /// Mid-lesson quit — nothing is saved until the last activity completes
  /// (see [_writeProgressRecord]), so warn the learner before closing:
  /// confirming discards all progress in this attempt and the lesson
  /// restarts from the first activity next time it's opened.
  Future<void> _confirmExit() async {
    if (_finished) {
      widget.onClose();
      return;
    }
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit lesson?'),
        content: const Text(
          'Your progress will not be saved. You\'ll restart this lesson '
          'from the beginning next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (quit == true) widget.onClose();
  }

  /// FR-5.1's `ProgressBox` write — the real telemetry the Parent Dashboard's
  /// per-adventure breakdown and mediation prompts read back. `moduleId` is
  /// the destination id so records group by adventure, matching how
  /// `adventure_map_screen.dart` opens this screen.
  void _writeProgressRecord() {
    final learnerId = ref.read(sessionProvider).learner?.id;
    if (learnerId == null) return;
    final avgAccuracy = _accuracyCount == 0
        ? 0.0
        : _accuracySum / _accuracyCount;
    ProgressRepository().writeProgress(
      learnerId: learnerId,
      moduleId: '${widget.destinationId}',
      strokeAccuracyPct: avgAccuracy,
      sequencingErrors: _errorsTotal,
      timeOnTaskSeconds: _stopwatch.elapsed.inSeconds,
      lessonId: widget.lesson.id,
    );
  }

  // The hunt's, Classroom Heroes' and Ayah Builder's own reward screens
  // already carry the continue button.
  bool get _skipCompleteScreen =>
      _activity.type == ActivityType.ayahBuilder ||
      _activity.type == ActivityType.creationHunt ||
      _activity.type == ActivityType.classroomHeroes ||
      _activity.type == ActivityType.sirahStory ||
      _activity.type == ActivityType.quranEtiquette;

  bool get _isFullBleedActivity =>
      _activity.type == ActivityType.creationHunt ||
      _activity.type == ActivityType.classroomHeroes ||
      _activity.type == ActivityType.sirahStory ||
      _activity.type == ActivityType.quranEtiquette ||
      _isWudhuActivity;

  bool get _isWudhuActivity =>
      _activity.type == ActivityType.fiqhDrag &&
      FiqhDragActivity.modeFor(_activity.id) == FiqhMode.wudhu;

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return LessonCompleteScreen(
        lesson: widget.lesson,
        xpEarned: _xpEarned,
        onContinue: widget.onClose,
      );
    }

    final lessonColor = _hexColor(widget.lesson.color);
    final totalXp = widget.lesson.activities.fold<int>(
      0,
      (sum, activity) => sum + activity.xp,
    );
    final progress = widget.lesson.activities.isEmpty
        ? 0.0
        : _activityIndex / widget.lesson.activities.length;

    return PopScope(
      // Prevent the default back-navigation — we handle it ourselves
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7E9),
        // Trace's, Ayah Builder's, and Greeting Match's own scenery
        // backgrounds are meant to run fully edge-to-edge — under the status
        // bar too — so unlike every other activity type they skip the
        // opaque top bar and title row entirely instead of just relocating
        // them. Trace's and Ayah Builder's exits are handled by the back
        // arrow baked into their own layout (see `onBack`); Greeting
        // Match's background has no such baked-in control, so it gets a
        // small floating close button instead.
        body: switch (_activity.type) {
          ActivityType.trace ||
          ActivityType.ayahBuilder => _buildActivityContent(lessonColor),
          // Wudhu Master and Allah's Creation Hunt bring their own
          // background, HUD and exit chip, so they run edge-to-edge like
          // Trace does.
          ActivityType.creationHunt ||
          ActivityType.classroomHeroes ||
          ActivityType.sirahStory ||
          ActivityType.quranEtiquette ||
          ActivityType.fiqhDrag when _isFullBleedActivity =>
            _buildActivityContent(lessonColor),
          ActivityType.pronounce => Stack(
            children: [
              Positioned.fill(child: _buildActivityContent(lessonColor)),
              Positioned(
                left: 16,
                top: MediaQuery.of(context).padding.top + 12,
                child: _buildFloatingClose(),
              ),
            ],
          ),
          _ => Column(
            children: [
              _buildTopBar(lessonColor, progress, totalXp),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _buildActivityTitleRow(),
                      Expanded(child: _buildActivityContent(lessonColor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        },
      ),
    );
  }

  Widget _buildFloatingClose() {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          _confirmExit();
        },
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/greeting_match/greeting_match_back_button.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color lessonColor, double progress, int totalXp) {
    final topPadding = MediaQuery.of(context).padding.top;
    final total = widget.lesson.activities.length;
    final finished = _activityIndex; // number of activities finished
    final percentage = total == 0 ? 0 : ((finished / total) * 100).round();

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14 + topPadding, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0EDE8), width: 2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _confirmExit,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDE8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '✕',
                style: TextStyle(fontSize: 18, color: Color(0xFF666666)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 10,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(color: const Color(0xFFF0EDE8)),
                        ),
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [lessonColor, AppColors.gold],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Game ${_activityIndex + 1} of $total',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '$percentage% finished',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: lessonColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECC8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$totalXp XP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTitleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(_activity.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            _activity.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const Spacer(),
          Text(
            '${_activityIndex + 1}/${widget.lesson.activities.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCCCCCC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityContent(Color lessonColor) {
    final activity = _activity;
    // `key: ValueKey(activity.id)` matters here, not just style: two
    // consecutive activities of the same type (e.g. two trace activities
    // back to back) are the same widget type at the same tree position, so
    // without a distinct key Flutter reuses the previous activity's State
    // — its card-index/done-set/etc — instead of starting the new activity
    // fresh.
    return switch (activity.type) {
      ActivityType.trace => TraceActivity(
        key: ValueKey(activity.id),
        cards: activity.cards!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
        onBack: _confirmExit,
      ),
      ActivityType.pronounce => GreetingMatchActivity(
        key: ValueKey(activity.id),
        questions: activity.greetingQuestions!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
      ),
      ActivityType.quranSync => QuranSyncActivity(
        key: ValueKey(activity.id),
        line: activity.quranLine!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
      ),
      ActivityType.ayahBuilder => AyahBuilderGame(
        key: ValueKey(activity.id),
        sessions: ayahBuilderSessions,
        initialIndex: ayahBuilderSessions.indexOf(activity.ayahSession!),
        xp: activity.xp,
        onComplete: _handleActivityComplete,
        onExit: _confirmExit,
      ),
      ActivityType.story => StoryActivity(
        key: ValueKey(activity.id),
        activityId: activity.id,
        panels: activity.panels!,
        xp: activity.xp,
        onComplete: _handleActivityComplete,
      ),
      ActivityType.fiqhDrag => FiqhDragActivity(
        key: ValueKey(activity.id),
        activityId: activity.id,
        items: activity.fiqhItems!,
        zones: activity.fiqhZones!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
        onBack: _confirmExit,
      ),
      ActivityType.quiz => QuizActivity(
        key: ValueKey(activity.id),
        questions: activity.questions!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
      ),
      ActivityType.creationHunt => CreationHuntGame(
        key: ValueKey(activity.id),
        stage: activity.huntStage!,
        xp: activity.xp,
        onComplete: _handleActivityComplete,
        onExit: _confirmExit,
      ),
      ActivityType.classroomHeroes => ClassroomHeroesGame(
        key: ValueKey(activity.id),
        session: activity.heroesSession!,
        xp: activity.xp,
        onComplete: _handleActivityComplete,
        onExit: _confirmExit,
      ),
      ActivityType.sirahStory => SirahStoryGame(
        key: ValueKey(activity.id),
        session: activity.sirahSession!,
        xp: activity.xp,
        onComplete: _handleActivityComplete,
        onExit: _confirmExit,
      ),
      ActivityType.quranEtiquette => QuranEtiquetteGame(
        key: ValueKey(activity.id),
        session: activity.etiquetteSession!,
        xp: activity.xp,
        onComplete: _handleActivityComplete,
        onExit: _confirmExit,
      ),
      ActivityType.harakatPop => HarakatPopActivity(
        key: ValueKey(activity.id),
        cards: activity.cards!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
      ),
    };
  }
}
