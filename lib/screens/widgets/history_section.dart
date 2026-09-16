import 'package:flutter/material.dart';

import '../../models/watt_log.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/log_item_tile.dart';
import 'add_log_sheet.dart';

/// Judul daftar riwayat pencatatan di halaman utama.
class HistoryHeader extends StatelessWidget {
  const HistoryHeader({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text('Riwayat Pencatatan', style: AppTypography.headingMedium),
          const SizedBox(width: 10),
          Text(
            '$count entri terbaru',
            style: AppTypography.micro(
              fontSize: 8.5,
              letterSpacing: 1.1,
            ).copyWith(color: ThemeColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}

/// Daftar riwayat pencatatan di halaman utama.
class HistoryList extends StatelessWidget {
  const HistoryList({
    super.key,
    required this.logs,
    required this.onEdit,
    required this.onDelete,
  });

  final List<WattLog> logs;
  final void Function(WattLog log) onEdit;
  final void Function(WattLog log) onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: ThemeColors.border(context)),
            bottom: BorderSide(color: ThemeColors.border(context)),
          ),
        ),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < logs.length; i++) ...<Widget>[
              if (i > 0) const Divider(height: 1),
              LogItemTile(
                log: logs[i],
                onTap: () => onEdit(logs[i]),
                onDelete: () => onDelete(logs[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Deretan penutup daftar riwayat halaman utama: akses ke keseluruhan riwayat.
class SeeAllRow extends StatelessWidget {
  const SeeAllRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: ThemeColors.border(context)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Lihat semua riwayat',
                style: AppTypography.caption.copyWith(
                  fontSize: 11.5,
                  color: AppColors.primary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tampilan kosong saat belum ada pencatatan.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'Mulai Dengan Satu Pencatatan',
            style: AppTypography.headingMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Catat pembelian atau kalibrasi token pertamamu '
            'untuk mulai memantau pemakaian.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            child: AppButton(
              label: 'Mulai Pencatatan',
              icon: Icons.edit_note,
              variant: AppButtonVariant.secondary,
              onPressed: () =>
                  AddLogSheet.show(context, initialType: LogType.initial),
            ),
          ),
        ],
      ),
    );
  }
}
