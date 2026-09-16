import 'package:flutter/material.dart';

import '../../providers/watt_provider.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/watt_calculator.dart';
import 'monthly_usage_chart.dart';

/// Kartu ringkasan pemakaian bulanan: grafik 6 bulan + panel agregat.
class MonthlyOverview extends StatelessWidget {
  const MonthlyOverview({super.key, required this.provider});

  final WattProvider provider;

  @override
  Widget build(BuildContext context) {
    final List<MonthlySummary> summaries = provider.recentMonthlySummaries(6);
    final MonthlySummary current = summaries.last;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('Pemakaian Bulanan', style: AppTypography.headingMedium),
                const Spacer(),
                Text(
                  '6 BULAN TERAKHIR',
                  style: AppTypography.micro(
                    fontSize: 8.5,
                    letterSpacing: 1.2,
                  ).copyWith(color: ThemeColors.textSecondary(context)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MonthlyUsageChart(summaries: summaries),
            const SizedBox(height: 18),
            _MonthlySummaryPanel(provider: provider, current: current),
          ],
        ),
      ),
    );
  }
}

class _MonthlySummaryPanel extends StatelessWidget {
  const _MonthlySummaryPanel({required this.provider, required this.current});

  final WattProvider provider;
  final MonthlySummary current;

  @override
  Widget build(BuildContext context) {
    final bool hasTariff = provider.hasTariff;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: ThemeColors.soft(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _panelCell(
              context,
              label: 'PEMAKAIAN',
              value: Formatters.kwh(current.kwhConsumed),
              unit: 'kWh',
            ),
          ),
          // _verticalDivider(context),
          // Expanded(
          //   child: _panelCell(
          //     context,
          //     label: 'BIAYA / BLN',
          //     value: Formatters.currency(current.amountPaid),
          //     unit: 'terbayar',
          //   ),
          // ),
          _verticalDivider(context),
          Expanded(
            child: _panelCell(
              context,
              label: 'EST. BIAYA /BLN.',
              value: hasTariff
                  ? Formatters.currency(provider.estimatedMonthlyCost)
                  : '—',
              unit: hasTariff ? '' : 'set tarif',
              muted: !hasTariff,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelCell(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    bool muted = false,
  }) {
    return Column(
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.micro(
            fontSize: 8,
            letterSpacing: 1,
          ).copyWith(color: ThemeColors.textSecondary(context)),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value,
                maxLines: 1,
                style: AppTypography.statValue.copyWith(
                  color: muted
                      ? ThemeColors.textSecondary(context)
                      : ThemeColors.textPrimary(context),
                  fontSize: 16,
                ),
              ),
              if (unit.isNotEmpty) ...<Widget>[
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: AppTypography.micro(fontSize: 8)
                      .copyWith(color: ThemeColors.textSecondary(context)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider(BuildContext context) => Container(
    width: 1,
    height: 30,
    color: ThemeColors.border(context).withValues(alpha: 0.9),
  );
}
