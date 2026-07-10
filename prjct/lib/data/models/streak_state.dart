import 'package:hive/hive.dart';

/// Consecutive-days-played tracker backing the Student Hub streak badge
/// (FR-3.2; Diagrams Figure 2 "Update streak tracker"). One record per
/// learner, keyed by [learnerId] in its Hive box.
class StreakState extends HiveObject {
  StreakState({
    required this.learnerId,
    required this.currentStreak,
    required this.lastPlayedDate,
  });

  final String learnerId;
  final int currentStreak;
  final DateTime lastPlayedDate;
}

class StreakStateAdapter extends TypeAdapter<StreakState> {
  @override
  final int typeId = 8;

  @override
  StreakState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StreakState(
      learnerId: fields[0] as String,
      currentStreak: fields[1] as int,
      lastPlayedDate: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, StreakState obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.learnerId)
      ..writeByte(1)
      ..write(obj.currentStreak)
      ..writeByte(2)
      ..write(obj.lastPlayedDate);
  }
}
