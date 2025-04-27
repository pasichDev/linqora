import 'package:hive/hive.dart';

import '../models/ws_host_model.dart';

class WsHostLocalDataSource {
  Box<WsHostModel>? _box;

  Future<Box<WsHostModel>> get box async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<WsHostModel>('hosts');
    }
    return _box!;
  }

  Future<List<WsHostModel>> getAll() async {
    final boxInstance = await box;
    return boxInstance.values.toList();
  }

  Future<void> add(WsHostModel host) async {
    final boxInstance = await box;
    await boxInstance.put(host.id, host);
  }

  Future<void> delete(int id) async {
    final boxInstance = await box;
    await boxInstance.delete(id);
  }
}
