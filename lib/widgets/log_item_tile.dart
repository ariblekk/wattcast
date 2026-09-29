import 'package:flutter/material.dart';

import '../models/watt_log.dart';
import '../theme/app_typography.dart';
import '../theme/theme_colors.dart';
import '../utils/formatters.dart';
import 'log_type_badge.dart';

/// Baris daftar riwayat bergaya editorial: tanpa kotak per-item,
/// dipisahkan garis rambut oleh parent-nya. Angka sisa memakai tabular.
class LogItemTile extends StatelessWidget {
  const LogItemTile({
    super.key,
    required this.log,
    this.onTap,
    this.onDelete,
    this.showDelete = true,
    this.previousRemaining,
  });

  final WattLog log;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDelete;

  /// Sisa kWh pencatatan sebelumnya (meter yang sama), untuk menampilkan
  /// transisi `sebelum → sesudah` pada log kalibrasi.
  final double? previousRemaining;

  Color _accent(BuildContext context) {
    switch (log.logType) {
      case LogType.purchase:
        return ThemeColors.success(context);
      case LogType.calibration:
        return ThemeColors.warning(context);
      case LogType.initial:
        return ThemeColors.accent(context);
    }
  }

  String get _detail {
    switch (log.logType) {
      case LogType.purchase:
        if (log.amountPaid > 0) {
          return 'Beli ${Formatters.kwh(log.kwhPurchased)} kWh · '
              '${Formatters.currency(log.amountPaid)}';
        }
        return 'Beli ${Formatters.kwh(log.kwhPurchased)} kWh';
      case LogType.calibration:
        if (log.notes.isNotEmpty) return log.notes;
        return 'Penyesuaian sisa token';
      case LogType.initial:
        return 'Mulai pemantauan token';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _accent(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Kelompok info utama
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LogTypeBadge(type: log.logType),
                  const SizedBox(height: 6),
                  Text(
                    _detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: ThemeColors.textPrimary(context),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    Formatters.dateTime(log.timestamp),
                    style: AppTypography.caption
                        .copyWith(
                          color: ThemeColors.textSecondary(context),
                          fontSize: 10.5,
                        )
                        .copyWith(letterSpacing: 0.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Sisa token
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (previousRemaining != null &&
                    log.logType != LogType.initial) ...<Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          Formatters.kwh(previousRemaining!),
                          style: AppTypography.captionBold.copyWith(
                            fontSize: 11.5,
                            color: ThemeColors.textSecondary(context),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Text(
                            '→',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              color: ThemeColors.textSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Text(
                  Formatters.kwh(log.remainingKwh),
                  style: AppTypography.statValue.copyWith(
                    color: accent,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'kWh sisa',
                  style: AppTypography.micro(fontSize: 8, letterSpacing: 0.8)
                      .copyWith(color: ThemeColors.textSecondary(context)),
                ),
              ],
            ),
            if (showDelete && onDelete != null) ...<Widget>[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.close, size: 16),
                color: ThemeColors.textSecondary(context).withValues(alpha: 0.55),
                visualDensity: VisualDensity.compact,
                tooltip: 'Hapus pencatatan',
              ),
            ],
          ],
        ),
      ),
    );
  }
}