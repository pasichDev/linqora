import 'package:get/get.dart';

import '../../../domain/entities/ws_host.dart';
import '../../../domain/usecases/get_all_hosts.dart';

class WsHostController extends GetxController {
  final GetAllHosts getAllHosts;

  WsHostController(this.getAllHosts);

  var hosts = <WsHost>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadHosts();
  }

  void loadHosts() async {
    hosts.value = await getAllHosts();
  }
}
