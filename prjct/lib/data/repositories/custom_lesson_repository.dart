import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../local/hive_boxes.dart';
import '../models/custom_lesson.dart';
import '../remote/firestore_mirror.dart';

/// Hive-backed CRUD for [CustomLesson] — a teacher's freeform lesson
/// content for one of their classes.
class CustomLessonRepository {
  Box<CustomLesson> get _box => Hive.box<CustomLesson>(HiveBoxes.customLessons);

  Future<CustomLesson> create({
    required String classId,
    required String teacherId,
    required String title,
    required String instructions,
    required String body,
  }) async {
    final lesson = CustomLesson(
      id: const Uuid().v4(),
      classId: classId,
      teacherId: teacherId,
      title: title,
      instructions: instructions,
      body: body,
      createdAt: DateTime.now(),
    );
    await _box.put(lesson.id, lesson);
    return lesson;
  }

  Future<void> delete(String id) => _box.delete(id);

  List<CustomLesson> byClassId(String classId) =>
      _box.values.where((l) => l.classId == classId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Every lesson across the given classIds, newest first — used by the
  /// Student Hub to show what's been assigned across every class the
  /// learner is enrolled in (usually just one).
  List<CustomLesson> byClassIds(Iterable<String> classIds) {
    final ids = classIds.toSet();
    return _box.values.where((l) => ids.contains(l.classId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  CustomLesson? findById(String id) => _box.get(id);

  Future<void> pushAll(FirestoreMirror mirror) async {
    for (final lesson in _box.values) {
      try {
        await mirror.pushCustomLesson(lesson);
      } catch (_) {
        // Best-effort — see `ParentRepository.pushAll`'s doc for why.
      }
    }
  }
}
