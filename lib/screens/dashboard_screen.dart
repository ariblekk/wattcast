import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiOverlayStyle;
import 'package:provider/provider.dart';

import '../models/watt_log.dart';
import '../providers/watt_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'history_screen.dart';
import 'widgets/add_log_sheet.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/history_section.dart';
import 'widgets/meter_carousel.dart';
import 'widgets/monthly_overview.dart';
import 'widgets/summary_card.dart';

/// Cakram aura radial yang memudar transparan; hiasan murni (tak menerima tap).
Widget _glowBlob(double size, Color color) {
  return IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

/// Layar utama WattCast: masthead tinta, carousel meteran, ringkasan,
/// grafik bulanan, serta daftar riwayat bergaya leger.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();

  static const double _badgeThreshold = 16;

  /// Berapa px bagian bawah carousel yang sengaja "keluar" dari latar
  /// masthead agar terkesan mengambang di atas kartu.
  static const double _mastheadOverflow = 44;

  /// Saat offset scroll melewati tinggi masthead, ikon status bar dibalik
  /// ke gelap (konten terang); di bawahnya tetap terang (di atas slate).
  static const double _statusBarFlipOffset = 280;

  /// `null` = belum pernah diterapkan, agar build pertama selalu menyetel style.
  bool? _statusBarDark;

  void _syncStatusBarStyle(double offset) {
    final bool overMasthead = offset > _statusBarFlipOffset;
    if (overMasthead == _statusBarDark) return;
    _statusBarDark = overMasthead;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          overMasthead ? Brightness.dark : Brightness.light,
      statusBarBrightness:
          overMasthead ? Brightness.light : Brightness.dark,
    ));
  }

  void _openAddSheet(BuildContext context, LogType type) {
    AddLogSheet.show(context, initialType: type);
  }

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
    );
  }

  void _openEditSheet(BuildContext context, WattLog log) {
    AddLogSheet.show(context, existingLog: log);
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
            child: const Text(
              'Hapus',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<WattProvider>().deleteLog(log.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Pencatatan dihapus')));
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Consumer<WattProvider>(
        builder: (BuildContext context, WattProvider provider, _) {
          return Stack(
            children: <Widget>[
              RefreshIndicator(
                onRefresh: provider.loadLogs,
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: bottomInset + 32),
                  children: <Widget>[
                    _MastheadShelter(
                        overflow: _mastheadOverflow,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(height: topInset),
                            const DashboardTitle(),
                            MeterCarousel(
                              onPurchase: _openAddSheet,
                              onCalibration: _openAddSheet,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SummaryCard(
                        provider: provider,
                        onHistoryTap: () => _openHistory(context),
                      ),
                      if (provider.hasData) ...<Widget>[
                        const SizedBox(height: 24),
                        MonthlyOverview(provider: provider),
                      ],
                      const SizedBox(height: 24),
                      HistoryHeader(
                        count: provider.logCount > 6 ? 6 : provider.logCount,
                      ),
                      if (provider.hasData) ...<Widget>[
                        HistoryList(
                          logs: provider.logs.take(6).toList(),
                          onEdit: (WattLog log) => _openEditSheet(context, log),
                          onDelete: (WattLog log) =>
                              _confirmDelete(context, log),
                        ),
                        if (provider.logCount > 6)
                          SeeAllRow(onTap: () => _openHistory(context)),
                      ] else
                        const EmptyState(),
                    ],
                  ),
                ),
                ListenableBuilder(
                  listenable: _scrollController,
                  builder: (BuildContext context, Widget? _) {
                    final double offset = _scrollController.hasClients
                        ? _scrollController.offset
                        : 0;
                    _syncStatusBarStyle(offset);
                    final bool mini =
                        _scrollController.hasClients && offset > _badgeThreshold;
                    return Positioned(
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: DashboardHeader(mini: mini),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
    );
  }
}

/// Latar slate masthead yang lebih pendek dari kontennya sehingga bagian
/// bawah carousel terlihat "keluar" dari latar (konten mengambang).
///
/// ListView memberi tinggi tak terbatas, jadi tinggi konten diukur lewat
/// GlobalKey sekali per layout (addPostFrameCallback) lalu dipakai untuk
/// memotong tinggi latar sebesar [overflow] px.
class _MastheadShelter extends StatefulWidget {
  const _MastheadShelter({required this.overflow, required this.child});

  final double overflow;
  final Widget child;

  @override
  State<_MastheadShelter> createState() => _MastheadShelterState();
}

class _MastheadShelterState extends State<_MastheadShelter> {
  final GlobalKey _contentKey = GlobalKey();
  double _bgHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final RenderObject? renderObject = _contentKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !mounted) return;
    final double height = renderObject.size.height;
    if (height != _bgHeight) setState(() => _bgHeight = height);
  }

  @override
  Widget build(BuildContext context) {
    final double bgHeight = _bgHeight <= 0 ? 0 : _bgHeight - widget.overflow;

    return Stack(
      children: <Widget>[
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: bgHeight,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(28),
            ),
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AppColors.topGradient,
                        stops: <double>[0.0, 0.55, 0.9],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -80,
                  right: -70,
                  child: _glowBlob(280, AppColors.topGlowPrimary),
                ),
              ],
            ),
          ),
        ),
        KeyedSubtree(key: _contentKey, child: widget.child),
      ],
    );
  }
}
