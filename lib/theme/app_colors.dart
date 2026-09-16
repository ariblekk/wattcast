import 'package:flutter/material.dart';

/// Token warna "Electric Slate" khas WattCast.
///
/// Identitas: amber listrik (#F59E0B) for CTA berenergi di atas bodi
/// slate (#1E293B) yang tenang, latar off-white (#F8FAFC), dan status
/// danger/success/warning klasik stoplight.
class AppColors {
  AppColors._();

  // ===== Token inti =====
  static const Color background = Color(0xFFF8FAFC);
  static const Color foreground = Color(0xFF0F172A);

  static const Color card = Color(0xFFFFFFFF);
  static const Color popover = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFFF59E0B);
  static const Color primaryForeground = Color(0xFF1E293B);

  static const Color secondary = Color(0xFFF1F5F9);
  static const Color secondaryForeground = Color(0xFF1E293B);

  static const Color muted = Color(0xFFF1F5F9);
  static const Color mutedForeground = Color(0xFF64748B);

  static const Color accent = Color(0xFFF1F5F9);
  static const Color accentForeground = Color(0xFF1E293B);

  static const Color destructive = Color(0xFFEF4444);
  static const Color destructiveForeground = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE2E8F0);
  static const Color input = Color(0xFFE2E8F0);
  static const Color ring = Color(0xFFF59E0B);

  // ===== Chart (nada energy: amber → slate) =====
  static const List<Color> chart = <Color>[
    Color(0xFFF59E0B),
    Color(0xFF64748B),
    Color(0xFF334155),
    Color(0xFF1E293B),
    Color(0xFFEF4444),
  ];

  // ===== Status =====
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // ===== Masthead atas (header → carousel): slate gelap "ink" =====
  static const List<Color> topGradient = <Color>[
    Color(0xFF29384F),
    Color(0xFF1E293B),
    Color(0xFF1A2332),
  ];

  /// Cakram glow amber sangat lembut di masthead; alpha rendah murni dekoratif.
  static const Color topGlowPrimary = Color(0x1FF59E0B);

  /// Teks di atas masthead gelap; setara colorScheme.onSurface setempat.
  static const Color topForeground = Color(0xFFF8FAFC);
  static const Color topForegroundMuted = Color(0xFF94A3B8);

  // ===== Alias kompatibel nama lama =====
  static const Color surface = card;
  static const Color textPrimary = foreground;
  static const Color textSecondary = mutedForeground;
  static const Color danger = destructive;
}

/// Sudut kartu/tombol. shadcn: `--radius: 0.625rem` (≈10px @16px root),
/// turunannya persis pola Tailwind v4 (md = radius-2px, xl = radius+4px).
abstract final class AppRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 14;
  static const double xl2 = 18;
}