import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/parent_account.dart';
import 'package:salamlearn/data/models/teacher_account.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/ui/settings/personal_info_screen.dart';

import '../../test_helpers/hive_test_setup.dart';
import '../../test_helpers/responsive_harness.dart';

class _FakeSession extends SessionNotifier {
  _FakeSession(this._role);
  final UserRole _role;

  @override
  SessionState build() => SessionState(
    activeRole: _role,
    activeParentId: 'parent-1',
    activeTeacherId: 'teacher-1',
    pinVerified: true,
  );
}

void main() {
  late Directory tempDir;

  setUpAll(loadRealFonts);

  setUp(() async {
    tempDir = await setUpTestHive();
    await Hive.box<ParentAccount>(HiveBoxes.parents).put(
      'parent-1',
      ParentAccount(
        id: 'parent-1',
        fullName: 'Aisha Santos',
        email: 'aisha@example.com',
        mobileNumber: '+639171234567',
        pinHash: 'x',
        pinSalt: 'y',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await Hive.box<TeacherAccount>(HiveBoxes.teachers).put(
      'teacher-1',
      TeacherAccount(
        id: 'teacher-1',
        fullName: 'Ustadh Yusuf Abdurrahman Al-Farouqi',
        school: 'Madrasah Al-Hikmah Integrated Learning Center',
        email: 'yusuf@example.com',
        pinHash: 'x',
        pinSalt: 'y',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  });

  tearDown(() => tearDownTestHive(tempDir));

  Future<void> pumpRow(
    WidgetTester tester,
    UserRole role, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [sessionProvider.overrideWith(() => _FakeSession(role))],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: PersonalInfoRow(),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Personal information'));
    await settle(tester);
  }

  /// Save does real Hive I/O, which can't finish inside the fake clock.
  Future<void> save(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Save changes'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await settle(tester);
  }

  testWidgets('parent edits name and mobile; email stays read-only', (
    tester,
  ) async {
    await pumpRow(tester, UserRole.parent);
    expect(find.text('Aisha Santos'), findsOneWidget);
    await open(tester);

    // Prefilled, mobile shown without its +63 (that's the fixed prefix).
    expect(find.widgetWithText(TextField, 'Aisha Santos'), findsOneWidget);
    expect(find.widgetWithText(TextField, '9171234567'), findsOneWidget);
    expect(find.text('School (optional)'), findsNothing);
    final email = tester.widget<TextField>(
      find.widgetWithText(TextField, 'aisha@example.com'),
    );
    expect(email.readOnly, isTrue);

    // Empty name and a short number are caught before anything is saved.
    await tester.enterText(find.widgetWithText(TextField, 'Aisha Santos'), '');
    await tester.enterText(find.widgetWithText(TextField, '9171234567'), '123');
    await save(tester);
    expect(find.text('Please enter your full name'), findsOneWidget);
    expect(
      find.textContaining('Enter a 10-digit mobile number'),
      findsOneWidget,
    );
    expect(
      Hive.box<ParentAccount>(HiveBoxes.parents).get('parent-1')!.fullName,
      'Aisha Santos',
    );

    await tester.enterText(
      find.byType(TextField).at(0),
      '  Aisha   M. Santos ',
    );
    await tester.enterText(find.byType(TextField).at(1), '09181112222');
    await save(tester);

    final saved = Hive.box<ParentAccount>(HiveBoxes.parents).get('parent-1')!;
    expect(saved.fullName, 'Aisha M. Santos');
    expect(saved.mobileNumber, '+639181112222');
    expect(saved.email, 'aisha@example.com');
    expect(saved.pinHash, 'x');
    // Back on Settings, which already shows the new name.
    expect(find.text('Save changes'), findsNothing);
    expect(find.text('Aisha M. Santos'), findsOneWidget);
    expect(find.text('Personal information saved'), findsOneWidget);
  });

  testWidgets('teacher can also edit their school and clear the mobile', (
    tester,
  ) async {
    await pumpRow(tester, UserRole.asatidz);
    await open(tester);
    expect(find.text('School (optional)'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Madrasah Al-Hikmah Integrated Learning Center',
      ),
      'Madrasah An-Nur',
    );
    await save(tester);

    final saved = Hive.box<TeacherAccount>(
      HiveBoxes.teachers,
    ).get('teacher-1')!;
    expect(saved.school, 'Madrasah An-Nur');
    expect(saved.mobileNumber, isNull);
    expect(saved.fullName, 'Ustadh Yusuf Abdurrahman Al-Farouqi');
  });

  for (final scale in responsiveTextScales) {
    testWidgets('fits at every size, with errors showing, text x$scale', (
      tester,
    ) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        for (final role in [UserRole.parent, UserRole.asatidz]) {
          await pumpRow(tester, role, size: size, scale: scale);
          expect(tester.takeException(), isNull, reason: label);
          expect(brokenWords(tester), isEmpty, reason: 'Row $label');
          await open(tester);
          await scrollThroughChecking(tester, '$role $label');

          await scrollUntilFound(
            tester,
            find.byType(TextField).first,
            towardsTop: true,
          );
          await tester.enterText(find.byType(TextField).first, '');
          await save(tester);
          await scrollUntilFound(
            tester,
            find.text('Please enter your full name'),
            towardsTop: true,
          );
          await scrollThroughChecking(tester, 'Errors $role $label');
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
