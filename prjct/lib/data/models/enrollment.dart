import 'package:hive/hive.dart';

/// Links a [LearnerProfile] to a [ClassSection] (FR-6.1; Diagrams Figure 4
/// "Enroll Students"). Keyed by `'$classId:$learnerId'` in its Hive box so
/// enrollment is naturally deduplicated per class/learner pair.
class Enrollment extends HiveObject {
  Enrollment({
    required this.classId,
    required this.learnerId,
    required this.enrolledAt,
  });

  final String classId;
  final String learnerId;
  final DateTime enrolledAt;
}

class EnrollmentAdapter extends TypeAdapter<Enrollment> {
  @override
  final int typeId = 5;

  @override
  Enrollment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Enrollment(
      classId: fields[0] as String,
      learnerId: fields[1] as String,
      enrolledAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Enrollment obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.classId)
      ..writeByte(1)
      ..write(obj.learnerId)
      ..writeByte(2)
      ..write(obj.enrolledAt);
  }
}
