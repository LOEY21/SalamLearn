import 'package:hive/hive.dart';

/// Learner (child) entity created by the parent (FR-2.3).
///
/// [id], [parentId], [username], [passwordHash], [passwordSalt],
/// [gradeLevel], and [createdAt] back the real Hive-persisted registration
/// flow (Diagrams and Flowcharts.pdf, Figure 7) — they are nullable/optional
/// for now so the in-memory session (Phase 4 of the backend plan) can adopt
/// them without breaking existing call sites in the same change.
class LearnerProfile extends HiveObject {
  LearnerProfile({
    required this.name,
    required this.age,
    this.avatar = '🧒',
    this.id,
    this.parentId,
    this.username,
    this.passwordHash,
    this.passwordSalt,
    this.gradeLevel = 'Grade 1',
    this.createdAt,
  });

  final String name;
  final int age;
  final String avatar;
  final String? id;
  final String? parentId;
  final String? username;
  final String? passwordHash;
  final String? passwordSalt;
  final String gradeLevel;
  final DateTime? createdAt;

  String? get studentId => id == null ? null : studentIdFor(id!);
}

/// The 8-digit Student ID ("1234-5678") a teacher enrolls a learner with.
/// Derived from the learner's doc id (FNV-1a) rather than stored, so every
/// learner — old, parent-made or admin-made — has one with no migration.
/// Masked to 32 bits each step so the web build (JS doubles) matches.
// ponytail: 8 digits from a 32-bit hash, collisions possible at scale —
// `findAllByStudentId` callers already handle 2+ matches.
String studentIdFor(String learnerId) {
  var h = 0x811c9dc5;
  for (final c in learnerId.codeUnits) {
    h ^= c;
    h = (((h << 24) & 0xFFFFFFFF) + h * 403) & 0xFFFFFFFF;
  }
  final digits = (h % 100000000).toString().padLeft(8, '0');
  return '${digits.substring(0, 4)}-${digits.substring(4)}';
}

/// Strips spaces/dashes so "1234 5678", "12345678" and "1234-5678" all match.
String normalizeStudentId(String input) => input.replaceAll(RegExp(r'\D'), '');

/// Hand-written Hive adapter (no build_runner — see Phase 1 plan notes:
/// `hive_generator`'s pinned analyzer range conflicts with the
/// `flutter_riverpod` 3.x toolchain, so every model in this project is
/// serialized by hand instead of via codegen).
class LearnerProfileAdapter extends TypeAdapter<LearnerProfile> {
  @override
  final int typeId = 2;

  @override
  LearnerProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LearnerProfile(
      name: fields[0] as String,
      age: fields[1] as int,
      avatar: fields[2] as String,
      id: fields[3] as String?,
      parentId: fields[4] as String?,
      username: fields[5] as String?,
      passwordHash: fields[6] as String?,
      passwordSalt: fields[7] as String?,
      gradeLevel: fields[8] as String,
      createdAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LearnerProfile obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.age)
      ..writeByte(2)
      ..write(obj.avatar)
      ..writeByte(3)
      ..write(obj.id)
      ..writeByte(4)
      ..write(obj.parentId)
      ..writeByte(5)
      ..write(obj.username)
      ..writeByte(6)
      ..write(obj.passwordHash)
      ..writeByte(7)
      ..write(obj.passwordSalt)
      ..writeByte(8)
      ..write(obj.gradeLevel)
      ..writeByte(9)
      ..write(obj.createdAt);
  }
}
