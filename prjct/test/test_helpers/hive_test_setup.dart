import 'dart:io';

import 'package:hive/hive.dart';
import 'package:salamlearn/data/models/assigned_module.dart';
import 'package:salamlearn/data/models/badge_award.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/data/models/consent_record.dart';
import 'package:salamlearn/data/models/custom_lesson.dart';
import 'package:salamlearn/data/models/enrollment.dart';
import 'package:salamlearn/data/models/learner_profile.dart';
import 'package:salamlearn/data/models/lesson_folder.dart';
import 'package:salamlearn/data/models/parent_account.dart';
import 'package:salamlearn/data/models/progress_record.dart';
import 'package:salamlearn/data/models/streak_state.dart';
import 'package:salamlearn/data/models/teacher_account.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';

/// Test-only Hive bootstrap — mirrors `HiveService.init()` but uses the
/// core `Hive.init(path)` against a real temp directory instead of
/// `Hive.initFlutter()`, so tests don't need a mocked path_provider
/// channel. Call [setUpTestHive] in a `setUp`/`setUpAll` and
/// [tearDownTestHive] in the matching `tearDown`/`tearDownAll`.
Future<Directory> setUpTestHive() async {
  final tempDir = await Directory.systemTemp.createTemp('salamlearn_test_hive');
  Hive.init(tempDir.path);

  void registerOnce<T>(int typeId, TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(typeId)) Hive.registerAdapter(adapter);
  }

  registerOnce(0, ParentAccountAdapter());
  registerOnce(1, TeacherAccountAdapter());
  registerOnce(2, LearnerProfileAdapter());
  registerOnce(3, ConsentRecordAdapter());
  registerOnce(4, ClassSectionAdapter());
  registerOnce(5, EnrollmentAdapter());
  registerOnce(6, ProgressRecordAdapter());
  registerOnce(7, AssignedModuleAdapter());
  registerOnce(8, StreakStateAdapter());
  registerOnce(9, BadgeAwardAdapter());
  registerOnce(10, CustomLessonAdapter());
  registerOnce(11, LessonFolderAdapter());

  await Future.wait([
    Hive.openBox<ParentAccount>(HiveBoxes.parents),
    Hive.openBox<TeacherAccount>(HiveBoxes.teachers),
    Hive.openBox<LearnerProfile>(HiveBoxes.learners),
    Hive.openBox<ConsentRecord>(HiveBoxes.consents),
    Hive.openBox<ClassSection>(HiveBoxes.classes),
    Hive.openBox<Enrollment>(HiveBoxes.enrollments),
    Hive.openBox<ProgressRecord>(HiveBoxes.progress),
    Hive.openBox<AssignedModule>(HiveBoxes.assignedModules),
    Hive.openBox<StreakState>(HiveBoxes.streaks),
    Hive.openBox<BadgeAward>(HiveBoxes.badges),
    Hive.openBox<CustomLesson>(HiveBoxes.customLessons),
    Hive.openBox<LessonFolder>(HiveBoxes.lessonFolders),
    Hive.openBox<dynamic>(HiveBoxes.settings),
  ]);

  return tempDir;
}

Future<void> tearDownTestHive(Directory tempDir) async {
  await Hive.close();
  await Hive.deleteFromDisk();
  if (tempDir.existsSync()) {
    tempDir.deleteSync(recursive: true);
  }
}
