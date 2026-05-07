import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
    webSocketProvider.registerHandler(
      TypeMessageWs.file_read.value,
      _handleFileRead,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.file_write.value,
      _handleFileWrite,
    );
    listDir('');
    super.onInit();
  }

  @override
  void onClose() {
    webSocketProvider.removeHandler(TypeMessageWs.file_list.value);
    webSocketProvider.removeHandler(TypeMessageWs.file_delete.value);
    webSocketProvider.removeHandler(TypeMessageWs.file_read.value);
    webSocketProvider.removeHandler(TypeMessageWs.file_write.value);
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

  Future<void> downloadFile(FileItem item) async {
    if (item.isDir) return;
    isLoading.value = true;
    final path = currentPath.value.isEmpty
        ? item.name
        : '${currentPath.value}/${item.name}';
    try {
      final msg = WsMessage(type: TypeMessageWs.file_read.value)
        ..setField('data', {'path': path});
      webSocketProvider.sendMessage(msg.toJson());
    } catch (e) {
      isLoading.value = false;
      showErrorSnackbar('error'.tr, e.toString());
    }
  }

  Future<void> uploadFile() async {
    try {
      final result = await fp.FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = await File(file.path!).readAsBytes();
      final base64Content = base64Encode(bytes);

      isLoading.value = true;
      final remotePath = currentPath.value.isEmpty
          ? file.name
          : '${currentPath.value}/${file.name}';

      final msg = WsMessage(type: TypeMessageWs.file_write.value)
        ..setField('data', {'path': remotePath, 'content': base64Content});

      webSocketProvider.sendMessage(msg.toJson());
    } catch (e) {
      isLoading.value = false;
      showErrorSnackbar('error'.tr, e.toString());
    }
  }

  final isViewing = false.obs;

  Future<void> viewFile(FileItem item) async {
    if (item.isDir) return;
    isViewing.value = true;
    isLoading.value = true;
    final path = currentPath.value.isEmpty
        ? item.name
        : '${currentPath.value}/${item.name}';
    try {
      final msg = WsMessage(type: TypeMessageWs.file_read.value)
        ..setField('data', {'path': path});
      webSocketProvider.sendMessage(msg.toJson());
    } catch (e) {
      isLoading.value = false;
      isViewing.value = false;
      showErrorSnackbar('error'.tr, e.toString());
    }
  }

  void _handleFileRead(Map<String, dynamic> data) async {
    isLoading.value = false;
    final viewMode = isViewing.value;
    isViewing.value = false;

    if (data['status'] == 'error') {
      showErrorSnackbar('error'.tr, data['message'] ?? 'error'.tr);
      return;
    }

    try {
      final String fileName = data['data']?['name'] ?? 'file';
      final String base64Content = data['data']?['content'] ?? '';
      if (base64Content.isEmpty) return;

      final bytes = base64Decode(base64Content);

      if (viewMode) {
        final ext = fileName.split('.').last.toLowerCase();
        final textExts = ['txt', 'md', 'log', 'json', 'yaml', 'yml', 'go', 'dart', 'js', 'py', 'sh', 'bat', 'ps1'];
        
        if (textExts.contains(ext)) {
          final text = utf8.decode(bytes);
          Get.dialog(
            Dialog(
              backgroundColor: const Color(0xFF0F172A),
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            fileName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          text,
                          style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          return;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Share/Open the file
      await Share.shareXFiles([XFile(file.path)], text: fileName);
    } catch (e) {
      showErrorSnackbar('error'.tr, 'Failed to process file: $e');
    }
  }

  void _handleFileWrite(Map<String, dynamic> data) {
    isLoading.value = false;
    if (data['status'] == 'error') {
      showErrorSnackbar('error'.tr, data['message'] ?? 'error'.tr);
      return;
    }
    Get.snackbar(
      'success'.tr,
      'file_uploaded_success'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
    listDir(currentPath.value);
  }
}
