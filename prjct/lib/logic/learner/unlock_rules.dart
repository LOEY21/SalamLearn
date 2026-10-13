import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/repositories/class_repository.dart';
import '../../ui/core_modules/module_registry.dart';

/// Stage (map destination) unlock, shared by the Adventure Map and the
/// parent/teacher progress views so they always agree: the first stage is
/// open, each later one opens once the stage before it is fully complete,
/// or early when a teacher assigned it (class-wide or to [learnerId]).
bool isStageUnlocked(
  String? learnerId,
  Destination destination,
  Set<String> completed,
) {
  final index = curriculum.indexWhere((d) => d.id == destination.id);
  if (index <= 0) return true;
  if (curriculum[index - 1].lessons.every((l) => completed.contains(l.id))) {
    return true;
  }
  if (learnerId == null) return false;

  final repo = ClassRepository();
  for (final e in repo.byLearnerId(learnerId)) {
    final assignments = [
      ...repo.assignmentsFor(classId: e.classId, learnerId: null),
      ...repo.assignmentsFor(classId: e.classId, learnerId: learnerId),
    ];
    if (assignments.any(
      (a) => moduleForAssignment(a.moduleId)?.destinationId == destination.id,
    )) {
      return true;
    }
  }
  return false;
}

/// Lesson ("game session") unlock inside a stage — same rule as
/// `DestinationLevelsSheet`: the stage's lessons split into 3 levels, a
/// level opens once the previous one is complete, and each lesson once the
/// one before it in its level is done.
bool isLessonUnlocked(
  String? learnerId,
  Destination destination,
  Lesson lesson,
  Set<String> completed,
) {
  if (!isStageUnlocked(learnerId, destination, completed)) return false;
  final lessons = destination.lessons;
  final perLevel = (lessons.length / 3).ceil();
  final i = lessons.indexWhere((l) => l.id == lesson.id);
  final levelStart = i - i % perLevel;
  if (!lessons.take(levelStart).every((l) => completed.contains(l.id))) {
    return false;
  }
  return i == levelStart || completed.contains(lessons[i - 1].id);
}
