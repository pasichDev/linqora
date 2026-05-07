// Note: requires file_delete handler in LinqoraHost/internal/ws/server.go
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/core/themes/lin_styles.dart';
import '../controllers/filebrowser_controller.dart';
import '../controllers/device_home_controller.dart';
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
    final homeController = Get.find<DeviceHomeController>();

    // Inject actions into Dashboard AppBar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateAppBar(homeController);
    });

    // Listen to path changes to update AppBar
    _controller.currentPath.listen((_) => _updateAppBar(homeController));
  }

  void _updateAppBar(DeviceHomeController homeController) {
    if (!mounted) return;
    
    homeController.appBarActions.assignAll([
      IconButton(
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        onPressed: _controller.uploadFile,
        tooltip: 'upload'.tr,
      ),
      IconButton(
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        onPressed: _controller.refresh,
        tooltip: 'refresh'.tr,
      ),
    ]);

    homeController.onBackPressed.value = () {
      if (_controller.pathStack.isEmpty) {
        homeController.selectMenuItem(-1);
      } else {
        _controller.navigateUp();
      }
    };

    homeController.appBarTitleOverride.value =
        _controller.currentPath.value.isEmpty
            ? 'file_manager'.tr
            : _controller.currentPath.value.split('/').last;
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
    return _buildContent(context);
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                item.isDir
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            item.isDir ? Icons.folder_rounded : _iconForFile(item.name),
            color:
                item.isDir
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white70,
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle:
            item.isDir
                ? null
                : Text(
                  item.formattedSize,
                  style: TextStyle(color: Colors.white.withOpacity(0.4)),
                ),
        trailing:
            item.isDir
                ? const Icon(Icons.chevron_right_rounded, color: Colors.white24)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.visibility_rounded,
                          color: Colors.white38,
                          size: 20,
                        ),
                        onPressed: () => _controller.viewFile(item),
                        tooltip: 'view'.tr,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white38,
                          size: 20,
                        ),
                        onPressed: () => _controller.downloadFile(item),
                        tooltip: 'download'.tr,
                      ),
                    ],
                  ),
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
