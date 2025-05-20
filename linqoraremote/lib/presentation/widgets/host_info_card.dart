import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/widgets/shimmer_effect.dart';

import '../../data/models/host_info.dart';

class HostInfoCard extends StatelessWidget {
  final HostSystemInfo host;

  const HostInfoCard({required this.host, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      color: Get.theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(host.os, style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Get.theme.colorScheme.onPrimaryContainer)),
            Text("${host.cpuModel}, ${host.cpuFrequency} MHz, ${host
                .cpuPhysicalCores}/${host.cpuLogicalCores} cores",
              style: TextStyle(fontSize: 12, color: Theme
                  .of(context,)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),),),
            Text("RAM: ${host.virtualMemoryTotal} GB",
              style: TextStyle(fontSize: 12, color: Theme
                  .of(context,)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),),),
          ],),),);
  }
}

class HostInfoCardSkeleton extends StatelessWidget {
  const HostInfoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ShimmerEffect(height: 18, width: 120),
            const SizedBox(height: 8),
            ShimmerEffect(height: 14, width: double.infinity),
            const SizedBox(height: 8),
            ShimmerEffect(height: 14, width: 100),
          ],),),);
  }
}
