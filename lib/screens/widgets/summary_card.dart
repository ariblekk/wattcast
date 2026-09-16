import 'package:flutter/material.dart';

import '../../models/watt_log.dart';
import '../../providers/watt_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_colors.dart';
import '../../utils/formatters.dart';

/// Kartu ringkasan yang bisa dikembangkan: versi ringkas menampilkan strip
/// tiga angka kunci (sisa token, estimasi habis, biaya harian); versi
/// diperluas menambah detail tarif, biaya bulanan, dan pembelian terakhir.
class SummaryCard extends StatefulWidget {
  const SummaryCard({
    super.key,
    required this.provider,
    required this.onHistoryTap,
  });

  final WattProvider provider;
  final VoidCallback onHistoryTap;

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  bool _expanded = false;

  Color _estimateColor(BuildContext context, double? days) {
    if (days == null) return ThemeColors.textSecondary(context);
    if (days <= 7) return ThemeColors.danger(context);
    if (days <= 15) return ThemeColors.warning(context);
    return ThemeColors.success(context);
  }

  @override
  Widget build(BuildContext context) {
    final WattProvider provider = widget.provider;
    final bool hasData = provider.hasData;
    final double? daysLeft = provider.estimatedDaysLeft;
    final WattLog? lastPurchase = provider.latestPurchaseLog;

    final Widget strip = _SummaryStrip(provider: provider, daysLeft: daysLeft);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Baris judul + tombol ghost "Lihat Riwayat" + toggle kolapse
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'RINGKASAN',
                  style: AppTypography.micro(
                    fontSize: 9,
                    letterSpacing: 1.3,
                  ).copyWith(color: ThemeColors.textSecondary(context)),
                ),
              ),
              TextButton(
                onPressed: widget.onHistoryTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  overlayColor: AppColors.primary.withValues(alpha: 0.08),
                  textStyle: AppTypography.micro(
                    fontSize: 8.5,
                    letterSpacing: 1.1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('LIHAT RIWAYAT'),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: strip,
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                strip,
                const SizedBox(height: 14),
                _row(
                  context,
                  label: 'Rata-rata pemakaian',
                  value: hasData
                      ? '${Formatters.kwh(provider.averageDailyRate)} kWh/hari'
                      : '—',
                  valueColor: ThemeColors.textPrimary(context),
                ),
                const SizedBox(height: 9),
                if (provider.hasTariff) ...<Widget>[
                  _row(
                    context,
                    label: 'Tarif terpasang',
                    value:
                        '${Formatters.currency(provider.tariffPerKwh!)} / kWh',
                    valueColor: ThemeColors.textPrimary(context),
                  ),
                  const SizedBox(height: 9),
                ],
                _row(
                  context,
                  label: 'Est. biaya / bulan',
                  value: provider.hasTariff
                      ? Formatters.currency(provider.estimatedMonthlyCost)
                      : '—',
                  valueColor: provider.hasTariff
                      ? ThemeColors.textPrimary(context)
                      : ThemeColors.textSecondary(context),
                ),
                if (hasData && daysLeft != null) ...<Widget>[
                  const SizedBox(height: 9),
                  _row(
                    context,
                    label: 'Perkiraan habis',
                    value: '${Formatters.date(provider.estimatedEmptyDate ?? DateTime.now().add(Duration(days: daysLeft.round())))} · ${Formatters.kwh(daysLeft)} hari',
                    valueColor: _estimateColor(context, daysLeft),
                  ),
                ],
                const SizedBox(height: 12),
                _DashedDivider(color: ThemeColors.border(context)),
                const SizedBox(height: 12),
                // Pembelian token terakhir: nominal di bawah teks, tanggal di kanannya
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Pembelian token terakhir',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11.5,
                        color: ThemeColors.textSecondary(context)
                            .withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (lastPurchase == null)
                      Text(
                        'Belum ada',
                        style: AppTypography.captionBold.copyWith(
                          fontSize: 12.5,
                          color: ThemeColors.textPrimary(context),
                        ),
                      )
                    else
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              lastPurchase.amountPaid > 0
                                  ? Formatters.currency(lastPurchase.amountPaid)
                                  : 'Kalibrasi',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.captionBold.copyWith(
                                fontSize: 12.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            Formatters.date(lastPurchase.timestamp),
                            style: AppTypography.caption
                                .copyWith(
                                  fontSize: 10.5,
                                  color: ThemeColors.textSecondary(context),
                                )
                                .copyWith(letterSpacing: 0.3),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              label: Text(_expanded ? 'TUTUP DETAIL' : 'LIHAT DETAIL'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                overlayColor: AppColors.primary.withValues(alpha: 0.08),
                textStyle: AppTypography.micro(
                  fontSize: 9,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 11.5,
              color: ThemeColors.textSecondary(context).withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.captionBold.copyWith(
              fontSize: 12.5,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Strip tiga angka kunci: sisa token, estimasi hari habis, biaya harian.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.provider, required this.daysLeft});

  final WattProvider provider;
  final double? daysLeft;

  @override
  Widget build(BuildContext context) {
    final bool hasData = provider.hasData;
    final bool hasTariff = provider.hasTariff;
    final Color estimateColor = _estimateColor(context, daysLeft);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: ThemeColors.soft(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _cell(
              context,
              label: 'SISA TOKEN',
              value: hasData ? Formatters.kwh(provider.remainingKwh) : '—',
              unit: 'kWh',
            ),
          ),
          _verticalDivider(context),
          Expanded(
            child: _cell(
              context,
              label: 'EST. HABIS',
              value: daysLeft != null ? Formatters.kwh(daysLeft!) : '—',
              unit: 'hari',
              valueColor: estimateColor,
            ),
          ),
          _verticalDivider(context),
          Expanded(
            child: _cell(
              context,
              label: 'BIAYA / HARI',
              value: hasTariff ? Formatters.currency(provider.costPerDay) : '—',
              unit: '',
              muted: !hasTariff,
            ),
          ),
        ],
      ),
    );
  }

  static Color _estimateColor(BuildContext context, double? days) {
    if (days == null) return ThemeColors.textSecondary(context);
    if (days <= 7) return ThemeColors.danger(context);
    if (days <= 15) return ThemeColors.warning(context);
    return ThemeColors.success(context);
  }

  Widget _cell(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    Color? valueColor,
    bool muted = false,
  }) {
    final Color fallback = muted
        ? ThemeColors.textSecondary(context)
        : ThemeColors.textPrimary(context);
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
                  color: valueColor ?? fallback,
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

/// Garis pemisah horisontal putus-putus bergaya editorial.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedDividerPainter(color),
    );
  }
}

class _DashedDividerPainter extends CustomPainter {
  _DashedDividerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    double x = 0;
    const double dash = 4;
    const double gap = 3;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}