import 'package:get/get.dart';
import '../../data/datasources/ws_host_local_datasource.dart';
import '../../data/repositories/ws_host_repository_impl.dart';
import '../../domain/usecases/get_all_hosts.dart';
import '../controllers/ws_host_controller.dart';

class WsHostBinding extends Bindings {
  @override
  void dependencies() {
    // Спочатку реєструємо локальне джерело даних
    Get.lazyPut<WsHostLocalDataSource>(() => WsHostLocalDataSource());

    // Регіструємо репозиторій, який потребує доступу до локального джерела даних
    Get.lazyPut<WsHostRepositoryImpl>(() => WsHostRepositoryImpl(Get.find<WsHostLocalDataSource>()));

    // Регіструємо use case, який потребує репозиторій
    Get.lazyPut(() => GetAllHosts(Get.find<WsHostRepositoryImpl>()));

    // Регіструємо контролер, який потребує use case
    Get.lazyPut(() => WsHostController(Get.find<GetAllHosts>()));
  }
}
