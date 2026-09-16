import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/watt_calculator.dart';

/// Grafik batang konsumsi kWh ([summaries]) gaya editorial: batang rata
/// tanpa latar, garis grid rambut, label bulan kapital mikro.
class MonthlyUsageChart extends StatelessWidget {
  const MonthlyUsageChart({super.key, required this.summaries});

  final List<MonthlySummary> summaries;

  static const List<String> _monthShort = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  String _monthLabel(MonthlySummary summary) =>
      _monthShort[summary.month - 1];

  @override
  Widget build(BuildContext context) {
    final bool isEmpty =
        summaries.every((MonthlySummary s) => s.kwhConsumed <= 0);

    if (isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Text(
          'Belum ada data pemakaian bulanan',
          style: AppTypography.caption
              .copyWith(color: ThemeColors.textSecondary(context)),
        ),
      );
    }

    final double maxY = summaries.fold<double>(
      0,
      (double max, MonthlySummary s) => math.max(max, s.kwhConsumed),
    );
    final double upper = math.max(maxY * 1.18, 1);
    final double interval = _niceInterval(upper / 4);

    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,
          maxY: upper,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (BarChartGroupData group) =>
                  ThemeColors.surface(context),
              getTooltipItem: (
                BarChartGroupData group,
                int groupIndex,
                BarChartRodData rod,
                int rodIndex,
              ) {
                final MonthlySummary summary = summaries[group.x];
                return BarTooltipItem(
                  '${Formatters.kwh(summary.kwhConsumed)} kWh',
                  TextStyle(
                    color: ThemeColors.textPrimary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      value.toStringAsFixed(0),
                      textAlign: TextAlign.right,
                      style: AppTypography.micro(
                        fontSize: 9,
                        letterSpacing: 0.4,
                      ).copyWith(color: ThemeColors.textSecondary(context)),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.toInt();
                  if (index < 0 || index >= summaries.length) {
                    return const SizedBox.shrink();
                  }
                  final MonthlySummary summary = summaries[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthLabel(summary).toUpperCase(),
                      style: AppTypography.micro(
                        fontSize: 9,
                        letterSpacing: 0.8,
                      ).copyWith(color: ThemeColors.textSecondary(context)),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (double value) => FlLine(
              color: ThemeColors.border(context).withValues(alpha: 0.8),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List<BarChartGroupData>.generate(
            summaries.length,
            (int index) {
              final MonthlySummary summary = summaries[index];
              return BarChartGroupData(
                x: index,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: summary.kwhConsumed,
                    width: 13,
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Interval sumbu "rapi" (1/2/5 × 10^n).
  double _niceInterval(double raw) {
    final double mag = math.pow(10, (math.log(raw) / math.ln10).floorToDouble())
        .toDouble();
    final double norm = raw / mag;
    if (norm >= 5) return 5 * mag;
    if (norm >= 2) return 2 * mag;
    return mag;
  }
}