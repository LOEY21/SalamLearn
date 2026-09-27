import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/fiqh_drag_activity.dart';
import 'package:salamlearn/ui/core_modules/activities/label_maker_game.dart';

void main() {
  testWidgets('start screen shows and Play hands off to the drag activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabelMakerGame(
            activityId: 'dest2-s3-act',
            items: const [
              FiqhDragItem(
                id: 'home4',
                emoji: '🛋️',
                label: 'Sofa',
                correctZoneId: 'living',
              ),
            ],
            zones: const [
              FiqhDropZone(id: 'living', label: 'Living Room', icon: '🛋️'),
            ],
            xp: 30,
            color: Colors.orange,
            onComplete: (_, _, _) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Learn Arabic Words'), findsOneWidget);
    expect(find.byType(FiqhDragActivity), findsNothing);

    await tester.tap(find.byKey(const ValueKey('lm-play')));
    await tester.pump();

    expect(find.byType(FiqhDragActivity), findsOneWidget);
  });
}
