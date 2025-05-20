import 'package:flutter/material.dart';
import 'package:linqoraremote/presentation/widgets/shimmer_effect.dart';

import '../../data/models/host_info.dart';

class HostInfoCard extends StatelessWidget {
  final HostSystemInfo host;

  const HostInfoCard({required this.host, super.key});

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
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.computer_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      host.os,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Разделитель
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 12),

            // Процессор
            _buildInfoRow(
              context,
              Icons.memory_rounded,
              'Процессор',
              host.cpuModel,
              "${host.cpuFrequency} MHz • ${host.cpuPhysicalCores}/${host.cpuLogicalCores} ядер",
            ),

            const SizedBox(height: 12),

            // Память
            _buildInfoRow(
              context,
              Icons.developer_board,
              'RAM',
              "${host.virtualMemoryTotal} GB",
              "",
            ),
          ],
        ),
      ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                secondaryInfo,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
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
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(width: 8),
                ShimmerEffect(height: 18, width: 160),
              ],
            ),

            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 12),

            // Процессор
            _buildSkeletonRow(context),

            const SizedBox(height: 12),

            // Память
            _buildSkeletonRow(context),
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
          borderRadius: BorderRadius.all(Radius.circular(4)),
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
}
