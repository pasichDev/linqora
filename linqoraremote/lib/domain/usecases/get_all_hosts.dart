import '../entities/ws_host.dart';
import '../repositories/ws_host_repository.dart';

class GetAllHosts {
  final WsHostRepository repository;

  GetAllHosts(this.repository);

  Future<List<WsHost>> call() => repository.getAll();
}
