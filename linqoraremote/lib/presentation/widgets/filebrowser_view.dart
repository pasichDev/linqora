// Note: requires file_delete handler in LinqoraHost/internal/ws/server.go
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import '../controllers/filebrowser_controller.dart';
import '../../data/models/file_item.dart';

class FileBrowserView extends StatefulWidget {
  const FileBrowserView({super.key});

  @override
  State<FileBrowserView> createState() => _FileBrowserViewState();
}

class _FileBrowserViewState extends State<FileBrowserView> {
  late final FileBrowserController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      FileBrowserController(webSocketProvider: Get.find<WebSocketProvider>()),
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<FileBrowserController>()) {
      Get.delete<FileBrowserController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPathBar(context),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildPathBar(BuildContext context) {
    return Obx(() {
      final path = _controller.currentPath.value;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: _controller.pathStack.isEmpty
                  ? null
                  : () => _controller.navigateUp(),
              tooltip: 'back'.tr,
            ),
            Expanded(
              child: Text(
                path.isEmpty ? 'home'.tr : path,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _controller.refresh,
              tooltip: 'refresh'.tr,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildContent(BuildContext context) {
    return Obx(() {
      if (_controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_controller.errorMessage.value.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _controller.errorMessage.value,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _controller.refresh,
                icon: const Icon(Icons.refresh),
                label: Text('retry'.tr),
              ),
            ],
          ),
        );
      }
      if (_controller.items.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(80),
              ),
              const SizedBox(height: 12),
              Text(
                'empty_directory'.tr,
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _controller.items.length,
        itemBuilder: (context, index) {
          final item = _controller.items[index];
          return _buildFileItem(context, item, index);
        },
      );
    });
  }

  Widget _buildFileItem(BuildContext context, FileItem item, int index) {
    return Dismissible(
      key: Key('${_controller.currentPath.value}/${item.name}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('confirm'.tr),
            content: Text('${'confirm_delete'.tr} "${item.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'delete'.tr,
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _controller.deleteItem(item),
      child: ListTile(
        leading: Icon(
          item.isDir ? Icons.folder : _iconForFile(item.name),
          color: item.isDir
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withAlpha(180),
        ),
        title: Text(item.name, overflow: TextOverflow.ellipsis),
        subtitle: item.isDir ? null : Text(item.formattedSize),
        trailing: item.isDir ? const Icon(Icons.chevron_right) : null,
        onTap: item.isDir ? () => _controller.navigateTo(item) : null,
      ).animate().fadeIn(delay: (index * 20).ms, duration: 300.ms),
    );
  }

  IconData _iconForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Icons.videocam;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'ogg':
        return Icons.music_note;
      case 'zip':
      case 'tar':
      case 'gz':
      case '7z':
      case 'rar':
        return Icons.archive;
      case 'txt':
      case 'md':
      case 'log':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }
}
