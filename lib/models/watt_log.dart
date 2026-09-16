/// Tipe pencatatan log pada tabel `watt_logs`.
///
/// - [initial]    : pencatatan awal (memuat saldo token pertama).
/// - [purchase]   : pembelian token baru (+ penambahan kWh).
/// - [calibration]: koreksi/penyesuaian sisa kWh meter.
enum LogType {
  initial('INITIAL'),
  purchase('PURCHASE'),
  calibration('CALIBRATION');

  const LogType(this.code);

  final String code;

  static LogType fromCode(String code) => LogType.values.firstWhere(
        (type) => type.code == code,
        orElse: () => LogType.initial,
      );
}

/// Model data satu baris riwayat pencatatan watt.
class WattLog {
  const WattLog({
    this.id,
    this.meterId = 1,
    required this.timestamp,
    required this.logType,
    required this.kwhPurchased,
    required this.remainingKwh,
    required this.amountPaid,
    this.notes = '',
  });

  final int? id;

  /// Id meteran pemilik pencatatan ini.
  final int meterId;

  final DateTime timestamp;
  final LogType logType;

  /// kWh token yang dibeli (0 untuk tipe INITIAL / CALIBRATION).
  final double kwhPurchased;

  /// Sisa kWh pada meter/token saat pencatatan dilakukan.
  final double remainingKwh;

  /// Nominal rupiah yang dibayarkan (0 untuk tipe selain PURCHASE).
  final double amountPaid;

  final String notes;

  bool get isPurchase => logType == LogType.purchase;

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'meter_id': meterId,
        'timestamp': timestamp.toIso8601String(),
        'log_type': logType.code,
        'kwh_purchased': kwhPurchased,
        'remaining_kwh': remainingKwh,
        'amount_paid': amountPaid,
        'notes': notes,
      };

  factory WattLog.fromMap(Map<String, dynamic> map) => WattLog(
        id: map['id'] as int?,
        meterId: (map['meter_id'] as int?) ?? 1,
        timestamp: DateTime.parse(map['timestamp'] as String),
        logType: LogType.fromCode(map['log_type'] as String),
        kwhPurchased: (map['kwh_purchased'] as num?)?.toDouble() ?? 0,
        remainingKwh: (map['remaining_kwh'] as num?)?.toDouble() ?? 0,
        amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
        notes: (map['notes'] as String?) ?? '',
      );

  WattLog copyWith({
    int? id,
    int? meterId,
    DateTime? timestamp,
    LogType? logType,
    double? kwhPurchased,
    double? remainingKwh,
    double? amountPaid,
    String? notes,
  }) {
    return WattLog(
      id: id ?? this.id,
      meterId: meterId ?? this.meterId,
      timestamp: timestamp ?? this.timestamp,
      logType: logType ?? this.logType,
      kwhPurchased: kwhPurchased ?? this.kwhPurchased,
      remainingKwh: remainingKwh ?? this.remainingKwh,
      amountPaid: amountPaid ?? this.amountPaid,
      notes: notes ?? this.notes,
    );
  }
}