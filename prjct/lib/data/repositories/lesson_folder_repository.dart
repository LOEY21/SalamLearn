import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../local/hive_boxes.dart';
import '../models/lesson_folder.dart';

/// Hive-backed CRUD for [LessonFolder] — FR-6.8's Custom Lesson Builder.
class LessonFolderRepository {
  Box<LessonFolder> get _box => Hive.box<LessonFolder>(HiveBoxes.lessonFolders);

  Future<LessonFolder> create({
    required String classId,
    required String teacherId,
    required String name,
    required List<String> itemRefs,
  }) async {
    final now = DateTime.now();
    final folder = LessonFolder(
      id: const Uuid().v4(),
      teacherId: teacherId,
      classId: classId,
      name: name,
      itemRefs: itemRefs,
      createdAt: now,
      updatedAt: now,
    );
    await _box.put(folder.id, folder);
    return folder;
  }

  /// Replaces a folder's name and/or sequence in place — used by the
  /// builder screen's "Save" action when editing an existing folder rather
  /// than creating a new one.
  Future<LessonFolder> update({
    required LessonFolder folder,
    required String name,
    required List<String> itemRefs,
  }) async {
    final updated = LessonFolder(
      id: folder.id,
      teacherId: folder.teacherId,
      classId: folder.classId,
      name: name,
      itemRefs: itemRefs,
      createdAt: folder.createdAt,
      updatedAt: DateTime.now(),
    );
    await _box.put(folder.id, updated);
    return updated;
  }

  Future<void> delete(String id) => _box.delete(id);

  LessonFolder? findById(String id) => _box.get(id);

  List<LessonFolder> byClassId(String classId) =>
      _box.values.where((f) => f.classId == classId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}
