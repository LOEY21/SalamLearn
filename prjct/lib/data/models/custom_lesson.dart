import 'package:hive/hive.dart';

/// A freeform lesson a teacher writes for one of their classes (title +
/// instructions + body text) — distinct from the five core interactive
/// modules (Tracing/Sounds/etc.), which have their own fixed mechanics.
/// This is plain informational content, no interactive grading.
class CustomLesson extends HiveObject {
  CustomLesson({
    required this.id,
    required this.classId,
    required this.teacherId,
    required this.title,
    required this.instructions,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String classId;
  final String teacherId;
  final String title;
  final String instructions;
  final String body;
  final DateTime createdAt;
}

class CustomLessonAdapter extends TypeAdapter<CustomLesson> {
  @override
  final int typeId = 10;

  @override
  CustomLesson read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomLesson(
      id: fields[0] as String,
      classId: fields[1] as String,
      teacherId: fields[2] as String,
      title: fields[3] as String,
      instructions: fields[4] as String,
      body: fields[5] as String,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CustomLesson obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.classId)
      ..writeByte(2)
      ..write(obj.teacherId)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.instructions)
      ..writeByte(5)
      ..write(obj.body)
      ..writeByte(6)
      ..write(obj.createdAt);
  }
}
