import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/student_hub/adventure_map_bottom_nav.dart';
import 'package:salamlearn/ui/student_hub/hub_bottom_nav.dart';

void main() {
  testWidgets('tapping Backpack calls onBackpackTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdventureMapBottomNav(
            active: HubTab.home,
            onHomeTap: () {},
            onBackpackTap: () => tapped = true,
            onProfileTap: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Backpack'));
    expect(tapped, true);
  });
}
