import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/meter.dart';
import '../models/watt_log.dart';
import '../providers/watt_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/theme_colors.dart';
import '../utils/formatters.dart';
import '../widgets/log_item_tile.dart';
import 'widgets/add_log_sheet.dart';

/// Halaman riwayat pencatatan penuh: pencarian & filter per meteran
/// dan per tipe log, dengan pengelompokan per hari.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  int? _meterFilter; // null = semua meteran
  LogType? _typeFilter; // null = semua tipe

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _searchText(WattLog log, Map<int, String> meterNames) {
    final String type = switch (log.logType) {
      LogType.purchase => 'beli pembelian',
      LogType.calibration => 'kalibrasi penyesuaian sisa',
      LogType.initial => 'awal mulai pantau',
    };
    return '$type '
        '${Formatters.kwh(log.kwhPurchased)} '
        '${Formatters.currency(log.amountPaid)} '
        '${Formatters.kwh(log.remainingKwh)} '
        '${Formatters.dateTime(log.timestamp)} '
        '${meterNames[log.meterId] ?? ''} '
        '${log.notes}';
  }

  Future<void> _confirmDelete(BuildContext context, WattLog log) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus Pencatatan?'),
        content: Text(
          'Pencatatan ${Formatters.dateTime(log.timestamp)} akan dihapus permanen.',
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

    if (confirmed != true || !context.mounted) return;
    await context.read<WattProvider>().deleteLog(log.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pencatatan dihapus')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WattProvider>(
      builder: (BuildContext context, WattProvider provider, Widget? _) {
        final Map<int, String> meterNames = <int, String>{
          for (final Meter meter in provider.meters) meter.id ?? 0: meter.name,
        };
        final bool multiMeter = provider.meters.length > 1;

        final List<WattLog> filtered = provider.logs.where((WattLog log) {
          if (_meterFilter != null && log.meterId != _meterFilter) {
            return false;
          }
          if (_typeFilter != null && log.logType != _typeFilter) {
            return false;
          }
          if (_query.isNotEmpty &&
              !_searchText(log, meterNames)
                  .toLowerCase()
                  .contains(_query.toLowerCase())) {
            return false;
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: ThemeColors.background(context),
          appBar: AppBar(
            backgroundColor: ThemeColors.background(context),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 0,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text('Riwayat Pencatatan',
                    style: AppTypography.headingMedium),
                const SizedBox(width: 10),
                Text(
                  '${filtered.length} entri',
                  style: AppTypography.micro(
                    fontSize: 8.5,
                    letterSpacing: 1.1,
                  ).copyWith(color: ThemeColors.textSecondary(context)),
                ),
              ],
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Pencarian
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeColors.surface(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ThemeColors.border(context)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 12),
                      Icon(Icons.search,
                          size: 17,
                          color:
                              ThemeColors.textSecondary(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (String value) =>
                              setState(() => _query = value.trim()),
                          style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Cari pembelian, nominal, tanggal…',
                            border: InputBorder.none,
                            isDense: true,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty) ...<Widget>[
                        IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.cancel, size: 16),
                          iconSize: 16,
                          color:
                              ThemeColors.textSecondary(context),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Bersihkan',
                        ),
                        const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ),
              ),
              // Filter tipe
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _chipRow(
                  context,
                  items: <(String, LogType?)>[
                    ('Semua', null),
                    ('Pembelian', LogType.purchase),
                    ('Kalibrasi', LogType.calibration),
                    ('Awal', LogType.initial),
                  ],
                  selected: _typeFilter,
                  select: (LogType? value) =>
                      setState(() => _typeFilter = value),
                ),
              ),
              // Filter meteran (hanya bila lebih dari satu)
              if (multiMeter)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _chipRow(
                    context,
                    items: <(String, int?)>[
                      ('Semua Meteran', null),
                      for (final Meter meter in provider.meters)
                        (meter.name, meter.id ?? 0),
                    ],
                    selected: _meterFilter,
                    select: (int? value) =>
                        setState(() => _meterFilter = value),
                  ),
                ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              // Daftar hasil
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(context)
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 32),
                        children: _buildSections(context, filtered),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chipRow<T>(BuildContext context, {
    required List<(String, T)> items,
    required T selected,
    required ValueChanged<T> select,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final (String label, T value) in items) ...<Widget>[
            Padding(
              padding: EdgeInsets.only(right: value == items.last.$2 ? 0 : 8),
              child: _FilterChip<T>(
                label: label,
                selected: value == selected,
                onTap: () => select(value),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    List<WattLog> logs,
  ) {
    final Map<String, List<WattLog>> byDay = <String, List<WattLog>>{};
    for (final WattLog log in logs) {
      final DateTime day = DateTime(
        log.timestamp.year,
        log.timestamp.month,
        log.timestamp.day,
      );
      byDay
          .putIfAbsent(day.toIso8601String(), () => <WattLog>[])
          .add(log);
    }

    final List<Widget> sections = <Widget>[];
    for (final MapEntry<String, List<WattLog>> entry in byDay.entries) {
      final List<WattLog> dayLogs = entry.value;
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Text(
            _dayLabel(dayLogs.first.timestamp),
            style: AppTypography.captionBold
                .copyWith(fontSize: 11.5)
                .copyWith(
                  letterSpacing: 0.3,
                  color: ThemeColors.textPrimary(context),
                ),
          ),
        ),
      );
      sections.add(
        _HistoryGroup(
          logs: dayLogs,
          onEdit: (WattLog value) =>
              AddLogSheet.show(context, existingLog: value),
          onDelete: (WattLog value) => _confirmDelete(context, value),
        ),
      );
    }
    return sections;
  }

  String _dayLabel(DateTime day) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Hari Ini';
    if (day == today.subtract(const Duration(days: 1))) return 'Kemarin';
    return Formatters.date(day);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.manage_search,
              size: 28,
              color: ThemeColors.textSecondary(context),
            ),
            const SizedBox(height: 10),
            Text('Tidak ada pencatatan',
                style: AppTypography.headingMedium),
            const SizedBox(height: 6),
            Text(
              _query.isNotEmpty || _typeFilter != null || _meterFilter != null
                  ? 'Coba ubah kata kunci atau filter pencarian.'
                  : 'Belum ada pencatatan untuk ditampilkan.',
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip filter editorial: garis rambut saat non-aktif, terisi penuh saat aktif.
class _FilterChip<T> extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : ThemeColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11.5,
            color: selected
                ? AppColors.primaryForeground
                : ThemeColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

/// Kelompok pencatatan satu hari bergaya leger: garis atas-bawah rambut.
class _HistoryGroup extends StatelessWidget {
  const _HistoryGroup({
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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