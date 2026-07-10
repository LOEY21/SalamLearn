import 'package:hive/hive.dart';

/// Parent/Guardian account (FR-2.1, FR-2.3; Diagrams Figure 5).
///
/// [passwordHash]/[passwordSalt] gate the primary email+password login;
/// [pinHash]/[pinSalt] gate the secondary 4-digit admin-area lock generated
/// at the end of registration. Both are SHA-256 + per-record salt via
/// `CredentialHasher` (Phase 3) — never stored as plain text.
///
/// [email]/[passwordHash]/[passwordSalt] are nullable to also support the
/// PIN-only bootstrap path (`ParentRepository.createPinOnly`) used by the
/// router's `/pin/setup` fallback when a grown-up area is reached before
/// any full registration happened — every account still always has a real
/// hashed PIN.
class ParentAccount extends HiveObject {
  ParentAccount({
    required this.id,
    required this.fullName,
    required this.pinHash,
    required this.pinSalt,
    required this.createdAt,
    this.email,
    this.mobileNumber,
    this.passwordHash,
    this.passwordSalt,
    this.firebaseUid,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? mobileNumber;
  final String? passwordHash;
  final String? passwordSalt;
  final String pinHash;
  final String pinSalt;
  final DateTime createdAt;

  /// Firebase Auth uid, set only if registration happened while online
  /// (Phase 9 — this is what lets Firestore security rules scope a
  /// document to its owner via `request.auth.uid`). Null offline; there's
  /// no way to retroactively create one since the plaintext password is
  /// discarded immediately after hashing.
  final String? firebaseUid;
}

class ParentAccountAdapter extends TypeAdapter<ParentAccount> {
  @override
  final int typeId = 0;

  @override
  ParentAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ParentAccount(
      id: fields[0] as String,
      fullName: fields[1] as String,
      email: fields[2] as String?,
      mobileNumber: fields[3] as String?,
      passwordHash: fields[4] as String?,
      passwordSalt: fields[5] as String?,
      pinHash: fields[6] as String,
      pinSalt: fields[7] as String,
      createdAt: fields[8] as DateTime,
      firebaseUid: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ParentAccount obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.mobileNumber)
      ..writeByte(4)
      ..write(obj.passwordHash)
      ..writeByte(5)
      ..write(obj.passwordSalt)
      ..writeByte(6)
      ..write(obj.pinHash)
      ..writeByte(7)
      ..write(obj.pinSalt)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.firebaseUid);
  }
}
