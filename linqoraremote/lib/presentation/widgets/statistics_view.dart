import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/controllers/metrics_controller.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class StatisticsView extends StatefulWidget {
  const StatisticsView({super.key});

  @override
  State<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<StatisticsView>
    with SingleTickerProviderStateMixin {
  late final MetricsController metricsController;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    metricsController = Get.find<MetricsController>();
    metricsController.joinMetricsRoom();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    metricsController.leaveMetricsRoom();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Expanded(
            child: Obx(() {
              final cpuMetrics = metricsController.getCurrentCPUMetrics();
              final ramMetrics = metricsController.getCurrentRAMMetrics();

              if (cpuMetrics == null || ramMetrics == null) {
                return Center(
                  child: LoadingAnimationWidget.fourRotatingDots(
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 80,
                  ),
                );
              }

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: 1.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MetricsCard(
                      title: 'Температура процесора',
                      value: '${cpuMetrics.temperature}°C',
                    ),
                    const SizedBox(height: 16),
                    MetricsCard(
                      title: 'Навантаження процесора',
                      value: '${cpuMetrics.loadPercent}%',
                    ),
                    const SizedBox(height: 16),
                    MetricsCard(
                      title: 'Використання пам\'яті',
                      value: '${ramMetrics.usage} ГБ',
                    ),
                    const SizedBox(height: 16),
                    MetricsCard(
                      title: 'Навантаження пам\'яті',
                      value: '${ramMetrics.loadPercent}%',
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class MetricsCard extends StatelessWidget {
  final String title;
  final String value;

  const MetricsCard({required this.title, required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
