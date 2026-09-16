import 'package:flutter_test/flutter_test.dart';
import 'package:wattcast/models/watt_log.dart';
import 'package:wattcast/utils/watt_calculator.dart';

WattLog _log(
  DateTime ts,
  LogType type,
  double remaining, {
  double purchased = 0,
}) =>
    WattLog(
      timestamp: ts,
      logType: type,
      kwhPurchased: purchased,
      remainingKwh: remaining,
      amountPaid: 0,
    );

void main() {
  group('WattCalculator', () {
    test('daysBetween menghitung durasi dalam hari desimal', () {
      final DateTime start = DateTime(2026, 9, 1, 0, 0);
      final DateTime end = DateTime(2026, 9, 3, 12, 0);
      expect(WattCalculator.daysBetween(start, end), closeTo(2.5, 1e-9));
    });

    test('kwhConsumed untuk PURCHASE: (sisa lalu + beli) - sisa sekarang', () {
      final earlier = _log(DateTime(2026, 9, 1), LogType.purchase,
          100, purchased: 0);
      final later = _log(DateTime(2026, 9, 8), LogType.purchase,
          130, purchased: 50);
      expect(WattCalculator.kwhConsumed(earlier, later), 20);
    });

    test('kwhConsumed untuk non-PURCHASE: sisa lalu - sisa sekarang', () {
      final earlier = _log(DateTime(2026, 9, 1), LogType.initial, 100);
      final later = _log(DateTime(2026, 9, 8), LogType.calibration, 90);
      expect(WattCalculator.kwhConsumed(earlier, later), 10);
    });

    test('kwhConsumed tidak pernah negatif saat kalibrasi menaikkan saldo', () {
      final earlier = _log(DateTime(2026, 9, 1), LogType.initial, 100);
      final later = _log(DateTime(2026, 9, 8), LogType.calibration, 120);
      expect(WattCalculator.kwhConsumed(earlier, later), 0);
    });

    test('averageDailyRate merata-ratakan seluruh interval', () {
      final logs = <WattLog>[
        _log(DateTime(2026, 9, 1), LogType.initial, 100),
        _log(DateTime(2026, 9, 6), LogType.purchase, 70, purchased: 0),
        _log(DateTime(2026, 9, 11), LogType.calibration, 40),
      ];
      // Interval 1: 5 hari, pakai 30 kWh -> 6/hari
      // Interval 2: 5 hari, pakai 30 kWh -> 6/hari
      expect(WattCalculator.averageDailyRate(logs), closeTo(6.0, 1e-9));
    });

    test('averageDailyRate menghitung konsumsi tertunda di balik '
        'pembelian bersaldo-derived (telescoping)', () {
      final logs = <WattLog>[
        _log(DateTime(2026, 9, 1), LogType.initial, 100),
        // Beli 5 Sep: saldo derived (after = sisa_lama + token) -> 0 kWh.
        _log(DateTime(2026, 9, 5), LogType.purchase, 220, purchased: 120),
        // Kalibrasi 11 Sep: konsumsi 10 hari muncul seluruhnya di sini.
        _log(DateTime(2026, 9, 11), LogType.calibration, 190),
      ];
      // Ground truth: 100 + 120 - 190 = 30 kWh / 10 hari = 3/hari.
      expect(WattCalculator.averageDailyRate(logs), closeTo(3.0, 1e-9));
    });

    test('averageDailyRate memakai window recent, data basi tak menyeret', () {
      final DateTime base = DateTime(2026, 1, 1);
      final logs = <WattLog>[
        _log(base, LogType.initial, 100),
        // 50 hari pertama: cuma 5 kWh (0,1/hari) — di luar window 45 hari.
        _log(base.add(const Duration(days: 50)), LogType.calibration, 95),
        // 50 hari terakhir: 50 kWh (1/hari).
        _log(base.add(const Duration(days: 100)), LogType.calibration, 45),
      ];
      // Window = 45 hari terakhir -> irisan = 45 hari, konsumsi proporsional
      // 50 * (45/50) = 45 kWh -> 1,0/hari (bukan 0,55 rata-rata penuh).
      expect(WattCalculator.averageDailyRate(logs), closeTo(1.0, 1e-9));
    });

    test('averageDailyRate 0 bila data kurang dari 2', () {
      expect(WattCalculator.averageDailyRate(<WattLog>[]), 0);
      expect(
        WattCalculator.averageDailyRate(<WattLog>[
          _log(DateTime(2026, 9, 1), LogType.initial, 100),
        ]),
        0,
      );
    });

    test('estimatedDaysLeft = sisa / rata-rata harian', () {
      expect(
        WattCalculator.estimatedDaysLeft(remainingKwh: 60, dailyRate: 6),
        10,
      );
      expect(
        WattCalculator.estimatedDaysLeft(remainingKwh: 0, dailyRate: 6),
        0,
      );
      expect(
        WattCalculator.estimatedDaysLeft(remainingKwh: 60, dailyRate: 0),
        isNull,
      );
    });

    test('monthlySummary menghitung pemakaian & pembelian bulanan', () {
      final logs = <WattLog>[
        _log(DateTime(2026, 9, 25, 12), LogType.initial, 100),
        _log(DateTime(2026, 9, 30), LogType.purchase, 60, purchased: 20),
        _log(DateTime(2026, 10, 5), LogType.calibration, 30),
      ];
      final MonthlySummary sept =
          WattCalculator.monthlySummary(logs: logs, year: 2026, month: 9);
      // Interval pertama (25→30 Sep) penuh di September: 60 kWh.
      // Interval kedua (30 Sep→5 Okt) punya 1 dari 5 hari di September: +6.
      expect(sept.kwhConsumed, closeTo(66, 1e-9));
      expect(sept.kwhPurchased, closeTo(20, 1e-9));

      // Sebagian interval (4 dari 5 hari) jatuh di bulan Oktober.
      final MonthlySummary oct =
          WattCalculator.monthlySummary(logs: logs, year: 2026, month: 10);
      expect(oct.kwhConsumed, closeTo(24, 1e-9));
    });
  });
}