import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/logic/learner/noor_energy_provider.dart';
import 'package:salamlearn/ui/core_modules/module_registry.dart';
import 'package:salamlearn/ui/student_hub/adventure_map_screen.dart';
import 'package:salamlearn/ui/student_hub/destination_levels_sheet.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart'
    show ProgressionOverrideNotifier, progressionOverrideProvider;

/// `AdventureMapScreen.build()` reads `sessionProvider` directly (to pick
/// the current learner's avatar for the mascot), independent of the
/// `_isModuleAssigned` short-circuit below — needs its own Hive-free fake.
class _FakeSessionNotifier extends SessionNotifier {
  @override
  SessionState build() => const SessionState();
}

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

class _FakeProgressionOverrideOffNotifier extends ProgressionOverrideNotifier {
  @override
  bool build() => false;
}

void main() {
  testWidgets('shows one node per destination', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AdventureMapScreen()),
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
          sessionProvider.overrideWith(_FakeSessionNotifier.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Genuinely infinite-repeating animations (ambient background
    // breathing, Noor Energy lantern flicker) — pumpAndSettle never
    // returns here. Advance explicitly instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final module in coreModules) {
      expect(find.text(module.title), findsOneWidget);
    }
  });

  testWidgets(
    'tapping an unassigned destination node shows the locked dialog, not the levels sheet',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const AdventureMapScreen()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learnerXpProvider.overrideWith(_FakeLearnerXpNotifier.new),
            noorEnergyProvider.overrideWith(_FakeNoorEnergyNotifier.new),
            // Override off (no debug bypass) + a learner-less/teacher-less
            // session (both providers resolve to `null`/empty without
            // touching Hive) — every destination reads as genuinely
            // unassigned.
            progressionOverrideProvider.overrideWith(
              _FakeProgressionOverrideOffNotifier.new,
            ),
            sessionProvider.overrideWith(_FakeSessionNotifier.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      final firstModule = coreModules.first;

      // Tap via the node badge's own Key, not the title text — the label
      // pill sits below the badge as a Column sibling, outside the actual
      // InkWell hit-test region, so tapping the text itself would silently
      // hit nothing.
      //
      // This screen has genuinely infinite-repeating animations (ambient
      // background breathing, Noor Energy lantern flicker) — pumpAndSettle
      // never returns here. Advance explicitly instead, same pattern this
      // repo already uses for other continuously-animated screens.
      await tester.tap(find.byKey(ValueKey('node-badge-${firstModule.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('${firstModule.title} is Locked'), findsOneWidget);
      expect(find.byType(DestinationLevelsSheet), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('${firstModule.title} is Locked'), findsNothing);
    },
  );

  testWidgets(
    'tapping an assigned destination node opens the levels sheet, not the locked dialog',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const AdventureMapScreen()),
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
            sessionProvider.overrideWith(_FakeSessionNotifier.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      final firstModule = coreModules.first;

      await tester.tap(find.byKey(ValueKey('node-badge-${firstModule.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DestinationLevelsSheet), findsOneWidget);
      expect(find.text('${firstModule.title} is Locked'), findsNothing);
    },
  );
}
