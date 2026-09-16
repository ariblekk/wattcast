import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Resolusi warna tema dari ColorScheme aktif.
///
/// Seluruh widget memakai helper ini agar konsisten tanpa menebak
/// palet secara manual.
abstract final class ThemeColors {
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color soft(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color border(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color success(BuildContext context) => AppColors.success;

  static Color warning(BuildContext context) => AppColors.warning;

  static Color danger(BuildContext context) => AppColors.danger;

  static Color accent(BuildContext context) => AppColors.secondaryForeground;
}
