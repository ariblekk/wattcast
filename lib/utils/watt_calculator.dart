import '../models/watt_log.dart';

/// Ringkasan agregat pemakaian pada satu bulan kalender.
class MonthlySummary {
  const MonthlySummary({
    required this.year,
    required this.month,
    required this.kwhConsumed,
    required this.kwhPurchased,
    required this.amountPaid,
  });

  final int year;
  final int month;

  /// kWh yang benar-benar terpakai pada bulan tersebut
  /// (porsi interval dihitung proporsional terhadap durasi).
  final double kwhConsumed;

  /// Total kWh token yang dibeli pada bulan tersebut.
  final double kwhPurchased;

  /// Total nominal rupiah yang dibayarkan pada bulan tersebut.
  final double amountPaid;
}

/// Hasil kalkulasi satu interval di antara dua pencatatan berurutan.
class IntervalStats {
  const IntervalStats({
    required this.days,
    required this.kwhUsed,
    required this.dailyRate,
  });

  /// Durasi antar-pencatatan dalam hari (desimal).
  final double days;

  /// Pemakaian kWh pada interval tersebut.
  final double kwhUsed;

  /// Rata-rata pemakaian kWh/hari pada interval tersebut.
  final double dailyRate;
}

/// Mesin perhitungan presisi pemakaian & prediksi token listrik.
///
/// Seluruh fungsi bersifat murni (pure function) sehingga mudah diuji.
class WattCalculator {
  WattCalculator._();

  /// Durasi antara dua waktu dalam hari desimal.
  /// `(inMinutes / (60 * 24))` sesuai spesifikasi.
  static double daysBetween(DateTime earlier, DateTime later) {
    if (!later.isAfter(earlier)) return 0;
    return later.difference(earlier).inMinutes / (60 * 24);
  }

  /// Pemakaian kWh antara dua pencatatan berurutan:
  /// `(Sisa kWh Lalu + kWh Beli) - Sisa kWh Sekarang`.
  ///
  /// Untuk tipe non-PURCHASE, `kwh_purchased = 0` sehingga rumus
  /// menyusut menjadi `Sisa Lalu - Sisa Sekarang`.
  /// Hasil negatif (misal saat kalibrasi menaikkan saldo) dibulatkan ke 0.
  static double kwhConsumed(WattLog earlier, WattLog later) {
    final double used =
        (earlier.remainingKwh + later.kwhPurchased) - later.remainingKwh;
    return used < 0 ? 0 : used;
  }

  /// Statistik satu interval antara dua log berurutan.
  static IntervalStats intervalStats(WattLog earlier, WattLog later) {
    final double days = daysBetween(earlier.timestamp, later.timestamp);
    final double used = kwhConsumed(earlier, later);
    return IntervalStats(
      days: days,
      kwhUsed: used,
      dailyRate: days <= 0 ? 0 : used / days,
    );
  }

  /// Menghitung seluruh interval dari daftar log yang sudah urut menaik.
  static List<IntervalStats> allIntervals(List<WattLog> logsAscending) {
    final List<IntervalStats> intervals = <IntervalStats>[];
    for (int i = 1; i < logsAscending.length; i++) {
      intervals.add(intervalStats(logsAscending[i - 1], logsAscending[i]));
    }
    return intervals;
  }

  /// Rata-rata pemakaian kWh/hari (0 jika data < 2).
  ///
  /// Menggunakan **ground-truth telescoping** dalam **window rolling**:
  /// total pemakaian dihitung dari rantai saldo
  /// (`sisa_awal + Σ kWh_beli − sisa_akhir`), sehingga interval yang
  /// berakhir di pembelian bersaldo-derived (terhitung 0 kWh) tidak
  /// men-dilusi rata-rata — konsumsinya tetap muncul di snapshot berikutnya.
  ///
  /// Hanya [rateWindowDays] terakhir yang dihitung (proporsional per
  /// overlap-interval, gaya [monthlySummary]) supaya pola pemakaian terkini
  /// lebih berpengaruh daripada data basi yang jauh lebih lama.
  static const int rateWindowDays = 45;

  static double averageDailyRate(List<WattLog> logs) {
    if (logs.length < 2) return 0;

    final List<WattLog> ascending = _sortAscending(logs);
    final DateTime windowStart = ascending.last.timestamp
        .subtract(const Duration(days: rateWindowDays));

    double used = 0;
    double days = 0;
    for (int i = 1; i < ascending.length; i++) {
      final WattLog earlier = ascending[i - 1];
      final WattLog later = ascending[i];

      final double intervalDays =
          daysBetween(earlier.timestamp, later.timestamp);
      if (intervalDays <= 0) continue;

      // Overlap interval dengan window recent (start tidak sebelum
      // jendela, end selalu <= log terakhir).
      final DateTime overlapStart = earlier.timestamp.isAfter(windowStart)
          ? earlier.timestamp
          : windowStart;
      final double overlapDays =
          daysBetween(overlapStart, later.timestamp);
      if (overlapDays <= 0) continue;

      used += kwhConsumed(earlier, later) * (overlapDays / intervalDays);
      days += overlapDays;
    }

    if (days <= 0) return 0;
    return used / days;
  }

  /// Ringkasan pemakaian satu bulan kalender (tahun & bulan 1-12).
  ///
  /// Pemakaian lintas-bulan dialokasikan secara proporsional terhadap
  /// porsi durasi interval yang jatuh di dalam bulan tersebut.
  static MonthlySummary monthlySummary({
    required List<WattLog> logs,
    required int year,
    required int month,
  }) {
    final List<WattLog> ascending = _sortAscending(logs);

    double purchased = 0;
    double paid = 0;
    for (final WattLog log in ascending) {
      if (log.timestamp.year == year && log.timestamp.month == month) {
        purchased += log.kwhPurchased;
        paid += log.amountPaid;
      }
    }

    final DateTime monthStart = DateTime(year, month, 1);
    final DateTime monthEnd = DateTime(year, month + 1, 1);

    double consumed = 0;
    for (int i = 1; i < ascending.length; i++) {
      final WattLog earlier = ascending[i - 1];
      final WattLog later = ascending[i];

      final double intervalDays =
          daysBetween(earlier.timestamp, later.timestamp);
      if (intervalDays <= 0) continue;

      // Overlap interval dengan bulan target.
      final DateTime overlapStart =
          earlier.timestamp.isAfter(monthStart) ? earlier.timestamp : monthStart;
      final DateTime overlapEnd =
          later.timestamp.isBefore(monthEnd) ? later.timestamp : monthEnd;
      final double overlapDays = overlapEnd.difference(overlapStart).inMinutes / (60 * 24);
      if (overlapDays <= 0) continue;

      final double used = kwhConsumed(earlier, later);
      consumed += used * (overlapDays / intervalDays);
    }

    return MonthlySummary(
      year: year,
      month: month,
      kwhConsumed: consumed,
      kwhPurchased: purchased,
      amountPaid: paid,
    );
  }

  /// Estimasi sisa hari hingga token habis:
  /// `Sisa kWh Terakhir / Rata-rata kWh Harian`.
  ///
  /// Mengembalikan `null` bila tidak bisa diprediksi (rata-rata = 0).
  static double? estimatedDaysLeft({
    required double remainingKwh,
    required double dailyRate,
  }) {
    if (remainingKwh <= 0) return 0;
    if (dailyRate <= 0) return null;
    return remainingKwh / dailyRate;
  }

  /// Tanggal perkiraan token habis berdasarkan log terakhir.
  static DateTime? estimatedEmptyDate({
    required WattLog latestLog,
    required double? daysLeft,
  }) {
    if (daysLeft == null) return null;
    return latestLog.timestamp.add(
      Duration(minutes: (daysLeft * 24 * 60).round()),
    );
  }

  static List<WattLog> _sortAscending(List<WattLog> logs) {
    return List<WattLog>.from(logs)
      ..sort((WattLog a, WattLog b) => a.timestamp.compareTo(b.timestamp));
  }
}