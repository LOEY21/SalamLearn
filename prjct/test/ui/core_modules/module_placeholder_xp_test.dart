import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/ui/core_modules/module_placeholder_screen.dart';

/// No real Hive I/O — a real `Box.put()` call triggered from inside a
/// widget test's gesture-driven async callback hangs this environment's
/// test runner indefinitely after the test body completes (root-caused via
/// a series of probes: reproducible regardless of which module/animation
/// renders, and disappears entirely once the real Hive write is replaced
/// with an in-memory state update). Hive persistence itself is already
/// covered by `learner_xp_provider_test.dart`; this test only needs to
/// verify that `_runDfdSimulation` actually calls `addXp` at the right
/// point, which this fake proves without touching Hive.
class _FakeLearnerXpNotifier extends LearnerXpNotifier {
  @override
  int build() => 0;

  @override
  void addXp(int amount) {
    state = state + amount;
  }
}

void main() {
  testWidgets('completing the DFD simulation flow awards 50 XP', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [learnerXpProvider.overrideWith(_FakeLearnerXpNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ModulePlaceholderScreen(moduleId: 'flashcards'),
        ),
      ),
    );
    await tester.pump();

    expect(container.read(learnerXpProvider), 0);

    // Tap "Finish Lesson!" to kick off _runDfdSimulation.
    await tester.tap(find.text('Finish Lesson! 🌟'));
    await tester.pump();

    // Drive every Future.delayed step in the DFD simulation forward:
    // validating (1200ms) -> savingLocal (1000ms) -> updatingStreak (1000ms)
    // -> awardingBadges (1000ms, where addXp fires) -> checkingInternet
    // (800ms) -> syncingCloud (1200ms) -> finished.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));

    // XP is awarded as soon as the "awardingBadges" step runs, before the
    // remaining internet-check/sync steps finish.
    expect(container.read(learnerXpProvider), 50);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();

    // Still 50 — addXp(50) fires exactly once per completed simulation.
    expect(container.read(learnerXpProvider), 50);
  });
}
