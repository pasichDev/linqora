import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import '../../core/themes/lx_theme.dart';
import '../../data/models/file_item.dart';
import '../controllers/filebrowser_controller.dart';
import '../controllers/device_home_controller.dart';
import 'lx_glass.dart';
import 'lx_header.dart';

class FileBrowserView extends StatefulWidget {
  const FileBrowserView({super.key});

  @override
  State<FileBrowserView> createState() => _FileBrowserViewState();
}

class _FileBrowserViewState extends State<FileBrowserView> {
  late final FileBrowserController _controller;
  FileItem? _previewItem;
  String _searchQuery = '';

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

  void _showPreview(FileItem item) {
    setState(() => _previewItem = item);
  }

  String _itemMeta(FileItem item) {
    if (item.isDir) {
      return 'Folder';
    }
    final size = item.formattedSize;
    final date = _formatDate(item.modTime);
    return size.isNotEmpty ? '$size · $date' : date;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  IconData _iconForItem(FileItem item) {
    if (item.isDir) return Icons.folder_rounded;
    final ext = item.name.contains('.')
        ? item.name.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_rounded;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Icons.videocam_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'ogg':
        return Icons.music_note_rounded;
      case 'zip':
      case 'tar':
      case 'gz':
      case '7z':
      case 'rar':
        return Icons.archive_rounded;
      case 'txt':
      case 'md':
      case 'log':
        return Icons.article_rounded;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Widget _buildBreadcrumb() {
    final path = _controller.currentPath.value;
    if (path.isEmpty) {
      return Text(
        'Home',
        style: const TextStyle(fontSize: 11, color: lxTextGhost),
      );
    }
    final parts = path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).toList();
    final widgets = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      if (i > 0) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '/',
              style: TextStyle(fontSize: 11, color: lxTextGhost),
            ),
          ),
        );
      }
      widgets.add(
        Text(
          parts[i],
          style: const TextStyle(fontSize: 11, color: lxTextGhost),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: widgets),
    );
  }

  Widget _buildFileRow(FileItem item) {
    return GestureDetector(
      onTap: () {
        if (item.isDir) {
          _controller.navigateTo(item);
        } else {
          _showPreview(item);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: lxHairline, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: lxGlass2,
                border: Border.all(color: lxHairline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  _iconForItem(item),
                  size: 14,
                  color: item.isDir ? lxAccent : lxTextDim,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                      color: lxText,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    _itemMeta(item),
                    style: const TextStyle(fontSize: 10.5, color: lxTextFaint),
                  ),
                ],
              ),
            ),
            if (item.isDir)
              const Icon(
                Icons.chevron_right_rounded,
                size: 11,
                color: lxTextGhost,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: lxGlass2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.name.contains('.')
                      ? item.name.split('.').last.toUpperCase()
                      : 'FILE',
                  style: const TextStyle(
                    fontSize: 10,
                    color: lxTextFaint,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList() {
    final query = _searchQuery.toLowerCase();
    final filtered = _controller.items
        .where((item) => query.isEmpty || item.name.toLowerCase().contains(query))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_rounded, size: 36, color: lxTextFaint),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty ? 'Empty directory' : 'No results',
              style: const TextStyle(fontSize: 13, color: lxTextFaint),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildFileRow(filtered[index]),
    );
  }

  Widget _buildPreviewModal(FileItem item) {
    return GestureDetector(
      onTap: () => setState(() => _previewItem = null),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: const Color(0x8C0A0C10),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xD90F172A),
                    borderRadius: BorderRadius.circular(lxRadiusModal),
                    border: Border.all(color: lxHairlineHi),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x80000000),
                        blurRadius: 60,
                        offset: Offset(0, 30),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PREVIEW',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.4,
                              color: lxTextFaint,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _previewItem = null),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: lxGlass2,
                                border: Border.all(color: lxHairline),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 11,
                                  color: lxTextDim,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Preview body
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: lxHairline),
                          color: lxSurface,
                        ),
                        child: Center(
                          child: Icon(
                            _iconForItem(item),
                            size: 36,
                            color: lxTextFaint,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                                color: lxText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.formattedSize,
                            style: const TextStyle(
                              fontSize: 11,
                              color: lxTextFaint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _controller.downloadFile(item),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: lxAccent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: lxAccent.withValues(alpha: 0.35),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.download_rounded,
                                      size: 14,
                                      color: lxBg,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Download',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: lxBg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: lxGlass2,
                              border: Border.all(color: lxHairline),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 14,
                                color: lxText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostname =
        Get.find<DeviceHomeController>().hostInfo.value?.hostname ?? 'Device';

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LxHeader(
          title: 'Files',
          eyebrow: '~/$hostname',
          showBack: false,
          action: GestureDetector(
            onTap: _controller.uploadFile,
            child: LxGlass(
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Icon(Icons.add_rounded, size: 14, color: lxTextDim),
                ),
              ),
            ),
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: LxGlass(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 14, color: lxTextFaint),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: lxText, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Search files…',
                      hintStyle: TextStyle(color: lxTextFaint, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: lxGlass2,
                    border: Border.all(color: lxHairline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '⌘K',
                    style: TextStyle(
                      fontSize: 10,
                      color: lxTextFaint,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Breadcrumb row
        Obx(
          () => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(child: _buildBreadcrumb()),
              ],
            ),
          ),
        ),
        // Top border + file list
        Expanded(
          child: Column(
            children: [
              const Divider(color: lxHairline, height: 1, thickness: 1),
              Expanded(
                child: Obx(() {
                  if (_controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: lxAccent,
                        strokeWidth: 2,
                      ),
                    );
                  }
                  if (_controller.errorMessage.value.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 36,
                            color: lxTextFaint,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _controller.errorMessage.value,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: lxTextFaint,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _controller.refresh,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: lxGlass2,
                                border: Border.all(color: lxHairline),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: lxTextDim,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return _buildFileList();
                }),
              ),
            ],
          ),
        ),
      ],
    );

    return Stack(
      children: [
        body,
        if (_previewItem != null)
          Positioned.fill(
            child: _buildPreviewModal(_previewItem!),
          ),
      ],
    );
  }
}
