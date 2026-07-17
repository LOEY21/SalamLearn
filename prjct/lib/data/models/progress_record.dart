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
    this.lessonId,
    this.isClassroomMode = false,
  });

  final String id;
  final String learnerId;
  final String moduleId;
  final double strokeAccuracyPct;
  final int sequencingErrors;
  final int timeOnTaskSeconds;
  final DateTime completedAt;
  final bool assignedByTeacher;

  /// True only for telemetry written live during a teacher's Cast session
  /// (Hot Seat tracing) — as opposed to solo Student Hub/Adventure Map
  /// play, which never sets this. Lets the Teacher Dashboard's Class
  /// Health Index (FR-6.2) count classroom activity exclusively, matching
  /// what the SRS actually specifies for that widget.
  final bool isClassroomMode;

  /// The specific lesson (within [moduleId]'s destination) this record
  /// completed — drives the Adventure Map's per-lesson/per-level unlock
  /// gating in `destination_levels_sheet.dart`. Nullable/field-8 so old
  /// records written before this existed still decode fine (`fields[8]`
  /// simply reads as null).
  final String? lessonId;
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
      lessonId: fields[8] as String?,
      isClassroomMode: fields[9] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ProgressRecord obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.assignedByTeacher)
      ..writeByte(8)
      ..write(obj.lessonId)
      ..writeByte(9)
      ..write(obj.isClassroomMode);
  }
}
