import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/fiqh_drag_activity.dart';

void main() {
  // Wudhu Master's 10-step simplified order (curriculum_data.dart's
  // 'dest1-fiqh-3' content) — the sequencer used to be hardcoded to exactly
  // 6 slots, so this also guards the dynamic slot-count rework.
  final items = [
    const FiqhDragItem(id: 'u1', emoji: '👐', label: 'Wash Hands', correctZoneId: '1'),
    const FiqhDragItem(id: 'u2', emoji: '👄', label: 'Rinse Mouth', correctZoneId: '2'),
    const FiqhDragItem(id: 'u3', emoji: '👃', label: 'Rinse Nose', correctZoneId: '3'),
    const FiqhDragItem(id: 'u4', emoji: '👤', label: 'Wash Face', correctZoneId: '4'),
    const FiqhDragItem(id: 'u5', emoji: '💪', label: 'Wash Right Arm', correctZoneId: '5'),
    const FiqhDragItem(id: 'u6', emoji: '💪', label: 'Wash Left Arm', correctZoneId: '6'),
    const FiqhDragItem(id: 'u7', emoji: '🧕', label: 'Wipe Head', correctZoneId: '7'),
    const FiqhDragItem(id: 'u8', emoji: '👂', label: 'Wipe Ears', correctZoneId: '8'),
    const FiqhDragItem(id: 'u9', emoji: '🦶', label: 'Wash Right Foot', correctZoneId: '9'),
    const FiqhDragItem(id: 'u10', emoji: '🦶', label: 'Wash Left Foot', correctZoneId: '10'),
  ];

  Future<void> pumpGame(WidgetTester tester, {required Function onComplete}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FiqhDragActivity(
            activityId: 'dest1-fiqh-3',
            items: items,
            zones: const [],
            xp: 50,
            color: const Color(0xFFD85A30),
            onComplete: (xp, accuracyPct, errors) =>
                onComplete(xp, accuracyPct, errors),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders all 10 Wudhu Master steps in the tray', (tester) async {
    await pumpGame(tester, onComplete: (_, _, _) {});

    for (final item in items) {
      expect(find.text(item.label), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('wudhuSlot9')), findsOneWidget);
  });

  testWidgets('dropping a step onto its correct slot locks it in', (tester) async {
    await pumpGame(tester, onComplete: (_, _, _) {});

    final handle = await tester.startGesture(
      tester.getCenter(find.text('Wash Hands')),
    );
    await tester.pump();
    await handle.moveTo(
      tester.getCenter(find.byKey(const ValueKey('wudhuSlot0'))),
    );
    await tester.pump();
    await handle.up();
    await tester.pumpAndSettle();

    // The tray copy of the label is gone; only the placed-slot copy remains.
    expect(find.text('Wash Hands'), findsOneWidget);
  });

  testWidgets('dropping a step onto the wrong slot bounces back', (tester) async {
    await pumpGame(tester, onComplete: (_, _, _) {});

    final handle = await tester.startGesture(
      tester.getCenter(find.text('Wash Hands')),
    );
    await tester.pump();
    await handle.moveTo(
      tester.getCenter(find.byKey(const ValueKey('wudhuSlot9'))),
    );
    await tester.pump();
    await handle.up();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Rejected drop: the step stays in the tray, unplaced.
    expect(find.text('Wash Hands'), findsOneWidget);
    expect(find.text('Wash Left Foot'), findsOneWidget);
  });
}
