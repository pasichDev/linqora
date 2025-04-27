import 'package:hive/hive.dart';

part 'ws_host.g.dart';

@HiveType(typeId: 0)
class WsHost extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String ip;

  @HiveField(3)
  final bool online;

  WsHost({
    this.id = 0,
    required this.name,
    required this.ip,
    required this.online,
  });

  WsHost copyWith({int? id, String? name, String? ip, bool? online}) {
    return WsHost(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      online: online ?? this.online,
    );
  }
}
