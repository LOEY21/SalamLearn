import 'package:hive_flutter/hive_flutter.dart';

import '../models/assigned_module.dart';
import '../models/badge_award.dart';
import '../models/class_section.dart';
import '../models/consent_record.dart';
import '../models/custom_lesson.dart';
import '../models/enrollment.dart';
import '../models/learner_profile.dart';
import '../models/parent_account.dart';
import '../models/progress_record.dart';
import '../models/streak_state.dart';
import '../models/teacher_account.dart';

/// Hive box name constants — one per entity, plus [settings] for the
/// unstructured key/value data (volumes, language, `lastSyncedAt`).
class HiveBoxes {
  const HiveBoxes._();

  static const parents = 'parents';
  static const teachers = 'teachers';
  static const learners = 'learners';
  static const consents = 'consents';
  static const classes = 'classes';
  static const enrollments = 'enrollments';
  static const progress = 'progress';
  static const assignedModules = 'assigned_modules';
  static const streaks = 'streaks';
  static const badges = 'badges';
  static const customLessons = 'custom_lessons';
  static const settings = 'settings';
}

/// Local persistence bootstrap. `HiveService.init()` must run once, before
/// `runApp`, so every box is open before the first Riverpod provider reads
/// from it.
class HiveService {
  const HiveService._();

  static Future<void> init() async {
    await Hive.initFlutter();

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

    await _openAllBoxes();
  }

  static Future<void> _openAllBoxes() async {
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
      Hive.openBox<dynamic>(HiveBoxes.settings),
    ]);
  }

  /// FR-7.3 "Right to be Forgotten" — deletes every currently-open box's
  /// on-disk file, then reopens them fresh (empty). Deliberately does *not*
  /// re-run [init]'s `Hive.initFlutter()`/adapter registration — the home
  /// directory and adapters are already set up from the app's original
  /// startup call, redoing them would (a) need a live path_provider
  /// channel again and (b) throw on the already-registered adapters.
  static Future<void> eraseEverything() async {
    await Hive.deleteFromDisk();
    await _openAllBoxes();
  }
}
