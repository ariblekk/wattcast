import 'package:intl/intl.dart';

/// Kumpulan fungsi formatting yang dipakai di seluruh UI.
class Formatters {
  Formatters._();

  // ===== Parsing =====

  /// Mem-parse input desimal pengguna; menerima koma maupun titik
  /// sebagai pemisah desimal (menyesuaikan keyboard Indonesia).
  static double? parseDecimal(String? value) {
    if (value == null) return null;
    final String cleaned = value.trim().replaceAll(',', '.').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  // ===== Angka =====

  /// Format desimal dengan pemisah ribuan titik, misal `12,5` atau `1.234,56`.
  /// Nilai kecil (< 1 kWh) ditampilkan dengan presisi lebih tinggi.
  static String kwh(double value) {
    if (value == 0) return '0';
    final double abs = value.abs();
    final String raw = _trimTrailingZeros(value.toStringAsFixed(abs < 1 ? 3 : 2));
    return _groupThousands(raw);
  }

  /// Representasi desimal "mentah" (memakai titik) untuk isian form,
  /// aman dibaca ulang oleh [parseDecimal].
  static String rawDecimal(double value) =>
      _trimTrailingZeros(value.toStringAsFixed(2));

  /// Format angka bulat dengan pemisah ribuan, misal `1.234`.
  static String number(double value) => _groupThousands(value.toStringAsFixed(0));

  /// Format rupiah tanpa desimal, misal `Rp 250.000`.
  static String currency(double value) =>
      'Rp ${_groupThousands(value.round().toString())}';

  // ===== Tanggal / waktu =====

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  static String date(DateTime value) => _dateFormat.format(value);
  static String time(DateTime value) => _timeFormat.format(value);
  static String dateTime(DateTime value) => '${date(value)} · ${time(value)}';

  // ===== Helper internal =====

  static String _trimTrailingZeros(String raw) {
    if (!raw.contains('.')) return raw;
    String trimmed = raw.replaceAll(RegExp(r'0+$'), '');
    trimmed = trimmed.replaceAll(RegExp(r'\.$'), '');
    return trimmed;
  }

  static String _groupThousands(String digits) {
    final bool isNegative = digits.startsWith('-');
    final String absolute = isNegative ? digits.substring(1) : digits;

    final List<String> parts = absolute.split('.');
    final String intPart = parts.first;
    final String decPart = parts.length > 1 ? ',${parts[1]}' : '';

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      buffer.write(intPart[i]);
      final int remaining = intPart.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buffer.write('.');
    }

    return '${isNegative ? '-' : ''}${buffer.toString()}$decPart';
  }
}