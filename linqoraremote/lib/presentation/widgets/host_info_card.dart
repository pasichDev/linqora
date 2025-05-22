import 'package:flutter/material.dart';
import 'package:linqoraremote/presentation/widgets/default_card.dart';
import 'package:linqoraremote/presentation/widgets/shimmer_effect.dart';

import '../../data/models/host_info.dart';

class HostInfoCard extends StatelessWidget {
  final HostSystemInfo host;
  final bool isExpanded;
  final VoidCallback refresh;
  final VoidCallback toggleShowHostFull;

  const HostInfoCard({
    required this.host,
    super.key,
    required this.refresh,
    required this.isExpanded,
    required this.toggleShowHostFull,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.computer_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      host.os,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: toggleShowHostFull,
                      icon: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                      style: IconButton.styleFrom(
                        elevation: 0,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainer,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        padding: const EdgeInsets.all(0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      IconButton(
                        onPressed: refresh,
                        icon: Icon(Icons.refresh),
                        style: IconButton.styleFrom(
                          elevation: 0,
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurface,
                          padding: const EdgeInsets.all(0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            if (isExpanded) ...[
              Column(
                children: [
                  const SizedBox(height: 12),
                  // Разделитель
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),

                  // Процессор
                  _buildInfoRow(
                    context,
                    Icons.developer_board,
                    'Процессор',
                    host.cpu.model,
                    "${host.cpu.frequency} MHz • ${host.cpu.physicalCores}/${host.cpu.logicalCores} ядер",
                  ),

                  const SizedBox(height: 12),

                  // Память
                  _buildInfoRow(
                    context,
                    Icons.memory_outlined,
                    'Память',
                    _formatRamInfo(),
                    _formatRamUsage(),
                  ),

                  // GPU - показываем только если есть информация
                  if (host.gpu.model != 'Unknown')
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          context,
                          Icons.developer_board_rounded,
                          'Видеокарта',
                          host.gpu.model,
                          _formatGpuInfo(),
                        ),
                      ],
                    ),

                  // Диски - показываем если есть хотя бы один диск
                  if (host.disks.isNotEmpty)
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildDisksInfo(context),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Форматирование информации о RAM
  String _formatRamInfo() {
    String info = "${host.ram.total} GB";
    if (host.ram.type != 'Unknown') {
      info += " • ${host.ram.type}";
    }
    if (host.ram.frequency > 0) {
      info += " ${host.ram.frequency} MHz";
    }
    return info;
  }

  // Форматирование использования RAM
  String _formatRamUsage() {
    if (host.ram.used > 0 && host.ram.total > 0) {
      return "Используется: ${host.ram.used} GB • Доступно: ${host.ram.total} GB";
    } else if (host.ram.used > 0) {
      return "Используется: ${host.ram.used} GB";
    }
    return "";
  }

  // Форматирование информации о GPU
  String _formatGpuInfo() {
    String info = "";

    // Базовая информация о памяти
    if (host.gpu.memory > 0) {
      double gpuMemoryGB = host.gpu.memory / 1024.0;
      info += "${gpuMemoryGB.toStringAsFixed(1)} GB";
    }

    return info;
  }

  // Виджет для информации о дисках
  Widget _buildDisksInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.storage_rounded, color: colorScheme.secondary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Диски',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...host.disks.map(
          (disk) => Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${disk.name} (${disk.mountPath})",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  "${disk.total} GB • Свободно: ${disk.free} GB • ${disk.fileSystem}",
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String primaryInfo,
    String secondaryInfo,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.secondary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                primaryInfo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (secondaryInfo.isNotEmpty)
                Text(
                  secondaryInfo,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class HostInfoCardSkeleton extends StatelessWidget {
  const HostInfoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                ShimmerEffect(
                  height: 20,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(width: 8),
                ShimmerEffect(height: 18, width: 160),
              ],
            ),

            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),

            // Процессор
            _buildSkeletonRow(context),

            const SizedBox(height: 12),

            // Память
            _buildSkeletonRow(context),

            const SizedBox(height: 12),

            // GPU
            _buildSkeletonRow(context),

            const SizedBox(height: 12),

            // Диски
            _buildSkeletonRow(context),
            _buildSkeletonDisk(context),
            _buildSkeletonDisk(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerEffect(
          height: 18,
          width: 18,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerEffect(height: 12, width: 60),
              SizedBox(height: 4),
              ShimmerEffect(height: 14, width: 180),
              SizedBox(height: 2),
              ShimmerEffect(height: 12, width: 120),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonDisk(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerEffect(height: 14, width: 160),
          SizedBox(height: 2),
          ShimmerEffect(height: 12, width: 200),
        ],
      ),
    );
  }
}
