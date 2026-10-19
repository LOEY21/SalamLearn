import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/logic/learner/noor_energy_provider.dart';
import 'package:salamlearn/logic/recent_module_provider.dart';
import 'package:salamlearn/ui/student_hub/hub_info_sheet.dart';
import 'package:salamlearn/ui/student_hub/noor_energy_info_sheet.dart';

class _PartialNoorEnergyNotifier extends NoorEnergyNotifier {
  @override
  NoorEnergyState build() => const NoorEnergyState(current: 3, maxEnergy: 5);
}

class _FakeStreak extends LearnerStreakNotifier {
  @override
  int build() => 4;
}

class _FakeXp extends LearnerXpNotifier {
  @override
  int build() => 120;
}

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        noorEnergyProvider.overrideWith(_PartialNoorEnergyNotifier.new),
        learnerStreakProvider.overrideWith(_FakeStreak.new),
        learnerXpProvider.overrideWith(_FakeXp.new),
      ],
      child: const MaterialApp(home: Scaffold(body: SizedBox())),
    ),
  );
  return tester.element(find.byType(Scaffold));
}

Future<void> _dismiss(WidgetTester tester) async {
  await tester.tap(find.text('Got it!'));
  await tester.pumpAndSettle();
  expect(find.text('Got it!'), findsNothing);
}

void main() {
  testWidgets('Noor Energy sheet shows lanterns lit and refill time', (
    tester,
  ) async {
    showNoorEnergyInfoSheet(await _pumpHost(tester));
    await tester.pumpAndSettle();

    expect(find.text('Noor Energy'), findsOneWidget);
    expect(find.text('3 of 5 lanterns lit'), findsOneWidget);
    expect(find.textContaining('Next lantern in'), findsOneWidget);
    await _dismiss(tester);
  });

  testWidgets('streak sheet shows the current streak', (tester) async {
    showStreakInfoSheet(await _pumpHost(tester));
    await tester.pumpAndSettle();

    expect(find.text('Day Streak'), findsOneWidget);
    expect(find.text('4 day streak'), findsOneWidget);
    await _dismiss(tester);
  });

  testWidgets('stars sheet shows stars earned', (tester) async {
    showStarsInfoSheet(await _pumpHost(tester));
    await tester.pumpAndSettle();

    expect(find.text('Stars'), findsOneWidget);
    expect(find.text('120 stars earned'), findsOneWidget);
    await _dismiss(tester);
  });
}
