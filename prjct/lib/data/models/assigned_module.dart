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
  });

  final String id;
  final String classId;
  final String? learnerId;
  final String moduleId;
  final DateTime dueDate;
  final DateTime assignedAt;
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
    );
  }

  @override
  void write(BinaryWriter writer, AssignedModule obj) {
    writer
      ..writeByte(6)
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
      ..write(obj.assignedAt);
  }
}
