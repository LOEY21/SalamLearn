import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/data/models/enrollment.dart';
import 'package:salamlearn/data/models/learner_profile.dart';
import 'package:salamlearn/data/models/lesson_folder.dart';
import 'package:salamlearn/data/models/progress_record.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/cast_games.dart';
import 'package:salamlearn/ui/teacher_dashboard/class_detail_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/class_health_detail_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/classroom_management_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/home_mode_dashboard_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/lesson_folder_builder_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/module_library_screen.dart';

import '../../test_helpers/hive_test_setup.dart';
import '../../test_helpers/responsive_harness.dart';

class _FakeTeacherClassController extends TeacherClassController {
  _FakeTeacherClassController(this._section);
  final ClassSection? _section;

  @override
  ClassSection? build() => _section;
}

/// Classroom Management, Module Library, Class Health Index and Home Mode
/// Insights at every window size and text scale: no overflow, no word
/// broken mid-word, every part reachable by scrolling.
void main() {
  late Directory tempDir;
  late ClassSection section;
  late ProviderContainer container;
  // No class at all, and a class with no students, folders or activity.
  late ProviderContainer noClass;
  late ProviderContainer emptyClass;
  final bare = ClassSection(
    id: 'class-empty',
    teacherId: 'teacher-1',
    name: 'Grade 1 - Section Al-Ikhlas',
    invitationCode: 'EMP000',
    createdAt: DateTime(2026, 1, 4),
  );

  setUpAll(loadRealFonts);

  setUp(() async {
    tempDir = await setUpTestHive();
    section = ClassSection(
      id: 'class-1',
      teacherId: 'teacher-1',
      name: 'Grade 1 - Section Al-Fatihah',
      invitationCode: 'ABC123',
      createdAt: DateTime(2026, 1, 1),
    );
    await Hive.box<ClassSection>(HiveBoxes.classes).put(section.id, section);
    final students = {
      'ali': ('Muhammad Abdurrahman Al-Farouqi', 92.0),
      'hamza': ('Hamza', 64.0),
      'zara': ('Zara', 40.0),
    };
    final now = DateTime.now();
    final lesson = curriculum.first.lessons.first.id;
    for (final MapEntry(key: id, value: (name, accuracy)) in students.entries) {
      await Hive.box<LearnerProfile>(
        HiveBoxes.learners,
      ).put(id, LearnerProfile(id: id, name: name, age: 6));
      await Hive.box<Enrollment>(HiveBoxes.enrollments).put(
        '${section.id}:$id',
        Enrollment(
          classId: section.id,
          learnerId: id,
          enrolledAt: DateTime(2026, 1, 2),
        ),
      );
      for (final classroom in [false, true]) {
        final recordId = 'p-$id-$classroom';
        await Hive.box<ProgressRecord>(HiveBoxes.progress).put(
          recordId,
          ProgressRecord(
            id: recordId,
            learnerId: id,
            moduleId: '${curriculum.first.id}',
            strokeAccuracyPct: accuracy,
            sequencingErrors: 1,
            timeOnTaskSeconds: 300,
            completedAt: now,
            lessonId: lesson,
            isClassroomMode: classroom,
          ),
        );
      }
    }
    final other = ClassSection(
      id: 'class-2',
      teacherId: 'teacher-1',
      name: 'Grade 1 - Section Al-Baqarah Afternoon',
      invitationCode: 'XYZ789',
      createdAt: DateTime(2026, 1, 3),
      schedule: 'Mondays and Thursdays, 8:00 to 9:30 in the morning',
    );
    final archived = ClassSection(
      id: 'class-3',
      teacherId: 'teacher-1',
      name: 'Grade 1 - Section Al-Kawthar 2025',
      invitationCode: 'OLD111',
      createdAt: DateTime(2025, 6, 1),
      archivedAt: DateTime(2026, 4, 1),
    );
    container = ProviderContainer(
      overrides: [
        teacherClassControllerProvider.overrideWith(
          () => _FakeTeacherClassController(section),
        ),
        teacherClassesProvider.overrideWithValue([section, other]),
        archivedTeacherClassesProvider.overrideWithValue([archived]),
        classLessonFoldersProvider(section.id).overrideWithValue([
          for (final (i, name) in [
            'Week 1 Greetings and Pronunciation Review',
            'Wudhu',
          ].indexed)
            LessonFolder(
              id: 'f$i',
              teacherId: 'teacher-1',
              classId: section.id,
              name: name,
              itemRefs: const [],
              createdAt: now,
              updatedAt: now,
            ),
        ]),
      ],
    );
    noClass = ProviderContainer(
      overrides: [
        teacherClassControllerProvider.overrideWith(
          () => _FakeTeacherClassController(null),
        ),
        teacherClassesProvider.overrideWithValue(const []),
        archivedTeacherClassesProvider.overrideWithValue(const []),
      ],
    );
    emptyClass = ProviderContainer(
      overrides: [
        teacherClassControllerProvider.overrideWith(
          () => _FakeTeacherClassController(bare),
        ),
        teacherClassesProvider.overrideWithValue([bare]),
        archivedTeacherClassesProvider.overrideWithValue(const []),
        classLessonFoldersProvider(bare.id).overrideWithValue(const []),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    noClass.dispose();
    emptyClass.dispose();
    await tearDownTestHive(tempDir);
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    double scale,
    Widget screen, {
    ProviderContainer? scope,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope ?? container,
        child: MaterialApp(
          key: UniqueKey(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await settle(tester);
  }

  /// Opens a popup from [trigger], checks it, closes it with Cancel.
  Future<void> checkDialog(
    WidgetTester tester,
    Finder trigger,
    String label, {
    bool towardsTop = true,
  }) async {
    await scrollUntilFound(tester, trigger, towardsTop: towardsTop);
    await settle(tester);
    await tester.tap(trigger);
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget, reason: label);
    expect(tester.takeException(), isNull, reason: label);
    expect(brokenWords(tester), isEmpty, reason: label);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
  }

  /// Opens a game card, then switches to 7 Stages and opens a stage,
  /// checking down from each.
  Future<void> checkOpenedCards(WidgetTester tester, String label) async {
    // A card's arrow turns upside down while it is open.
    final session = find.byWidgetPredicate(
      (w) => w is AnimatedRotation && w.turns == 0.5,
    );

    await tapToOpen(
      tester,
      find.text('Greeting Match'),
      session,
      reason: 'Game $label',
      towardsTop: true,
    );
    await scrollThroughChecking(tester, 'Game opened $label');

    final stages = find.text('7 Stages');
    await scrollUntilFound(tester, stages, towardsTop: true);
    await tester.tap(stages);
    await settle(tester);
    expect(session, findsNothing, reason: 'Stage cards start closed $label');
    await tapToOpen(
      tester,
      find.text('Stage 1: Welcome to Madrasah'),
      session,
      reason: 'Stage $label',
    );
    await scrollThroughChecking(tester, 'Stage opened $label');
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final scale in responsiveTextScales) {
    testWidgets('Classroom Management and Module Library fit, text x$scale', (
      tester,
    ) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';

        await pumpAt(tester, size, scale, const ClassroomManagementScreen());
        await scrollThroughChecking(tester, 'Classes $label');

        // Multi-select mode swaps the header for the selection bar.
        final row = find.text('Grade 1 - Section Al-Baqarah Afternoon');
        await scrollUntilFound(tester, row, towardsTop: true);
        // Let any fling finish so the press isn't eaten stopping it.
        await settle(tester);
        await tester.longPress(row);
        await settle(tester);
        await scrollUntilFound(
          tester,
          find.text('1 selected'),
          towardsTop: true,
        );
        expect(find.text('1 selected'), findsOneWidget, reason: label);
        await scrollThroughChecking(tester, 'Selecting $label');
        await checkDialog(
          tester,
          find.byTooltip('Archive'),
          'Archive popup $label',
        );
        await checkDialog(
          tester,
          find.byTooltip('Delete'),
          'Delete popup $label',
        );

        await pumpAt(tester, size, scale, const ModuleLibraryScreen());
        await scrollThroughChecking(tester, 'Module Library $label');
      }
      await finish(tester);
    });

    testWidgets('Class Detail fits (active, inactive, archived), '
        'text x$scale', (tester) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        for (final (name, id) in [
          ('Active', 'class-1'),
          ('Inactive', 'class-2'),
          ('Archived', 'class-3'),
        ]) {
          await pumpAt(tester, size, scale, ClassDetailScreen(classId: id));
          expect(find.text('Class not found'), findsNothing, reason: label);
          await scrollThroughChecking(tester, '$name class $label');
        }
        await pumpAt(
          tester,
          size,
          scale,
          ClassDetailScreen(classId: 'class-1'),
        );
        for (final action in ['Archive', 'Delete']) {
          await checkDialog(
            tester,
            find.text(action),
            '$action popup $label',
            towardsTop: false,
          );
        }
      }
      await finish(tester);
    });

    testWidgets('Lesson Folder Builder fits with every game open, '
        'text x$scale', (tester) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpAt(tester, size, scale, const LessonFolderBuilderScreen());
        // Fill the timeline, then open every other game.
        final selectAll = find.text('Select all');
        await scrollUntilFound(tester, selectAll, towardsTop: false);
        await tester.tap(selectAll.first);
        await settle(tester);
        for (final game in castGames.skip(1)) {
          final header = find.byKey(
            ValueKey('game-accordion-${game.type.name}'),
          );
          await scrollUntilFound(tester, header, towardsTop: false);
          await tester.tap(header);
          await settle(tester);
        }
        await scrollUntilFound(
          tester,
          find.text('Build Lesson Folder'),
          towardsTop: true,
        );
        expect(find.text('2 selected'), findsOneWidget, reason: label);
        await scrollThroughChecking(tester, 'Builder $label');
      }
      await finish(tester);
    });

    testWidgets('Class Health Index fits, text x$scale', (tester) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpAt(
          tester,
          size,
          scale,
          ClassHealthDetailScreen(classId: section.id),
        );
        await scrollThroughChecking(tester, 'Class Health $label');
      }
      await finish(tester);
    });

    testWidgets('Home Mode Insights fits, text x$scale', (tester) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';

        await pumpAt(tester, size, scale, const HomeModeDashboardScreen());
        await scrollThroughChecking(tester, 'Student list $label');

        await scrollUntilFound(tester, find.text('Hamza'), towardsTop: true);
        await tapToOpen(
          tester,
          find.text('Hamza'),
          find.text('All students'),
          reason: 'Student detail $label',
        );
        await scrollThroughChecking(tester, 'Student detail $label');

        final aggregate = find.text('Aggregate');
        await scrollUntilFound(tester, aggregate, towardsTop: true);
        await tester.tap(aggregate);
        await settle(tester);
        await scrollThroughChecking(tester, 'Aggregate $label');
      }
      await finish(tester);
    });

    testWidgets('Home Mode opened cards and long-named student fit, '
        'text x$scale', (tester) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        const longName = 'Muhammad Abdurrahman Al-Farouqi';

        await pumpAt(tester, size, scale, const HomeModeDashboardScreen());
        await scrollUntilFound(tester, find.text(longName), towardsTop: false);
        await tapToOpen(
          tester,
          find.text(longName),
          find.text('All students'),
          reason: 'Long name $label',
        );
        await scrollThroughChecking(tester, 'Long-name detail $label');
        await checkOpenedCards(tester, 'student $label');

        await pumpAt(tester, size, scale, const HomeModeDashboardScreen());
        await tester.tap(find.text('Aggregate'));
        await settle(tester);
        await scrollThroughChecking(tester, 'Aggregate $label');
        await checkOpenedCards(tester, 'class $label');
      }
      await finish(tester);
    });

    testWidgets('empty states fit, text x$scale', (tester) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        final screens = <(String, Widget, ProviderContainer, String)>[
          (
            'No classes',
            const ClassroomManagementScreen(),
            noClass,
            'No classes yet',
          ),
          (
            'Library, no class',
            const ModuleLibraryScreen(),
            noClass,
            'Create a class first',
          ),
          (
            'Home Mode, no class',
            const HomeModeDashboardScreen(),
            noClass,
            'No class selected',
          ),
          (
            'Library, no folders',
            const ModuleLibraryScreen(),
            emptyClass,
            'Start your first folder',
          ),
          (
            'Home Mode, no students',
            const HomeModeDashboardScreen(),
            emptyClass,
            'No students yet',
          ),
          (
            'Class Health, no activity',
            ClassHealthDetailScreen(classId: bare.id),
            emptyClass,
            'No classroom activity recorded yet.',
          ),
        ];
        for (final (name, screen, scope, expected) in screens) {
          await pumpAt(tester, size, scale, screen, scope: scope);
          await scrollUntilFound(
            tester,
            find.text(expected),
            towardsTop: false,
          );
          expect(find.text(expected), findsOneWidget, reason: '$name $label');
          await scrollThroughChecking(tester, '$name $label');
        }
      }
      await finish(tester);
    });
  }
}
