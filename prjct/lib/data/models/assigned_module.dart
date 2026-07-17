import 'package:hive/hive.dart';

/// A take-home module assignment (FR-6.3). [learnerId] is null when the
/// teacher assigned it to the whole class rather than one student — the
/// Learner's Student Hub resolves whether a module is "Assigned" by
/// checking both a matching [learnerId] and, if null, the learner's
/// enrolled [classId].
class AssignedModule extends HiveObject {
  AssignedModule({
    required this.id,
    required this.classId,
    required this.moduleId,
    required this.dueDate,
    required this.assignedAt,
    this.learnerId,
    this.maxLevel = 3,
    this.maxLessons,
  });

  final String id;
  final String classId;
  final String? learnerId;
  final String moduleId;
  final DateTime dueDate;
  final DateTime assignedAt;

  /// How far into this destination's 3 levels (Beginner/Practice/Mastery)
  /// the teacher has allowed this assignment to reach — the Adventure Map's
  /// level gating never opens a level past this, regardless of lesson
  /// completion. Defaults to 3 (no ceiling) so pre-existing assignments
  /// written before this field existed keep behaving as "fully open".
  final int maxLevel;

  /// How many lessons ("games") within the highest level [maxLevel] allows
  /// are unlocked — earlier levels stay fully open once [maxLevel] admits
  /// them, but the top level itself only opens this many lessons in order,
  /// regardless of completion. `null` means no cap (every lesson in that
  /// level is open).
  final int? maxLessons;
}

class AssignedModuleAdapter extends TypeAdapter<AssignedModule> {
  @override
  final int typeId = 7;

  @override
  AssignedModule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AssignedModule(
      id: fields[0] as String,
      classId: fields[1] as String,
      learnerId: fields[2] as String?,
      moduleId: fields[3] as String,
      dueDate: fields[4] as DateTime,
      assignedAt: fields[5] as DateTime,
      maxLevel: fields[6] as int? ?? 3,
      maxLessons: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, AssignedModule obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.classId)
      ..writeByte(2)
      ..write(obj.learnerId)
      ..writeByte(3)
      ..write(obj.moduleId)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.assignedAt)
      ..writeByte(6)
      ..write(obj.maxLevel)
      ..writeByte(7)
      ..write(obj.maxLessons);
  }
}
