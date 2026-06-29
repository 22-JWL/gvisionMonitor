import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class YieldGaugeCard extends StatelessWidget {
  final double yieldRate;    // 0.0 ~ 100.0
  final int total;
  final int good;
  final int reject;
  final int noDevice;

  const YieldGaugeCard({
    super.key,
    required this.yieldRate,
    required this.total,
    required this.good,
    required this.reject,
    required this.noDevice,
  });

  Color get _color => yieldRate >= 99
      ? const Color(0xFF43A047)
      : yieldRate >= 95
          ? const Color(0xFFFB8C00)
          : const Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final ng = total - good - noDevice;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 도넛 게이지
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 0,
                      centerSpaceRadius: 34,
                      sections: total == 0
                          ? [PieChartSectionData(value: 1, color: Colors.white12, radius: 12, showTitle: false)]
                          : [
                              PieChartSectionData(
                                value: good.toDouble(),
                                color: const Color(0xFF43A047),
                                radius: 12,
                                showTitle: false,
                              ),
                              if (ng > 0)
                                PieChartSectionData(
                                  value: ng.toDouble(),
                                  color: const Color(0xFFE53935),
                                  radius: 12,
                                  showTitle: false,
                                ),
                              if (noDevice > 0)
                                PieChartSectionData(
                                  value: noDevice.toDouble(),
                                  color: Colors.grey,
                                  radius: 12,
                                  showTitle: false,
                                ),
                            ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${yieldRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _color,
                        ),
                      ),
                      const Text('YIELD', style: TextStyle(fontSize: 9, color: Colors.white54)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // 숫자 요약
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('TOTAL',     '$total',    Colors.white70),
                  _row('GOOD',      '$good',     const Color(0xFF43A047)),
                  _row('REJECT',    '$ng',       ng > 0 ? const Color(0xFFE53935) : Colors.white38),
                  _row('NO DEVICE', '$noDevice', Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ),
            Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      );
}
