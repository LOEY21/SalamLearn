import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/widgets/child_profile_form.dart';
import 'package:salamlearn/ui/widgets/learner_avatar.dart';

void main() {
  test('every mascot id maps to bundled art, legacy emoji to none', () {
    expect(mascotAsset('boy_mascot'), 'assets/images/mascot_boy_1.png');
    expect(
      mascotAsset('girl_mascot_3', face: true),
      'assets/images/mascot_girl_3_face.jpg',
    );
    expect(mascotAsset('🧒'), isNull);
  });

  testWidgets('picking a mascot shows its looks', (tester) async {
    var avatar = 'boy_mascot';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => CompanionPicker(
                avatar: avatar,
                onChanged: (v) => setState(() => avatar = v),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Look 4'), findsOneWidget);

    await tester.tap(find.text('Amira'));
    await tester.pump();
    expect(avatar, 'girl_mascot');

    await tester.tap(find.bySemanticsLabel('Look 2'));
    await tester.pump();
    expect(avatar, 'girl_mascot_2');

    // Switching back starts Amir on his first look.
    await tester.tap(find.text('Amir'));
    await tester.pump();
    expect(avatar, 'boy_mascot');
  });

  testWidgets('looksOnly hides the other gender', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompanionPicker(
            avatar: 'girl_mascot_2',
            looksOnly: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Amir'), findsNothing);
    expect(find.text('Amira'), findsNothing);
    expect(find.bySemanticsLabel('Look 4'), findsOneWidget);
  });
}
