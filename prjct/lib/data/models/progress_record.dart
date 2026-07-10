import 'package:hive/hive.dart';

/// A single gameplay telemetry entry (the SRS's `ProgressBox` — data-flow
/// section, "Save learner progress into the local ProgressBox in the Hive
/// database"). Written synchronously by a core module's collision/tracing
/// engine on activity completion (FR-4.1–FR-4.5), read back by the Parent
/// Analytics Dashboard (FR-5.1) and Teacher Dashboard (FR-6.2).
class ProgressRecord extends HiveObject {
  ProgressRecord({
    required this.id,
    required this.learnerId,
    required this.moduleId,
    required this.strokeAccuracyPct,
    required this.sequencingErrors,
    required this.timeOnTaskSeconds,
    required this.completedAt,
    this.assignedByTeacher = false,
  });

  final String id;
  final String learnerId;
  final String moduleId;
  final double strokeAccuracyPct;
  final int sequencingErrors;
  final int timeOnTaskSeconds;
  final DateTime completedAt;
  final bool assignedByTeacher;
}

class ProgressRecordAdapter extends TypeAdapter<ProgressRecord> {
  @override
  final int typeId = 6;

  @override
  ProgressRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgressRecord(
      id: fields[0] as String,
      learnerId: fields[1] as String,
      moduleId: fields[2] as String,
      strokeAccuracyPct: fields[3] as double,
      sequencingErrors: fields[4] as int,
      timeOnTaskSeconds: fields[5] as int,
      completedAt: fields[6] as DateTime,
      assignedByTeacher: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ProgressRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.learnerId)
      ..writeByte(2)
      ..write(obj.moduleId)
      ..writeByte(3)
      ..write(obj.strokeAccuracyPct)
      ..writeByte(4)
      ..write(obj.sequencingErrors)
      ..writeByte(5)
      ..write(obj.timeOnTaskSeconds)
      ..writeByte(6)
      ..write(obj.completedAt)
      ..writeByte(7)
      ..write(obj.assignedByTeacher);
  }
}
