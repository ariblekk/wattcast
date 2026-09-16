import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/meter.dart';
import '../models/watt_log.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../utils/watt_calculator.dart';

/// State management pusat: daftar meteran, pengaturan, dan riwayat log.
///
/// Mendukung **banyak meteran** — seluruh log, tarif, dan flag notifikasi
/// dicakup per meteran; mode tema & status notifikasi bersifat global.
/// Data dibaca/ditulis ke SQLite via [DatabaseHelper].
class WattProvider extends ChangeNotifier {
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keySelectedMeter = 'selected_meter_id';
  static const String _keyDefaultDecay = 'default_daily_decay_percent';

  static String _tariffKey(int meterId) => 'tariff_per_kwh_$meterId';
  static String _lowNotifiedKey(int meterId) => 'low_balance_notified_$meterId';

  /// Ambang daya tahan (hari) untuk memicu notifikasi sisa kWh menipis.
  static const double lowBalanceThresholdDays = 7;

  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Meter> _meters = <Meter>[];
  int? _selectedMeterId;
  List<WattLog> _logs = <WattLog>[];
  final Map<int, WattLog?> _latestLogByMeter = <int, WattLog?>{};
  final Map<int, double> _tariffByMeter = <int, double>{};
  final Map<int, double> _capacityByMeter = <int, double>{};
  bool _isLoading = true;

  double? _tariffPerKwh;
  bool _notificationsEnabled = false;
  double _defaultDecayPercent = 10;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _loadMeters();
    await _loadUiSettings();

    _tariffPerKwh = await _loadTariffFor(_selectedMeterId!);
    _logs = await _db.getAllLogs(meterId: _selectedMeterId);
    _sortLogs();
    _refreshSelectedMeterCapacity();

    _isLoading = false;
    notifyListeners();
    await _maybeNotifyLowBalance();
  }

  // ===== Meteran =====

  List<Meter> get meters => List<Meter>.unmodifiable(_meters);

  int? get selectedMeterId => _selectedMeterId;

  Meter? get selectedMeter {
    for (final Meter meter in _meters) {
      if (meter.id == _selectedMeterId) return meter;
    }
    return _meters.isEmpty ? null : _meters.first;
  }

  Future<void> _loadMeters() async {
    _meters = await _db.getAllMeters();

    if (_meters.isEmpty) {
      final int id = await _db.insertMeter(
        Meter(name: 'Meteran Utama', createdAt: DateTime.now()),
      );
      _meters = await _db.getAllMeters();
      _selectedMeterId = id;
    }

    _latestLogByMeter.clear();
    _tariffByMeter.clear();
    _capacityByMeter.clear();
    for (final Meter meter in _meters) {
      _latestLogByMeter[meter.id!] =
          await _db.getLatestLog(meterId: meter.id);
      final double? tariff = await _loadTariffFor(meter.id!);
      if (tariff != null) _tariffByMeter[meter.id!] = tariff;
    }

    final String? saved = await _db.getSetting(_keySelectedMeter);
    final int? savedId = saved == null ? null : int.tryParse(saved);
    final bool exists =
        savedId != null && _meters.any((Meter m) => m.id == savedId);
    _selectedMeterId = exists ? savedId : _meters.first.id;
  }

  WattLog? latestLogForMeter(int meterId) => _latestLogByMeter[meterId];

  double? tariffForMeterId(int meterId) => _tariffByMeter[meterId];

  /// Kapasitas "tangki": sisa kWh tepat setelah pembelian terakhir.
  /// Hanya dihitung untuk meteran yang terpilih (log-nya termuat).
  double? fillCapacityForMeter(int meterId) => _capacityByMeter[meterId];

  void _refreshSelectedMeterCapacity() {
    final int id = _selectedMeterId!;
    double? capacity;
    for (final WattLog log in _logs) {
      if (log.isPurchase && log.remainingKwh > 0) {
        capacity = log.remainingKwh;
        break;
      }
    }
    if (capacity == null) {
      _capacityByMeter.remove(id);
    } else {
      _capacityByMeter[id] = capacity;
    }
  }

  Future<Meter> addMeter({required String name, String number = ''}) async {
    final Meter meter = Meter(
      name: name,
      number: number,
      createdAt: DateTime.now(),
    );
    final int id = await _db.insertMeter(meter);
    final Meter saved = meter.copyWith(id: id);
    _meters.add(saved);
    await _selectMeterById(id);
    return saved;
  }

  Future<void> updateMeter(Meter meter) async {
    await _db.updateMeter(meter);
    for (int i = 0; i < _meters.length; i++) {
      if (_meters[i].id == meter.id) {
        _meters[i] = meter;
        break;
      }
    }
    notifyListeners();
  }

  /// Menghapus meteran beserta seluruh log-nya.
  Future<void> deleteMeter(int id) async {
    if (_meters.length <= 1) return;

    await _db.deleteLogsForMeter(id);
    await _db.deleteMeter(id);
    _meters.removeWhere((Meter m) => m.id == id);
    _tariffByMeter.remove(id);
    _capacityByMeter.remove(id);

    if (_selectedMeterId == id) {
      _selectedMeterId = _meters.first.id;
      await _db.setSetting(_keySelectedMeter, _selectedMeterId.toString());
      _tariffPerKwh = await _loadTariffFor(_selectedMeterId!);
      _logs = await _db.getAllLogs(meterId: _selectedMeterId);
      _sortLogs();
      _refreshSelectedMeterCapacity();
    }
    notifyListeners();
    await _maybeNotifyLowBalance();
  }

  Future<void> selectMeter(int id) async {
    if (id == _selectedMeterId) return;
    await _selectMeterById(id);
  }

  Future<void> _selectMeterById(int id) async {
    if (!_meters.any((Meter m) => m.id == id)) return;
    _selectedMeterId = id;
    await _db.setSetting(_keySelectedMeter, id.toString());

    _tariffPerKwh = await _loadTariffFor(id);
    if (_tariffPerKwh != null) {
      _tariffByMeter[id] = _tariffPerKwh!;
    } else {
      _tariffByMeter.remove(id);
    }
    _logs = await _db.getAllLogs(meterId: id);
    _sortLogs();
    _refreshSelectedMeterCapacity();

    notifyListeners();
    await _maybeNotifyLowBalance();
  }

  // ===== Data mentah (meteran terpilih) =====

  /// Log ortur dari yang paling baru (indeks 0) ke terlama.
  List<WattLog> get logs => List<WattLog>.unmodifiable(_logs);

  bool get isLoading => _isLoading;
  int get logCount => _logs.length;

  /// Log pencatatan terakhir, atau `null` bila belum ada data.
  WattLog? get latestLog => _logs.isEmpty ? null : _logs.first;

  WattLog? _findLogById(int id) {
    for (final WattLog l in _logs) {
      if (l.id == id) return l;
    }
    return null;
  }

  void _sortLogs() {
    _logs.sort((WattLog a, WattLog b) => b.timestamp.compareTo(a.timestamp));
  }

  // ===== Statistik turunan =====

  /// Sisa kWh token terakhir.
  double get remainingKwh => latestLog?.remainingKwh ?? 0;

  /// Hari yang berlalu sejak pencatatan terakhir (desimal).
  double get daysSinceLastLog {
    final WattLog? latest = latestLog;
    if (latest == null) return 0;
    final double days =
        DateTime.now().difference(latest.timestamp).inMinutes / (60 * 24);
    return days > 0 ? days : 0;
  }

  /// Estimasi sisa kWh hari ini: sisa tercatat dikurangi pemakaian harian
  /// (dari interval antar-log) dikali hari yang berlalu. Bila data belum
  /// cukup (0–1 log), memakai penurunan persen default per hari.
  double get estimatedRemainingKwh {
    final WattLog? latest = latestLog;
    if (latest == null) return 0;
    final double days = daysSinceLastLog;
    if (days <= 0) return remainingKwh;

    double rate;
    if (_logs.length >= 2) {
      rate = averageDailyRate;
    } else {
      rate = latest.remainingKwh * (_defaultDecayPercent / 100);
    }

    final double estimated = latest.remainingKwh - rate * days;
    return estimated < 0 ? 0 : estimated;
  }

  /// `true` bila sisa kWh yang ditampilkan merupakan estimasi
  /// (bukan nilai tersimpan dari pencatatan terakhir).
  bool get isRemainingEstimated {
    final WattLog? latest = latestLog;
    if (latest == null) return false;
    return DateTime.now().isAfter(latest.timestamp);
  }

  /// Total kWh token yang pernah dibeli.
  double get totalKwhPurchased {
    double total = 0;
    for (final WattLog log in _logs) {
      total += log.kwhPurchased;
    }
    return total;
  }

  /// Total nominal rupiah yang pernah dibayarkan.
  double get totalAmountPaid {
    double total = 0;
    for (final WattLog log in _logs) {
      total += log.amountPaid;
    }
    return total;
  }

  /// Rata-rata pemakaian kWh per hari (ground-truth telescoping, window
  /// [WattCalculator.rateWindowDays] hari terakhir).
  double get averageDailyRate => WattCalculator.averageDailyRate(_logs);

  double? get estimatedDaysLeft => WattCalculator.estimatedDaysLeft(
        remainingKwh: estimatedRemainingKwh,
        dailyRate: averageDailyRate,
      );

  DateTime? get estimatedEmptyDate {
    final WattLog? latest = latestLog;
    if (latest == null) return null;
    return WattCalculator.estimatedEmptyDate(
      latestLog: latest,
      daysLeft: estimatedDaysLeft,
    );
  }

  /// Ringkasan pemakaian bulan berjalan.
  MonthlySummary get currentMonthSummary {
    final DateTime now = DateTime.now();
    return WattCalculator.monthlySummary(
      logs: _logs,
      year: now.year,
      month: now.month,
    );
  }

  /// Ringkasan [count] bulan terakhir (termasuk bulan berjalan),
  /// urut lama dulu — index terakhir = bulan berjalan.
  List<MonthlySummary> recentMonthlySummaries(int count) {
    final DateTime now = DateTime.now();
    return List<MonthlySummary>.generate(count, (int index) {
      final DateTime month =
          DateTime(now.year, now.month - (count - 1 - index), 1);
      return WattCalculator.monthlySummary(
        logs: _logs,
        year: month.year,
        month: month.month,
      );
    });
  }

  bool get hasData => _logs.isNotEmpty;

  /// Log pembelian token terakhir (nilai), atau `null` bila belum pernah.
  WattLog? get latestPurchaseLog {
    for (final WattLog log in _logs) {
      if (log.isPurchase) return log;
    }
    return null;
  }

  // ===== Pengaturan =====

  double? get tariffPerKwh => _tariffPerKwh;
  bool get hasTariff => _tariffPerKwh != null && _tariffPerKwh! > 0;
  bool get notificationsEnabled => _notificationsEnabled;

  double get costPerDay => hasTariff ? averageDailyRate * _tariffPerKwh! : 0;
  double get estimatedMonthlyCost => costPerDay * 30;

  Future<void> _loadUiSettings() async {
    _notificationsEnabled = await _db.getSetting(_keyNotifications) == 'true';
    _defaultDecayPercent = double.tryParse(
          await _db.getSetting(_keyDefaultDecay) ?? '',
        ) ??
        10;
  }

  Future<double?> _loadTariffFor(int meterId) async {
    final String? raw = await _db.getSetting(_tariffKey(meterId));
    if (raw == null || raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  /// Menyimpan tarif per kWh untuk meteran tertentu.
  Future<void> setTariffForMeter(int meterId, double? value) async {
    if (value == null) {
      _tariffByMeter.remove(meterId);
      if (meterId == _selectedMeterId) _tariffPerKwh = null;
    } else {
      _tariffByMeter[meterId] = value;
      if (meterId == _selectedMeterId) _tariffPerKwh = value;
    }
    await _db.setSetting(_tariffKey(meterId), value?.toString() ?? '');
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    await _db.setSetting(_keyNotifications, enabled.toString());
    notifyListeners();
    if (enabled) await _maybeNotifyLowBalance();
  }

  // ===== Notifikasi sisa menipis =====

  /// Menentukan tarif dari pembelian terakhir: nominal ÷ kWh terisi.
  /// Hanya berlaku untuk log PURCHASE dengan data lengkap.
  Future<void> _applyAutoTariff(WattLog log) async {
    if (!log.isPurchase || log.kwhPurchased <= 0 || log.amountPaid <= 0) return;
    final int meterId = _selectedMeterId!;
    final double tariff = log.amountPaid / log.kwhPurchased;
    _tariffPerKwh = double.parse(tariff.toStringAsFixed(1));
    _tariffByMeter[meterId] = _tariffPerKwh!;
    await _db.setSetting(_tariffKey(meterId), _tariffPerKwh!.toString());
  }

  Future<void> _maybeNotifyLowBalance() async {
    if (!_notificationsEnabled) return;

    for (final Meter meter in _meters) {
      final int meterId = meter.id!;
      final List<WattLog> logs = await _db.getAllLogs(meterId: meterId);
      if (logs.isEmpty) continue;
      logs.sort((WattLog a, WattLog b) => b.timestamp.compareTo(a.timestamp));

      final WattLog latest = logs.first;
      final double remaining = latest.remainingKwh;
      final double days =
          DateTime.now().difference(latest.timestamp).inMinutes / (60 * 24);

      double estimated = remaining;
      if (days > 0) {
        final double rate = logs.length >= 2
            ? WattCalculator.averageDailyRate(logs)
            : remaining * (_defaultDecayPercent / 100);
        estimated = remaining - rate * days;
        if (estimated < 0) estimated = 0;
      }

      final double dailyRate = WattCalculator.averageDailyRate(logs);
      final double? daysLeft = WattCalculator.estimatedDaysLeft(
        remainingKwh: estimated,
        dailyRate: dailyRate,
      );

      if (daysLeft == null || daysLeft > lowBalanceThresholdDays) {
        await _db.setSetting(_lowNotifiedKey(meterId), '');
        continue;
      }
      if (await _db.getSetting(_lowNotifiedKey(meterId)) == 'true') continue;

      await _db.setSetting(_lowNotifiedKey(meterId), 'true');
      await NotificationService.instance.showLowBalanceNotification(
        meterId: meterId,
        meterName: meter.name,
        remainingKwh: estimated,
        daysLeft: daysLeft,
      );
    }
  }

  // ===== Operasi CRUD log =====

  Future<void> loadLogs() async {
    _isLoading = true;
    notifyListeners();

    _logs = await _db.getAllLogs(meterId: _selectedMeterId);
    _sortLogs();
    _refreshSelectedMeterCapacity();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addLog(WattLog log) async {
    final int meterId = _selectedMeterId!;
    final int id = await _db.insertLog(log.copyWith(meterId: meterId));
    _logs.add(log.copyWith(id: id, meterId: meterId));
    _sortLogs();
    _latestLogByMeter[meterId] = _logs.first;
    await _applyAutoTariff(log);
    _refreshSelectedMeterCapacity();
    notifyListeners();
    await _maybeNotifyLowBalance();
  }

  Future<void> updateLog(WattLog log) async {
    await _db.updateLog(log);
    final int index = _logs.indexWhere((WattLog item) => item.id == log.id);
    if (index >= 0) {
      _logs[index] = log;
      _sortLogs();
      _latestLogByMeter[log.meterId] =
          await _db.getLatestLog(meterId: log.meterId);
      await _applyAutoTariff(log);
      _refreshSelectedMeterCapacity();
      notifyListeners();
      await _maybeNotifyLowBalance();
    }
  }

  Future<void> deleteLog(int id) async {
    final WattLog? target = _findLogById(id);
    await _db.deleteLog(id);
    _logs.removeWhere((WattLog item) => item.id == id);
    if (target != null) {
      _latestLogByMeter[target.meterId] =
          await _db.getLatestLog(meterId: target.meterId);
    }
    _refreshSelectedMeterCapacity();
    notifyListeners();
    await _maybeNotifyLowBalance();
  }

  // ===== Backup / reset =====

  /// Mengganti seluruh data (meteran + log) dengan hasil restore backup.
  Future<void> restoreFromBackup(ImportResult result) async {
    // Bersihkan meteran & log yang ada.
    for (final Meter meter in List<Meter>.of(_meters)) {
      await _db.deleteLogsForMeter(meter.id!);
      await _db.deleteMeter(meter.id!);
    }
    _meters = <Meter>[];
    _logs = <WattLog>[];

    // Bangun ulang meteran, catat pemetaan id lama → id baru.
    final Map<int, int> idMap = <int, int>{};
    for (final Meter meter in result.meters) {
      final int newId = await _db.insertMeter(meter.copyWith(id: null));
      idMap[meter.id ?? -1] = newId;
      _meters.add(meter.copyWith(id: newId));
    }
    int? firstNewId;
    if (_meters.isEmpty) {
      final Meter fallback = Meter(
        name: 'Meteran Utama',
        createdAt: DateTime.now(),
      );
      final int newId = await _db.insertMeter(fallback);
      _meters.add(fallback.copyWith(id: newId));
      firstNewId = newId;
    } else {
      firstNewId = _meters.first.id;
    }

    for (final WattLog log in result.logs) {
      final int meterId = idMap[log.meterId] ?? firstNewId!;
      await _db.insertLog(log.copyWith(id: null, meterId: meterId));
    }

    _selectedMeterId = firstNewId;
    await _db.setSetting(_keySelectedMeter, firstNewId.toString());

    for (final MapEntry<int, double> entry in result.tariffs.entries) {
      final int? target = idMap[entry.key];
      if (target == null) continue;
      await _db.setSetting(_tariffKey(target), entry.value.toString());
      _tariffByMeter[target] = entry.value;
    }

    _tariffPerKwh = await _loadTariffFor(_selectedMeterId!);
    await _db.setSetting(_lowNotifiedKey(_selectedMeterId!), '');
    _logs = await _db.getAllLogs(meterId: _selectedMeterId);
    _sortLogs();
    _refreshSelectedMeterCapacity();

    notifyListeners();
    await _maybeNotifyLowBalance();
  }

  /// Seluruh log lintas meteran (untuk keperluan backup).
  Future<List<WattLog>> getAllLogsForBackup() => _db.getAllLogs();

  /// Tarif per meteran (untuk keperluan backup).
  Future<Map<int, double>> exportTariffs() async {
    final Map<int, double> out = <int, double>{};
    for (final Meter meter in _meters) {
      final double? value = await _loadTariffFor(meter.id!);
      if (value != null) out[meter.id!] = value;
    }
    return out;
  }

  Future<void> resetAll() async {
    await _db.clearAll();
    _logs = <WattLog>[];
    if (_selectedMeterId != null) {
      await _db.setSetting(_lowNotifiedKey(_selectedMeterId!), '');
    }
    notifyListeners();
  }
}