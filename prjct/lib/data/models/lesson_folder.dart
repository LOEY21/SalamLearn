import 'package:hive/hive.dart';

/// FR-6.8 (Custom Lesson Builder) — a teacher-authored, ordered sequence of
/// existing curriculum activities ("modules"), grouped under one named
/// folder (e.g. "Week 4: Wudhu") for streamlined classroom presentation.
///
/// Deliberately references existing curriculum content rather than copying
/// it: each entry in [itemRefs] is a `"destinationId|lessonId|activityId"`
/// string pointing back into `curriculum_data.dart`'s `curriculum` list (see
/// `lib/ui/teacher_dashboard/module_library_data.dart` for the encode/decode
/// helpers and resolution against that list). A plain `List<String>` avoids
/// needing a second nested Hive adapter just to store three ids per item.
///
/// Local-device only, unlike most other teacher-owned models in this repo —
/// no `pushAll`/Firestore mirror method. FR-6.8 doesn't call for
/// cross-device sync of lesson folders, and a teacher curating their own
/// module sequences on their own device is a reasonable scope boundary; add
/// a mirror later if cross-device access becomes a real requirement.
class LessonFolder extends HiveObject {
  LessonFolder({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.name,
    required this.itemRefs,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String teacherId;
  final String classId;
  final String name;

  /// Ordered — this list's order *is* the timeline sequence.
  final List<String> itemRefs;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class LessonFolderAdapter extends TypeAdapter<LessonFolder> {
  @override
  final int typeId = 11;

  @override
  LessonFolder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LessonFolder(
      id: fields[0] as String,
      teacherId: fields[1] as String,
      classId: fields[2] as String,
      name: fields[3] as String,
      itemRefs: (fields[4] as List).cast<String>(),
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LessonFolder obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.teacherId)
      ..writeByte(2)
      ..write(obj.classId)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.itemRefs)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }
}
