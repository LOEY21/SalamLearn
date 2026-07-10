import 'package:hive/hive.dart';

/// A teacher-managed class section (FR-6.1; Diagrams Figure 4 "Create
/// Class"/"Generate Invitation Code"). [gradeLevel] and [section] are the
/// two inputs the Create Class form collects; [name] stays the combined
/// display string ("Grade 1 - Section A") so every existing reader (the
/// Parent class-join UI, the Firestore mirror, dashboard headers) keeps
/// working unchanged.
class ClassSection extends HiveObject {
  ClassSection({
    required this.id,
    required this.teacherId,
    required this.name,
    required this.invitationCode,
    required this.createdAt,
    this.gradeLevel,
    this.section,
    this.schedule,
  });

  final String id;
  final String teacherId;
  final String name;
  final String invitationCode;
  final DateTime createdAt;
  final String? gradeLevel;
  final String? section;

  /// Free-text meeting schedule collected on the Create Class form (e.g.
  /// "Mon/Wed/Fri, 9:00–10:00 AM") — nullable since classes created before
  /// this field existed have none on file.
  final String? schedule;
}

class ClassSectionAdapter extends TypeAdapter<ClassSection> {
  @override
  final int typeId = 4;

  @override
  ClassSection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClassSection(
      id: fields[0] as String,
      teacherId: fields[1] as String,
      name: fields[2] as String,
      invitationCode: fields[3] as String,
      createdAt: fields[4] as DateTime,
      gradeLevel: fields[5] as String?,
      section: fields[6] as String?,
      schedule: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ClassSection obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.teacherId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.invitationCode)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.gradeLevel)
      ..writeByte(6)
      ..write(obj.section)
      ..writeByte(7)
      ..write(obj.schedule);
  }
}
