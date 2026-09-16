import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/theme_colors.dart';

enum AppButtonVariant { primary, secondary, outline, danger }

/// Tombol solid tanpa gradien — semantik varian mengikuti shadcn/ui.
///
/// - [primary]  : shadcn "default" — latar `primary` (CTA utama / default).
/// - [secondary]: latar `secondary` abu, teks `secondaryForeground`.
/// - [outline]  : `card` + garis rambut `border`.
/// - [danger]   : shadcn "destructive" — latar `destructive`.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.expanded = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool expanded;
  final bool loading;

  bool get _enabled => !loading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final _ButtonPalette palette = _resolvePalette(context);
    final bool isOutline = variant == AppButtonVariant.outline;

    final Widget content = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: palette.foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: palette.foreground),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.captionBold.copyWith(
                  color: palette.foreground,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          );

    return SizedBox(
      height: 50,
      width: expanded ? double.infinity : null,
      child: Opacity(
        opacity: _enabled ? 1 : 0.45,
        child: Material(
          color: palette.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isOutline
                ? BorderSide(color: ThemeColors.border(context))
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _enabled ? onPressed : null,
            splashColor: palette.foreground.withValues(alpha: 0.12),
            highlightColor: palette.foreground.withValues(alpha: 0.06),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }

  _ButtonPalette _resolvePalette(BuildContext context) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _ButtonPalette(
          background: AppColors.primary,
          foreground: AppColors.primaryForeground,
        );
      case AppButtonVariant.secondary:
        return _ButtonPalette(
          background: AppColors.secondary,
          foreground: AppColors.secondaryForeground,
        );
      case AppButtonVariant.outline:
        return _ButtonPalette(
          background: ThemeColors.surface(context),
          foreground: ThemeColors.textPrimary(context),
        );
      case AppButtonVariant.danger:
        return _ButtonPalette(
          background: AppColors.danger,
          foreground: AppColors.destructiveForeground,
        );
    }
  }
}

class _ButtonPalette {
  const _ButtonPalette({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}