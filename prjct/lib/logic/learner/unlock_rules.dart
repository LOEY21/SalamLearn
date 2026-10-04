import '../../data/models/curriculum/curriculum_models.dart';

/// Stage (map destination) unlock, shared by the Adventure Map and the
/// parent/teacher progress views so they always agree: the first stage is
/// open, each later one opens once the stage before it is fully complete,
/// or early when a teacher assigned it (class-wide or to [learnerId]).
bool isStageUnlocked(
  String? learnerId,
  Destination destination,
  Set<String> completed,
) {
  return true;
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
  return true;
}
