import 'package:hive/hive.dart';

import '../../domain/entities/ws_host.dart';

part 'ws_host_model.g.dart';

@HiveType(typeId: 0)
class WsHostModel extends WsHost {
  @HiveField(0)
  @override
  final int id;

  @HiveField(1)
  @override
  final String name;

  @HiveField(2)
  @override
  final String ip;

  @HiveField(3)
  @override
  final bool online;

  WsHostModel({
    required this.id,
    required this.name,
    required this.ip,
    required this.online,
  }) : super(id: id, name: name, ip: ip, online: online);
}
