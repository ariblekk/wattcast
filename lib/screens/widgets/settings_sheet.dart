import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meter.dart';
import '../../models/watt_log.dart';
import '../../providers/watt_provider.dart';
import '../../services/backup_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/app_button.dart';

/// Modal bottom sheet berisi pengaturan aplikasi:
/// notifikasi serta cadangan/pemulihan data.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  // ===== Notifikasi =====

  Future<void> _toggleNotifications(bool value) async {
    await context.read<WattProvider>().setNotificationsEnabled(value);
  }

  // ===== Backup =====

  Future<void> _exportJson() async {
    final WattProvider provider = context.read<WattProvider>();
    final List<WattLog> allLogs = await provider.getAllLogsForBackup();
    if (allLogs.isEmpty) {
      _snack('Belum ada data untuk dicadangkan');
      return;
    }
    final Map<int, double> tariffs = await provider.exportTariffs();
    await BackupService.exportJson(
      meters: provider.meters,
      logs: allLogs,
      tariffs: tariffs,
    );
    if (mounted) _snack('Backup JSON berhasil diunduh');
  }

  Future<void> _exportCsv() async {
    final WattProvider provider = context.read<WattProvider>();
    final List<WattLog> allLogs = await provider.getAllLogsForBackup();
    if (allLogs.isEmpty) {
      _snack('Belum ada data untuk dicadangkan');
      return;
    }
    final Map<int, Meter> meterById = <int, Meter>{
      for (final Meter meter in provider.meters)
        if (meter.id != null) meter.id!: meter,
    };
    await BackupService.exportCsv(logs: allLogs, meterById: meterById);
    if (mounted) _snack('Ekspor CSV berhasil diunduh');
  }

  Future<void> _importBackup() async {
    final ImportResult? result = await BackupService.pickJsonBackup();
    if (result == null || !mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Pulihkan dari Backup?'),
        content: Text(
          'Seluruh data saat ini akan diganti dengan ${result.meters.length} '
          'meteran dan ${result.logs.length} pencatatan dari backup.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Pulihkan',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<WattProvider>().restoreFromBackup(result);
    if (!mounted) return;
    _snack('Backup dipulihkan (${result.logs.length} pencatatan)');
  }

  Future<void> _resetData() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus Semua Data?'),
        content: const Text(
          'Semua pencatatan akan dihapus permanen dari perangkat ini.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<WattProvider>().resetAll();
    if (!mounted) return;
    _snack('Seluruh data berhasil dihapus');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ===== UI =====

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: AppTypography.captionBold),
      );

  @override
  Widget build(BuildContext context) {
    final WattProvider provider = context.watch<WattProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: ThemeColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Pengaturan', style: AppTypography.headingMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Notifikasi & data aplikasi.',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ===== Notifikasi =====
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(
              'Notifikasi sisa kWh',
              style: AppTypography.bodyMedium,
            ),
            subtitle: Text(
              kIsWeb
                  ? 'Tidak tersedia di browser'
                  : 'Peringatan saat estimasi sisa ≤ ${WattProvider.lowBalanceThresholdDays} hari',
              style: AppTypography.caption.copyWith(fontSize: 11),
            ),
            value: provider.notificationsEnabled,
            onChanged: kIsWeb ? null : _toggleNotifications,
          ),
          const SizedBox(height: 14),

          // ===== Backup / pemulihan =====
          _sectionTitle('BACKUP & PEMULIHAN'),
          AppButton(
            label: 'Ekspor Backup (JSON)',
            icon: Icons.file_download_outlined,
            variant: AppButtonVariant.outline,
            onPressed: _exportJson,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Ekspor Riwayat (CSV)',
            icon: Icons.table_chart_outlined,
            variant: AppButtonVariant.outline,
            onPressed: _exportCsv,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Impor Backup (JSON)',
            icon: Icons.file_upload_outlined,
            variant: AppButtonVariant.outline,
            onPressed: _importBackup,
          ),
          const SizedBox(height: 24),

          // ===== Lainnya =====
          _sectionTitle('LAINNYA'),
          AppButton(
            label: 'Hapus Semua Data',
            icon: Icons.delete_forever_outlined,
            variant: AppButtonVariant.danger,
            onPressed: _resetData,
          ),
        ],
      ),
    );
  }
}