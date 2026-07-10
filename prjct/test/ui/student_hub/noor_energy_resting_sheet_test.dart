import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/student_hub/noor_energy_resting_sheet.dart';

void main() {
  testWidgets('shows the resting message and an OK button that dismisses it',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    final context = tester.element(find.byType(Scaffold));

    showNoorEnergyRestingSheet(context);
    await tester.pumpAndSettle();

    expect(find.textContaining('Noor Energy'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Noor Energy'), findsNothing);
  });
}
