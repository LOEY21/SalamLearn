import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/logic/learner/noor_energy_provider.dart';
import 'package:salamlearn/ui/student_hub/adventure_map_top_bar.dart';

/// No real Hive I/O — a real `Box.put()`/`get()` call triggered from
/// inside a widget test hangs this environment's test runner (same
/// hazard documented in `module_placeholder_xp_test.dart`, reproducible
/// even without a gesture, just from `build()` running during the first
/// `pumpWidget`). Hive persistence for these two providers is already
/// covered by their own dedicated provider tests; this test only needs
/// to verify the TopBar renders whatever `ref.watch` returns, which these
/// fakes prove without touching Hive.
class _FakeLearnerXpNotifier extends LearnerXpNotifier {
  @override
  int build() => 0;
}

class _FakeNoorEnergyNotifier extends NoorEnergyNotifier {
  @override
  NoorEnergyState build() => const NoorEnergyState(current: 5, maxEnergy: 5);
}

void main() {
  testWidgets('shows streak, XP, and Noor Energy values', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnerXpProvider.overrideWith(_FakeLearnerXpNotifier.new),
          noorEnergyProvider.overrideWith(_FakeNoorEnergyNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AdventureMapTopBar()),
        ),
      ),
    );

    expect(find.text('5'), findsOneWidget); // default streak from learnerStreakProvider
    expect(find.text('0'), findsOneWidget); // default XP (nothing earned yet)
    expect(find.textContaining('5'), findsWidgets); // Noor Energy 5/5 somewhere
  });
}
