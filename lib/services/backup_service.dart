import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';

import '../models/meter.dart';
import '../models/watt_log.dart';

/// Layanan cadangan & pemulihan data (export/import JSON & CSV).
///
/// JSON (format v2) memuat meteran, tarif per meteran, dan seluruh log.
/// Backup lama format v1 (tanpa meteran) tetap bisa diimpor — log akan
/// digabung ke meteran pertama.
class BackupService {
  BackupService._();

  static const int _formatVersion = 2;

  // ===== Export =====

  static Map<String, Object?> _serializeJson({
    required List<Meter> meters,
    required List<WattLog> logs,
    required Map<int, double> tariffs,
  }) {
    final Map<String, Object?> tariffJson =
        tariffs.map((int id, double value) => MapEntry(id.toString(), value));
    return <String, Object?>{
      'app': 'wattcast',
      'format_version': _formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'meters': meters.map((Meter m) => m.toMap()).toList(),
      'tariffs': tariffJson,
      'logs': logs.map((WattLog log) => log.toMap()).toList(),
    };
  }

  static Future<void> exportJson({
    required List<Meter> meters,
    required List<WattLog> logs,
    required Map<int, double> tariffs,
  }) async {
    final String data = const JsonEncoder.withIndent('  ')
        .convert(_serializeJson(meters: meters, logs: logs, tariffs: tariffs));
    await FileSaver.instance.saveFile(
      name: 'wattcast-backup',
      bytes: Uint8List.fromList(utf8.encode(data)),
      fileExtension: 'json',
      mimeType: MimeType.json,
    );
  }

  static Future<void> exportCsv({
    required List<WattLog> logs,
    required Map<int, Meter> meterById,
  }) async {
    final StringBuffer buffer = StringBuffer(
      'id;meter_id;meter_name;timestamp;log_type;'
      'kwh_purchased;remaining_kwh;amount_paid;notes\n',
    );
    for (final WattLog log in logs) {
      final Meter? meter = meterById[log.meterId];
      buffer
        ..write(log.id ?? '')
        ..write(';${log.meterId}')
        ..write(';${_csvCell(meter?.name ?? '')}')
        ..write(';${log.timestamp.toIso8601String()}')
        ..write(';${log.logType.code}')
        ..write(';${log.kwhPurchased}')
        ..write(';${log.remainingKwh}')
        ..write(';${log.amountPaid}')
        ..write(';${_csvCell(log.notes)}')
        ..write('\n');
    }
    await FileSaver.instance.saveFile(
      name: 'wattcast-logs',
      bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }

  // ===== Import =====

  /// Membuka dialog pilih file JSON. Mengembalikan `null` bila batal,
  /// bukan file, atau file tidak valid.
  static Future<ImportResult?> pickJsonBackup() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (files.isEmpty) return null;

    final Uint8List bytes = await files.first.readAsBytes();
    return parseBackupJson(utf8.decode(bytes));
  }

  /// Mem-parse string JSON backup. Mengembalikan `null` bila tidak valid.
  static ImportResult? parseBackupJson(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      // Meteran (fallback: satu meteran default untuk backup versi lama).
      final List<Meter> meters = <Meter>[];
      final dynamic rawMeters = decoded['meters'];
      if (rawMeters is List) {
        for (final dynamic item in rawMeters) {
          if (item is! Map<String, dynamic>) continue;
          meters.add(_meterFromJson(item));
        }
      }
      if (meters.isEmpty) {
        meters.add(Meter(name: 'Meteran Utama', createdAt: DateTime.now()));
      }
      // Pastikan tiap meteran punya id sumber (id negatif bila tak tersedia).
      for (int i = 0; i < meters.length; i++) {
        if (meters[i].id == null) {
          meters[i] = meters[i].copyWith(id: -(i + 1));
        }
      }
      final int firstMeterId = meters.first.id!;

      // Log.
      final List<WattLog> logs = <WattLog>[];
      final dynamic rawLogs = decoded['logs'];
      if (rawLogs is List) {
        for (final dynamic item in rawLogs) {
          if (item is! Map<String, dynamic>) continue;
          final int meterId =
              (item['meter_id'] as num?)?.toInt() ?? firstMeterId;
          logs.add(_logFromJson(item, meterId: meterId));
        }
      }
      if (logs.isEmpty) return null;

      // Tarif per meteran (kunci berupa id sumber sebagai string).
      final Map<int, double> tariffs = <int, double>{};
      final dynamic rawTariffs = decoded['tariffs'];
      if (rawTariffs is Map<String, dynamic>) {
        rawTariffs.forEach((String key, dynamic value) {
          if (value is num) {
            final int? meterId = int.tryParse(key);
            if (meterId != null) tariffs[meterId] = value.toDouble();
          }
        });
      }

      return ImportResult(meters: meters, logs: logs, tariffs: tariffs);
    } on FormatException {
      return null;
    }
  }

  static Meter _meterFromJson(Map<String, dynamic> json) => Meter(
        id: (json['id'] as num?)?.toInt(),
        name: (json['name'] as String?) ?? 'Meteran',
        number: (json['number'] as String?) ?? '',
        createdAt: DateTime.tryParse(
              (json['created_at'] as String?) ?? '',
            ) ??
            DateTime.now(),
      );

  static WattLog _logFromJson(Map<String, dynamic> json, {required int meterId}) =>
      WattLog(
        meterId: meterId,
        timestamp: DateTime.parse(json['timestamp'] as String),
        logType: LogType.fromCode(json['log_type'] as String),
        kwhPurchased: (json['kwh_purchased'] as num?)?.toDouble() ?? 0,
        remainingKwh: (json['remaining_kwh'] as num?)?.toDouble() ?? 0,
        amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
        notes: (json['notes'] as String?) ?? '',
      );

  static String _csvCell(String value) {
    if (!value.contains('"') && !value.contains(';') && !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }
}

/// Hasil parsing backup JSON: meteran, tarif per meteran, dan log.
class ImportResult {
  const ImportResult({
    required this.meters,
    required this.logs,
    required this.tariffs,
  });

  final List<Meter> meters;
  final List<WattLog> logs;
  final Map<int, double> tariffs;
}