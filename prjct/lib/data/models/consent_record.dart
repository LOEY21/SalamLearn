import 'package:hive/hive.dart';

/// Timestamped parental consent for local telemetry collection under
/// the Philippine Data Privacy Act of 2012, RA 10173 (FR-2.2).
class ConsentRecord {
  const ConsentRecord({required this.agreedAt});

  final DateTime agreedAt;
}

class ConsentRecordAdapter extends TypeAdapter<ConsentRecord> {
  @override
  final int typeId = 3;

  @override
  ConsentRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConsentRecord(agreedAt: fields[0] as DateTime);
  }

  @override
  void write(BinaryWriter writer, ConsentRecord obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.agreedAt);
  }
}
