import '../entities/ws_host.dart';

abstract class WsHostRepository {
  Future<List<WsHost>> getAll();
  Future<void> add(WsHost host);
  Future<void> delete(int id);
}
