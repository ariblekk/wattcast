import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sentralisasi tipografi aplikasi bergaya editorial.
///
/// - Judul memakai serif **Lora** (aksen majalah/koran).
/// - Badan & angka memakai sans **Plus Jakarta Sans** — angka statistik
///   memakai *tabular figures* agar rapi sejajar.
/// - Label kecil memakai huruf kapital dengan jarak huruf rapat
///   ([micro]), lazim pada layout editorial.
///
/// Semua style TIDAK membawa warna tetap; warna diambil dari tema aktif.
/// Gunakan `.copyWith(color: ...)` untuk warna khusus.
class AppTypography {
  AppTypography._();

  static const double _height = 1.25;

  static TextStyle _sans({
    required double fontSize,
    required FontWeight weight,
    double? letterSpacing,
    List<FontFeature>? fontFeatures,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: weight,
      height: _height,
      letterSpacing: letterSpacing ?? -0.2,
      fontFeatures: fontFeatures,
    );
  }

  static TextStyle _serif({
    required double fontSize,
    required FontWeight weight,
  }) {
    return GoogleFonts.lora(
      fontSize: fontSize,
      fontWeight: weight,
      height: 1.18,
      letterSpacing: -0.3,
    );
  }

  // ===== Judul (serif) =====
  static TextStyle get serifDisplay => _serif(fontSize: 30, weight: FontWeight.w700);
  static TextStyle get headingLarge => _serif(fontSize: 24, weight: FontWeight.w700);
  static TextStyle get headingMedium => _serif(fontSize: 18, weight: FontWeight.w600);

  // ===== Angka / Statistik (sans, tabular) =====
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle get statValue =>
      _sans(fontSize: 26, weight: FontWeight.w800, fontFeatures: _tabular);
  static TextStyle get statValueOnDark =>
      _sans(fontSize: 22, weight: FontWeight.w800, fontFeatures: _tabular);

  // ===== Body =====
  static TextStyle get bodyRegular => _sans(fontSize: 14, weight: FontWeight.w400);
  static TextStyle get bodyMedium => _sans(fontSize: 14, weight: FontWeight.w600);

  // ===== Keterangan =====
  static TextStyle get caption => _sans(fontSize: 12, weight: FontWeight.w500);
  static TextStyle get captionBold =>
      _sans(fontSize: 12, weight: FontWeight.w700);

  /// Label mikro huruf kapital dengan kerning rapat (gaya editorial).
  static TextStyle micro({double fontSize = 10, double letterSpacing = 1.3}) =>
      _sans(
        fontSize: fontSize,
        weight: FontWeight.w700,
        letterSpacing: letterSpacing,
      );
}