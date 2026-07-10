import 'package:hive/hive.dart';

/// A single Digital Backpack achievement badge earned by a learner
/// (FR-3.3). [badgeId] identifies which badge (the badge catalog itself
/// lives with the core modules, not here — this model only records that
/// a learner earned one, and when).
class BadgeAward extends HiveObject {
  BadgeAward({
    required this.learnerId,
    required this.badgeId,
    required this.earnedAt,
  });

  final String learnerId;
  final String badgeId;
  final DateTime earnedAt;
}

class BadgeAwardAdapter extends TypeAdapter<BadgeAward> {
  @override
  final int typeId = 9;

  @override
  BadgeAward read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BadgeAward(
      learnerId: fields[0] as String,
      badgeId: fields[1] as String,
      earnedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BadgeAward obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.learnerId)
      ..writeByte(1)
      ..write(obj.badgeId)
      ..writeByte(2)
      ..write(obj.earnedAt);
  }
}
