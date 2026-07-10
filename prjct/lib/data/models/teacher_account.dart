import 'package:hive/hive.dart';

/// Asatidz/Teacher account (FR-2.1, FR-6.1; Diagrams Figure 6).
///
/// See [ParentAccount] doc for the password/PIN hashing convention — the
/// two account types are deliberately separate Hive types (not a shared
/// base class) since they carry different fields ([school]) and are never
/// queried together.
class TeacherAccount extends HiveObject {
  TeacherAccount({
    required this.id,
    required this.fullName,
    required this.pinHash,
    required this.pinSalt,
    required this.createdAt,
    this.school,
    this.email,
    this.mobileNumber,
    this.passwordHash,
    this.passwordSalt,
    this.firebaseUid,
  });

  final String id;
  final String fullName;
  final String? school;
  final String? email;
  final String? mobileNumber;
  final String? passwordHash;
  final String? passwordSalt;
  final String pinHash;
  final String pinSalt;
  final DateTime createdAt;

  /// See `ParentAccount.firebaseUid` doc.
  final String? firebaseUid;
}

class TeacherAccountAdapter extends TypeAdapter<TeacherAccount> {
  @override
  final int typeId = 1;

  @override
  TeacherAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TeacherAccount(
      id: fields[0] as String,
      fullName: fields[1] as String,
      school: fields[2] as String?,
      email: fields[3] as String?,
      mobileNumber: fields[4] as String?,
      passwordHash: fields[5] as String?,
      passwordSalt: fields[6] as String?,
      pinHash: fields[7] as String,
      pinSalt: fields[8] as String,
      createdAt: fields[9] as DateTime,
      firebaseUid: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TeacherAccount obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.school)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.mobileNumber)
      ..writeByte(5)
      ..write(obj.passwordHash)
      ..writeByte(6)
      ..write(obj.passwordSalt)
      ..writeByte(7)
      ..write(obj.pinHash)
      ..writeByte(8)
      ..write(obj.pinSalt)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.firebaseUid);
  }
}
