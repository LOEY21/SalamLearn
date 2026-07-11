import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/logic/learner/noor_energy_provider.dart';
import 'package:salamlearn/ui/student_hub/adventure_map_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart'
    show ProgressionOverrideNotifier, progressionOverrideProvider;

/// No real Hive I/O — `AdventureMapScreen` renders `AdventureMapTopBar`,
/// which reads these two Hive-backed providers in `build()`. Without an
/// opened Hive box (as in this widget test), a real `Box.put()`/`get()`
/// call throws `HiveError: Box not found`. Same fake-override pattern as
/// `adventure_map_top_bar_test.dart` — these fakes only need to supply a
/// `build()` value, never touching Hive.
class _FakeLearnerXpNotifier extends LearnerXpNotifier {
  @override
  int build() => 0;
}

class _FakeNoorEnergyNotifier extends NoorEnergyNotifier {
  @override
  NoorEnergyState build() => const NoorEnergyState(current: 5, maxEnergy: 5);
}

/// `AdventureMapScreen._isModuleAssigned` short-circuits to `true` when this
/// debug override is on, before it ever reads `sessionProvider`/
/// `classHomeworkProvider`/`teacherRosterProvider` — all three of which are
/// transitively Hive-backed (`sessionProvider` reads a real `settings` box)
/// and would otherwise throw the same `HiveError` as above. Faking just this
/// one override avoids needing three separate Hive-avoidance fakes.
class _FakeProgressionOverrideNotifier extends ProgressionOverrideNotifier {
  @override
  bool build() => true;
}

void main() {
  testWidgets('shows one node per core module', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AdventureMapScreen()),
        GoRoute(path: '/module/:id', builder: (_, state) => Text('module ${state.pathParameters['id']}')),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnerXpProvider.overrideWith(_FakeLearnerXpNotifier.new),
          noorEnergyProvider.overrideWith(_FakeNoorEnergyNotifier.new),
          progressionOverrideProvider.overrideWith(
            _FakeProgressionOverrideNotifier.new,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('Tracing'), findsOneWidget);
    expect(find.text('Sounds'), findsOneWidget);
    expect(find.text('Stories'), findsOneWidget);
  });
}
