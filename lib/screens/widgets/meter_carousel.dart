import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/meter.dart';
import '../../models/watt_log.dart';
import '../../providers/watt_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_colors.dart';
import '../../utils/formatters.dart';
import 'meter_sheets.dart';

/// Bar meteran bergaya carousel: daftar meteran geser horizontal dengan
/// kartu informasi + aksi cepat di dalamnya.
class MeterCarousel extends StatefulWidget {
  const MeterCarousel({
    super.key,
    required this.onPurchase,
    required this.onCalibration,
  });

  final void Function(BuildContext, LogType) onPurchase;
  final void Function(BuildContext, LogType) onCalibration;

  @override
  State<MeterCarousel> createState() => _MeterCarouselState();
}

class _MeterCarouselState extends State<MeterCarousel> {
  final ScrollController _controller = ScrollController();
  int _syncedPage = -1;
  Timer? _realtimeTimer;

  static const double _gutter = 14;

  /// Lebar kartu item carousel: seragam agar tiap kartu menampilkan
  /// "peek" kartu berikutnya secara konsisten.
  double _extentFor(double viewport) => viewport - _gutter;

  /// Offset berhenti (snap) untuk tiap indeks: kartu pertama rata kiri,
  /// kartu terakhir rata kanan, sisanya di tengah.
  double _targetFor(double viewport, int count, int index) {
    final double e = viewport - _gutter;
    if (index <= 0) return 0;
    if (index >= count - 1) return count * e - viewport;
    return index * e - (viewport - e) / 2;
  }

  int _nearestIndex(double offset, double viewport, int count) {
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < count; i++) {
      final double dist = (offset - _targetFor(viewport, count, i)).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best;
  }

  void _selectAt(int index, List<Meter> meters) {
    if (index < 0 || index >= meters.length) return;
    context.read<WattProvider>().selectMeter(meters[index].id!);
  }

  Future<void> _copyNumber(BuildContext context, String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Nomor meter disalin')));
  }

  Future<void> _confirmMeterDelete(BuildContext context, Meter meter) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Hapus ${meter.name}?'),
        content: const Text(
          'Meteran beserta seluruh pencatatannya akan dihapus permanen.',
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
    await context.read<WattProvider>().deleteMeter(meter.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Meteran dihapus')));
  }

  @override
  void initState() {
    super.initState();
    _realtimeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WattProvider provider = context.watch<WattProvider>();
    final List<Meter> meters = provider.meters;
    // Lebar viewport carousel = lebar layar dikurangi padding kiri-kanan 16.
    final double vw = MediaQuery.sizeOf(context).width - 32;
    int page = 0;
    for (int i = 0; i < meters.length; i++) {
      if (meters[i].id == provider.selectedMeterId) {
        page = i;
        break;
      }
    }

    if (page != _syncedPage) {
      _syncedPage = page;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        final double v = MediaQuery.sizeOf(context).width - 32;
        final double target = _targetFor(
          v,
          meters.length,
          page,
        ).clamp(0, _controller.position.maxScrollExtent);
        if ((target - _controller.offset).abs() > 0.5) {
          _controller.jumpTo(target);
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'METERAN',
                style: AppTypography.micro(
                  fontSize: 8.5,
                  letterSpacing: 1.3,
                ).copyWith(color: AppColors.topForegroundMuted),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => MeterFormSheet.show(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.primary,
                ),
                child: Text(
                  'Tambah ID Pelanggan',
                  style: AppTypography.micro(fontSize: 8.5, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 185,
            child: meters.isEmpty
                ? const SizedBox()
                : NotificationListener<ScrollEndNotification>(
                    onNotification: (ScrollEndNotification notification) {
                      if (notification.depth != 0) return false;
                      final double v = notification.metrics.viewportDimension;
                      final int index = _nearestIndex(
                        notification.metrics.pixels,
                        v,
                        meters.length,
                      );
                      if (index != page) _selectAt(index, meters);
                      return false;
                    },
                    child: ListView(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      physics: _SnapCarouselPhysics(
                        itemCount: meters.length,
                        parent: const PageScrollPhysics(),
                      ),
                      children: <Widget>[
                        for (int i = 0; i < meters.length; i++)
                          SizedBox(
                            width: _extentFor(vw),
                            child: Builder(
                              builder: (BuildContext context) {
                                final Meter meter = meters[i];
                                final bool active =
                                    meter.id == provider.selectedMeterId;
                                final WattLog? latest = provider
                                    .latestLogForMeter(meter.id!);
                                return _MeterCarouselCard(
                                  meter: meter,
                                  latestLog: latest,
                                  remainingKwh: active
                                      ? provider.estimatedRemainingKwh
                                      : (latest?.remainingKwh ?? 0),
                                  isEstimated:
                                      active && provider.isRemainingEstimated,
                                  capacityKwh: provider.fillCapacityForMeter(
                                    meter.id!,
                                  ),
                                  tariffKwh: provider.tariffForMeterId(
                                    meter.id!,
                                  ),
                                  canDelete: meters.length > 1,
                                  onCopy: () =>
                                      _copyNumber(context, meter.number),
                                  onSelect: () => _selectAt(i, meters),
                                  onEdit: () => MeterFormSheet.show(
                                    context,
                                    existing: meter,
                                  ),
                                  onDelete: () =>
                                      _confirmMeterDelete(context, meter),
                                  onPurchase: () => widget.onPurchase(
                                    context,
                                    LogType.purchase,
                                  ),
                                  onCalibration: () => widget.onCalibration(
                                    context,
                                    LogType.calibration,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          if (meters.length > 1) ...<Widget>[
            const SizedBox(height: 10),
            _MeterDots(count: meters.length, activeIndex: page),
          ],
        ],
      ),
    );
  }
}

/// Physics carousel deterministik: kartu pertama berhenti rata kiri,
/// kartu terakhir rata kanan, dan kartu tengah di tengah viewport.
class _SnapCarouselPhysics extends ScrollPhysics {
  const _SnapCarouselPhysics({required this.itemCount, super.parent});

  final int itemCount;

  static const double _gutter = 14;

  double _target(double viewport, int index) {
    final double e = viewport - _gutter;
    if (index <= 0) return 0;
    if (index >= itemCount - 1) return itemCount * e - viewport;
    return index * e - (viewport - e) / 2;
  }

  @override
  _SnapCarouselPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapCarouselPhysics(parent: buildParent(ancestor), itemCount: itemCount);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (itemCount <= 1) return null;
    final double max = position.maxScrollExtent;
    final double viewport = position.viewportDimension;

    double best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < itemCount; i++) {
      final double target = _target(viewport, i).clamp(0.0, max);
      final double dist = (position.pixels - target).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = target;
      }
    }

    if (bestDist < 0.5 && velocity.abs() < 200) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      best,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

class _MeterCarouselCard extends StatelessWidget {
  const _MeterCarouselCard({
    required this.meter,
    required this.latestLog,
    required this.remainingKwh,
    required this.isEstimated,
    required this.capacityKwh,
    required this.tariffKwh,
    required this.canDelete,
    required this.onCopy,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onPurchase,
    required this.onCalibration,
  });

  final Meter meter;
  final WattLog? latestLog;
  final double remainingKwh;
  final bool isEstimated;
  final double? capacityKwh;
  final double? tariffKwh;
  final bool canDelete;
  final VoidCallback onCopy;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPurchase;
  final VoidCallback onCalibration;

  @override
  Widget build(BuildContext context) {
    final WattLog? lastPurchase = latestLog;

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Panel soft yang melapisi seluruh konten kartu
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: ThemeColors.soft(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // Baris atas: nama + menu ikon + ring sisa
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            meter.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headingMedium.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _iconAction(
                          context,
                          icon: Icons.edit_outlined,
                          onTap: onEdit,
                        ),
                        if (canDelete) ...<Widget>[
                          const SizedBox(width: 2),
                          _iconAction(
                            context,
                            icon: Icons.delete_outline,
                            color: AppColors.danger,
                            onTap: onDelete,
                          ),
                        ],
                        if (capacityKwh != null &&
                            capacityKwh! > 0) ...<Widget>[
                          const SizedBox(width: 10),
                          _SisaRing(
                            fraction: (remainingKwh / capacityKwh!).clamp(
                              0.0,
                              1.0,
                            ),
                            size: 26,
                          ),
                        ],
                      ],
                    ),
                    // Sisa token + nomor meter
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'SISA TOKEN',
                                style: AppTypography.micro(
                                  fontSize: 8,
                                  letterSpacing: 1.2,
                                ).copyWith(color: AppColors.primary),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: <Widget>[
                                  if (isEstimated)
                                    Text(
                                      '≈',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 12,
                                        color: ThemeColors.textSecondary(
                                          context,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    lastPurchase != null
                                        ? Formatters.kwh(remainingKwh)
                                        : '—',
                                    style: AppTypography.statValue.copyWith(
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'kWh',
                                    style: AppTypography.micro(fontSize: 9)
                                        .copyWith(
                                          color: ThemeColors.textSecondary(
                                            context,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (meter.number.isNotEmpty)
                          InkWell(
                            onTap: onCopy,
                            borderRadius: BorderRadius.circular(7),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: ThemeColors.surface(context),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: ThemeColors.border(context),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'No. ${meter.number}',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10,
                                      color: ThemeColors.textSecondary(context),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 10,
                                    color: ThemeColors.textSecondary(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Pencatatan terakhir
                    Text(
                      lastPurchase != null
                          ? 'Terakhir: ${lastPurchase.isPurchase ? Formatters.currency(lastPurchase.amountPaid) : 'Kalibrasi'} · ${Formatters.date(lastPurchase.timestamp)}'
                          : 'Belum ada pencatatan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10.5,
                        color: ThemeColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Aksi cepat: di dalam kartu, di luar panel soft
            Row(
              children: <Widget>[
                Expanded(
                  child: _cardActionButton(
                    context,
                    label: 'Beli Token',
                    icon: Icons.add,
                    onPressed: onPurchase,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _cardActionButton(
                    context,
                    label: 'Kalibrasi',
                    icon: Icons.tune,
                    onPressed: onCalibration,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: AppColors.primaryForeground),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.captionBold.copyWith(
                    fontSize: 11.5,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconAction(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 16,
          color: color ?? ThemeColors.textSecondary(context),
        ),
      ),
    );
  }
}

/// Cincin kecil penunjuk proporsi sisa token terhadap kapasitas tangki.
class _SisaRing extends StatelessWidget {
  const _SisaRing({required this.fraction, required this.size});

  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SisaRingPainter(
        fraction: fraction,
        trackColor: ThemeColors.border(context),
        arcColor: fraction <= 0.25 ? AppColors.danger : AppColors.primary,
      ),
    );
  }
}

class _SisaRingPainter extends CustomPainter {
  _SisaRingPainter({
    required this.fraction,
    required this.trackColor,
    required this.arcColor,
  });

  final double fraction;
  final Color trackColor;
  final Color arcColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double stroke = 3;
    final Rect rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final Paint track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final Paint arc = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * 3.14159265, false, track);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -3.14159265 / 2,
        2 * 3.14159265 * fraction,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_SisaRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.arcColor != arcColor;
}

class _MeterDots extends StatelessWidget {
  const _MeterDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == activeIndex ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? AppColors.primary
                  : ThemeColors.border(context),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}
