import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/presentation/controllers/monitoring_controller.dart';
import 'package:linqoraremote/presentation/widgets/loading_view.dart';

import 'banner.dart';
import 'metrics/metric_card.dart';
import 'metrics/metric_chart.dart';
import 'metrics/metrics_row.dart';

/// - Зміна шаблона відображення моніторнигу (стандартний - той що є, спрощений). Спрощений - це відображення без графіка, але згрупувати по категоріям (CPU,RAM,GPU,DISK)
/// - Реалізувати Always режим з заниженою підсвіткою, чорним фоном та мінімалістичним білим текстом. в альбомному режимі.
/// - Реалізувати можливість вибирати віджети в моніторингу які показувати які приховувати, зьерігаати в налаштуваннях.
///
class MonitoringView extends StatefulWidget {
  const MonitoringView({super.key});

  @override
  State<MonitoringView> createState() => _MonitoringViewState();
}

class _MonitoringViewState extends State<MonitoringView>
    with SingleTickerProviderStateMixin {
  late final MonitoringController _monitoringController;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _monitoringController = Get.put(
      MonitoringController(webSocketProvider: Get.find<WebSocketProvider>()),
    );

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
    if (_isControllerRegistered<MonitoringController>()) {
      Get.delete<MonitoringController>();
    }
    _animationController.dispose();
    super.dispose();
  }

  bool _isControllerRegistered<T>() {
    return Get.isRegistered<T>();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Expanded(
            child: Obx(() {
              final cpuMetrics = _monitoringController.getCurrentCPUMetrics();
              final ramMetrics = _monitoringController.getCurrentRAMMetrics();

              if (cpuMetrics == null || ramMetrics == null) {
                return LoadingView();
              }

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: 1.0,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        !_monitoringController.hasEnoughMetricsData
                            ? MessageBanner(
                              message:
                                  'Зачекайте, відбувається калібрація даних',
                            )
                            : SizedBox.shrink(),
                        MetricsCard(
                          title: 'Температура CPU',
                          value: '${cpuMetrics.temperature}°C',
                          widget: MetricChart(
                            metricsData:
                                _monitoringController.getTemperatures(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        MetricsCard(
                          title: 'Навантаження CPU',
                          value: '${cpuMetrics.loadPercent}%',
                          widget: Column(
                            children: [
                              MetricChart(
                                metricsData:
                                    _monitoringController.getCPULoads(),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  children: [
                                    MetricDetailRow(
                                      label: "Процеси",
                                      value:
                                          _monitoringController
                                              .currentCPUMetrics
                                              .value
                                              ?.processes
                                              .toString() ??
                                          "",
                                    ),
                                    MetricDetailRow(
                                      label: "Нитки",
                                      value:
                                          _monitoringController
                                              .currentCPUMetrics
                                              .value
                                              ?.threads
                                              .toString() ??
                                          "",
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        MetricsCard(
                          title: 'Використання RAM',
                          value:
                              '${ramMetrics.loadPercent}% (${ramMetrics.usage} ГБ)',
                          widget: MetricChart(
                            metricsData:
                                _monitoringController.getRAMUsagesPercent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
