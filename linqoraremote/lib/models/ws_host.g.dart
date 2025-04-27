// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_host.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WsHostAdapter extends TypeAdapter<WsHost> {
  @override
  final int typeId = 0;

  @override
  WsHost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WsHost(
      id: fields[0] as int,
      name: fields[1] as String,
      ip: fields[2] as String,
      online: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, WsHost obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.ip)
      ..writeByte(3)
      ..write(obj.online);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsHostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
