import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MetricChart extends StatelessWidget {
  final List<int> metricsData;

  const MetricChart({required this.metricsData, super.key});

  @override
  Widget build(BuildContext context) {
    return metricsData.length <= 5
        ? SizedBox.shrink()
        : Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: metricsData.length <= 5 ? 0 : 16),
              SizedBox(
                height: metricsData.length <= 5 ? 1 : 100,
                child: LineChart(
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
              SizedBox(height: metricsData.length <= 5 ? 0 : 16),
            ],
          ),
        );
  }
}
