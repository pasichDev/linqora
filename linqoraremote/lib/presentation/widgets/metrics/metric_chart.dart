import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class MetricChart extends StatelessWidget {
  final List<int> metricsData;

  const MetricChart({required this.metricsData, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: metricsData.length <= 5 ? 100 : 100,
            child:
                metricsData.length <= 5
                    ? Column(
                      children: [
                        LoadingAnimationWidget.stretchedDots(
                          color: Colors.white,
                          size: 70,
                        ),
                        Text(
                          "Зачекайте, замало даних для відображення графіка",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    )
                    : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots:
                                metricsData
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => FlSpot(
                                        e.key.toDouble(),
                                        e.value.toDouble(),
                                      ),
                                    )
                                    .toList(),
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
