import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/models/class_section.dart';
import '../../data/models/custom_lesson.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/custom_lesson_repository.dart';
import '../../data/repositories/learner_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../auth/session.dart';

/// Real, Hive-backed replacement for the hardcoded Ali/Yusra/Hamza roster
/// and single-class state that used to live directly in
/// `teacher_dashboard_screen.dart` (FR-6.1, FR-6.2, FR-6.3).
///
/// A teacher can own several [ClassSection]s; this tracks whichever one is
/// currently being viewed/managed (roster, homework, invitation code all
/// scope to it). The choice persists in the `settings` Hive box under
/// `activeClassId` — same pattern as the Parent side's `activeLearnerId` —
/// so it survives app restarts, defaulting to the first owned class when
/// nothing is picked yet or the stored id no longer belongs to this teacher.
class TeacherClassController extends Notifier<ClassSection?> {
  final _classes = ClassRepository();
  Box get _settings => Hive.box(HiveBoxes.settings);

  @override
  ClassSection? build() {
    final teacherId = ref.watch(
      sessionProvider.select((s) => s.activeTeacherId),
    );
    if (teacherId == null) return null;
    final owned = _classes.byTeacherId(teacherId);
    if (owned.isEmpty) return null;
    final activeId = _settings.get('activeClassId') as String?;
    final match = owned.where((c) => c.id == activeId);
    return match.isNotEmpty ? match.first : owned.first;
  }

  Future<void> createClass({
    required String gradeLevel,
    required String section,
    String? schedule,
  }) async {
    final teacherId = ref.read(sessionProvider).activeTeacherId;
    if (teacherId == null) return;
    final created = await _classes.create(
      teacherId: teacherId,
      gradeLevel: gradeLevel,
      section: section,
      schedule: schedule,
    );
    await _settings.put('activeClassId', created.id);
    state = created;
  }

  /// Switches which owned class the dashboard is viewing (FR-6.1 — a
  /// teacher can manage more than one class section).
  Future<void> switchClass(String classId) async {
    final teacherId = ref.read(sessionProvider).activeTeacherId;
    if (teacherId == null) return;
    final match = _classes.byTeacherId(teacherId).where((c) => c.id == classId);
    if (match.isEmpty) return;
    await _settings.put('activeClassId', classId);
    state = match.first;
  }

  Future<void> regenerateInvitationCode() async {
    final current = state;
    if (current == null) return;
    state = await _classes.regenerateInvitationCode(current);
  }
}

final teacherClassControllerProvider =
    NotifierProvider<TeacherClassController, ClassSection?>(
      TeacherClassController.new,
    );

/// Every class the active teacher owns (FR-6.1) — backs the class
/// switcher in the Profile tab. Watches [teacherClassControllerProvider]
/// purely to force a recompute after create/switch, the same "watch
/// something that changes" trick `parentLearnersProvider` uses since Hive
/// box reads aren't natively observable by Riverpod.
final teacherClassesProvider = Provider<List<ClassSection>>((ref) {
  final teacherId = ref.watch(sessionProvider.select((s) => s.activeTeacherId));
  ref.watch(teacherClassControllerProvider);
  if (teacherId == null) return const [];
  return ClassRepository().byTeacherId(teacherId);
});

final activeClassNameProvider = Provider<String>((ref) {
  final section = ref.watch(teacherClassControllerProvider);
  return section?.name ?? 'No class yet — create one';
});

/// Total enrolled students across every class the teacher owns — backs
/// the Classroom tab's hero stat pill. Sums each owned class's roster
/// rather than reading `teacherRosterProvider` (which is scoped to just
/// the active class).
final teacherTotalStudentsProvider = Provider<int>((ref) {
  final classes = ref.watch(teacherClassesProvider);
  var total = 0;
  for (final section in classes) {
    total += ref.watch(classRosterProvider(section.id)).length;
  }
  return total;
});

final classInvitationCodeProvider = Provider<String>((ref) {
  final section = ref.watch(teacherClassControllerProvider);
  return section?.invitationCode ?? '—';
});

/// Feedback notes are freeform teacher-to-parent text (visible in the
/// use-case diagram's "Assessment and Feedback" box) but have no FR number
/// and weren't part of the Phase 1 model set — kept as session-only
/// state (keyed by learnerId) rather than inventing a new Hive box for
/// them. Resets on app restart; flagged as a known simplification, not a
/// silent omission.
class TeacherFeedbackNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  void setFeedback(String learnerId, String feedback) =>
      state = {...state, learnerId: feedback};
}

final teacherFeedbackProvider =
    NotifierProvider<TeacherFeedbackNotifier, Map<String, String>>(
      TeacherFeedbackNotifier.new,
    );

String _masteryFor(double accuracyPct) {
  if (accuracyPct >= 80) return 'High';
  if (accuracyPct >= 50) return 'Medium';
  return 'Needs help';
}

/// The real roster for one specific class — one entry per learner
/// enrolled in it, with real [ProgressRepository] telemetry. Until Module
/// 4's core learning engines exist and write [ProgressRecord]s,
/// freshly-enrolled learners correctly show 0% completion/accuracy rather
/// than fabricated numbers — that's the actual current state, not a bug.
///
/// Parameterized by `classId` (rather than always reading the "active"
/// class) so the Profile tab's per-class management cards can show every
/// owned class's students at once, not just whichever one happens to be
/// active.
final classRosterProvider = Provider.family<List<Map<String, dynamic>>, String>((
  ref,
  classId,
) {
  final classes = ClassRepository();
  final learners = LearnerRepository();
  final progress = ProgressRepository();
  final feedback = ref.watch(teacherFeedbackProvider);

  final enrollments = classes.byClassId(classId);
  final roster = <Map<String, dynamic>>[];
  for (final enrollment in enrollments) {
    final learner = learners.findById(enrollment.learnerId);
    if (learner == null) continue;
    final summary = progress.summary(enrollment.learnerId);
    final assignments = classes
        .assignmentsFor(classId: classId, learnerId: enrollment.learnerId)
        .map(
          (a) =>
              '${a.moduleId} (Due: ${a.dueDate.day}/${a.dueDate.month}/${a.dueDate.year})',
        )
        .toList();
    roster.add({
      'learnerId': enrollment.learnerId,
      'name': learner.name,
      'completion': summary.accuracyPct / 100,
      'tracing': '${summary.accuracyPct.round()}%',
      'activity': summary.timeOnTaskMinutes == 0
          ? 'No activity yet'
          : '${summary.timeOnTaskMinutes}m logged',
      'mastery': _masteryFor(summary.accuracyPct),
      'feedback': feedback[enrollment.learnerId] ?? '',
      'assignedModules': assignments,
    });
  }
  return roster;
});

/// The active class's roster — what the Roster tab and homework assigner
/// read. Thin wrapper over [classRosterProvider] scoped to whichever class
/// [teacherClassControllerProvider] currently has active.
final teacherRosterProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final section = ref.watch(teacherClassControllerProvider);
  if (section == null) return const [];
  return ref.watch(classRosterProvider(section.id));
});

/// Whole-class (not per-student) homework assignments for the active class.
final classHomeworkProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final section = ref.watch(teacherClassControllerProvider);
  if (section == null) return const [];
  final classes = ClassRepository();
  return classes
      .assignmentsFor(classId: section.id, learnerId: null)
      .map(
        (a) => {
          'module': a.moduleId,
          'dueDate': '${a.dueDate.day}/${a.dueDate.month}/${a.dueDate.year}',
        },
      )
      .toList();
});

/// A class's freeform lessons (title/instructions/body), newest first —
/// backs `class_detail_screen.dart`'s "Custom Lessons" card. Plain Hive
/// read like [classRosterProvider]; callers `ref.invalidate` this after
/// create/delete since Hive box writes aren't natively observable.
final classCustomLessonsProvider = Provider.family<List<CustomLesson>, String>(
  (ref, classId) => CustomLessonRepository().byClassId(classId),
);

/// Every custom lesson across every class the given learner is enrolled
/// in — what the Student Hub's "From your teacher" section reads.
final learnerCustomLessonsProvider =
    Provider.family<List<CustomLesson>, String>((ref, learnerId) {
      final classIds = ClassRepository()
          .byLearnerId(learnerId)
          .map((e) => e.classId);
      return CustomLessonRepository().byClassIds(classIds);
    });
