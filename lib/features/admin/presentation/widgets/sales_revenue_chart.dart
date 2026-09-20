import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../domain/entities/admin_sales.dart';

/// Revenue-per-day bar chart for the admin sales dashboard (#12).
///
/// One bar per day of the window — the data layer already zero-fills the
/// timeline, so gaps render as empty bars instead of distorting the
/// axis. Amounts are minor units formatted through [Money] for display.
class SalesRevenueChartCard extends StatelessWidget {
  const SalesRevenueChartCard({super.key, required this.points});

  /// Exactly one point per day, oldest first (see [AdminSalesOverview]).
  final List<AdminRevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.adminRevenueLastDays(points.length),
                style: textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: points.isEmpty
                  ? Center(
                      child: Text(context.l10n.adminNoRevenueData,
                          style: textTheme.bodySmall))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        // A zero-height axis breaks scaling; floor at 1 so
                        // an all-zero window still renders flat bars.
                        maxY: _maxRevenue == 0 ? 1 : _maxRevenue * 1.2,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              // ~5 labels for a 14-day window.
                              interval: points.length <= 5
                                  ? 1
                                  : (points.length / 5).ceilToDouble(),
                              getTitlesWidget: _dayLabel,
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < points.length; i++)
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                toY: points[i].revenueMinor.toDouble(),
                                width: 14,
                                borderRadius: BorderRadius.circular(4),
                                color: scheme.primary,
                              ),
                            ]),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  double get _maxRevenue => points.fold<double>(
      0, (max, p) => p.revenueMinor > max ? p.revenueMinor.toDouble() : max);

  /// Maps a bar-group x index back to a compact `d/m` calendar label.
  Widget _dayLabel(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= points.length) {
      return const SizedBox.shrink();
    }
    final day = points[index].day;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '${day.day}/${day.month}',
        style: const TextStyle(fontSize: 10),
      ),
    );
  }
}
