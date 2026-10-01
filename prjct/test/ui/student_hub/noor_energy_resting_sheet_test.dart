import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/student_hub/noor_energy_resting_sheet.dart';

import 'package:salamlearn/logic/learner/noor_energy_provider.dart';

/// No real Hive I/O inside `testWidgets` — same fake pattern as
/// `adventure_map_top_bar_test.dart`.
class _EmptyNoorEnergyNotifier extends NoorEnergyNotifier {
  @override
  NoorEnergyState build() => const NoorEnergyState(current: 0, maxEnergy: 5);
}

void main() {
  testWidgets('shows the resting message and an OK button that dismisses it', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noorEnergyProvider.overrideWith(_EmptyNoorEnergyNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    final context = tester.element(find.byType(Scaffold));

    showNoorEnergyRestingSheet(context);
    await tester.pumpAndSettle();

    expect(find.textContaining('Noor Energy'), findsOneWidget);
    expect(find.text('Okay, I\'ll wait'), findsOneWidget);

    await tester.tap(find.text('Okay, I\'ll wait'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Noor Energy'), findsNothing);
  });
}
