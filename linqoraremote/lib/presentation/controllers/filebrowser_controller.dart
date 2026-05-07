import 'package:get/get.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/error_handler.dart';
import '../../data/enums/type_request_host.dart';
import '../../data/models/file_item.dart';
import '../../data/models/ws_message.dart';
import '../../data/providers/websocket_provider.dart';

class FileBrowserController extends GetxController {
  final WebSocketProvider webSocketProvider;

  FileBrowserController({required this.webSocketProvider});

  final items = <FileItem>[].obs;
  final currentPath = ''.obs;
  final pathStack = <String>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    webSocketProvider.registerHandler(
      TypeMessageWs.file_list.value,
      _handleFileList,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.file_delete.value,
      _handleFileDelete,
    );
    listDir('');
    super.onInit();
  }

  @override
  void onClose() {
    webSocketProvider.removeHandler(TypeMessageWs.file_list.value);
    webSocketProvider.removeHandler(TypeMessageWs.file_delete.value);
    super.onClose();
  }

  void listDir(String path) {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final msg = WsMessage(type: TypeMessageWs.file_list.value)
        ..setField('data', {'path': path});
      webSocketProvider.sendMessage(msg.toJson());
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = e.toString();
      AppLogger.release(
        'FileBrowser listDir error: $e',
        module: 'FileBrowserController',
      );
    }
  }

  void _handleFileList(Map<String, dynamic> data) {
    isLoading.value = false;
    if (data['status'] == 'error') {
      errorMessage.value = data['message'] ?? 'error'.tr;
      return;
    }
    final rawPath = data['data']?['path'] as String? ?? '';
    // The Go backend returns the list under the key "files"
    final rawItems = data['data']?['files'] as List<dynamic>? ?? [];
    currentPath.value = rawPath;
    items.value = rawItems
        .map((e) => FileItem.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  void navigateTo(FileItem item) {
    if (!item.isDir) return;
    final newPath = currentPath.value.isEmpty
        ? item.name
        : '${currentPath.value}/${item.name}';
    pathStack.add(currentPath.value);
    listDir(newPath);
  }

  bool navigateUp() {
    if (pathStack.isEmpty) return false;
    final parent = pathStack.removeLast();
    listDir(parent);
    return true;
  }

  void deleteItem(FileItem item) {
    final path = currentPath.value.isEmpty
        ? item.name
        : '${currentPath.value}/${item.name}';
    try {
      final msg = WsMessage(type: TypeMessageWs.file_delete.value)
        ..setField('data', {'path': path});
      webSocketProvider.sendMessage(msg.toJson());
    } catch (e) {
      showErrorSnackbar('error'.tr, e.toString());
    }
  }

  void _handleFileDelete(Map<String, dynamic> data) {
    if (data['status'] == 'error') {
      showErrorSnackbar('error'.tr, data['message'] ?? 'error'.tr);
      return;
    }
    listDir(currentPath.value);
  }

  void refresh() => listDir(currentPath.value);
}
