import '../../domain/entities/ws_host.dart';
import '../../domain/repositories/ws_host_repository.dart';
import '../datasources/ws_host_local_datasource.dart';
import '../models/ws_host_model.dart'; // Імпортуємо модель

class WsHostRepositoryImpl implements WsHostRepository {
  final WsHostLocalDataSource local;

  WsHostRepositoryImpl(this.local);

  @override
  Future<List<WsHost>> getAll() async {
    // Перетворюємо модель Hive на звичайні сутності перед поверненням
    final models = await local.getAll();
    return models
        .map(
          (model) => WsHost(
            id: model.id,
            name: model.name,
            ip: model.ip,
            online: model.online,
          ),
        )
        .toList();
  }

  @override
  Future<void> add(WsHost host) async {
    // Перетворюємо звичайну сутність на модель Hive перед збереженням
    final hostModel = WsHostModel(
      id: host.id,
      name: host.name,
      ip: host.ip,
      online: host.online,
    );
    await local.add(hostModel);
  }

  @override
  Future<void> delete(int id) async {
    await local.delete(id);
  }
}
