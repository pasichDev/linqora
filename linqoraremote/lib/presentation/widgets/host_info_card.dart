import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/core/themes/lin_styles.dart';
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

    return LinStyles.glassMorphism(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.dns_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          host.os,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (isExpanded)
                      IconButton(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      onPressed: toggleShowHostFull,
                      icon: Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 28,
                      ),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 20),
              _buildInfoRow(
                context,
                Icons.developer_board_rounded,
                'cpu'.tr,
                host.cpu.model,
                "${host.cpu.frequency} MHz • ${host.cpu.physicalCores}/${host.cpu.logicalCores} ${'cores'.tr}",
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                Icons.memory_rounded,
                'ram'.tr,
                _formatRamInfo(),
                _formatRamUsage(),
              ),
              if (host.gpu.model != 'Unknown') ...[
                const SizedBox(height: 16),
                _buildInfoRow(
                  context,
                  Icons.videogame_asset_rounded,
                  'gpu'.tr,
                  host.gpu.model,
                  _formatGpuInfo(),
                ),
              ],
              if (host.disks.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildDisksInfo(context),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatRamInfo() {
    String info = "${host.ram.total} GB";
    if (host.ram.type != 'unknown'.tr) {
      info += " • ${host.ram.type}";
    }
    if (host.ram.frequency > 0) {
      info += " ${host.ram.frequency} MHz";
    }
    return info;
  }

  String _formatRamUsage() {
    if (host.ram.used > 0 && host.ram.total > 0) {
      return "${'used'.tr}: ${host.ram.used} GB • ${'available'.tr}: ${host.ram.total} GB";
    } else if (host.ram.used > 0) {
      return "${'used'.tr}: ${host.ram.used} GB";
    }
    return "";
  }

  String _formatGpuInfo() {
    if (host.gpu.memory > 0) {
      double gpuMemoryGB = host.gpu.memory / 1024.0;
      return "${gpuMemoryGB.toStringAsFixed(1)} GB";
    }
    return "";
  }

  Widget _buildDisksInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.storage_rounded, color: colorScheme.secondary, size: 18),
            const SizedBox(width: 12),
            Text(
              'disk'.tr.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: colorScheme.secondary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...host.disks.map(
          (disk) => Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${disk.name} (${disk.mountPath})",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${disk.total} GB • ${'free'.tr}: ${disk.free} GB • ${disk.fileSystem}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.secondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                primaryInfo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (secondaryInfo.isNotEmpty)
                Text(
                  secondaryInfo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
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
    return LinStyles.glassMorphism(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerEffect(height: 36, width: 36, borderRadius: BorderRadius.circular(10)),
                const SizedBox(width: 12),
                const ShimmerEffect(height: 20, width: 140),
              ],
            ),
            const SizedBox(height: 24),
            _buildSkeletonRow(),
            const SizedBox(height: 16),
            _buildSkeletonRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerEffect(height: 18, width: 18, borderRadius: BorderRadius.all(Radius.circular(4))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerEffect(height: 10, width: 50),
              SizedBox(height: 6),
              ShimmerEffect(height: 14, width: 180),
              SizedBox(height: 4),
              ShimmerEffect(height: 12, width: 120),
            ],
          ),
        ),
      ],
    );
  }
}
