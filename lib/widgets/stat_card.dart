import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/theme_colors.dart';

/// Kartu statistik bergaya editorial.
///
/// Strukturnya menyerupai blok angka di majalah: garis aksen tipis di
/// tepi atas (seperti warna sampul dokumen), label kapital mikro,
/// lalu angka besar tabular. Tanpa bayangan, tanpa kotak ikon.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.subtitle,
    this.badgeColor = AppColors.primary,
    this.onTap,
  });

  final String title;
  final String value;
  final String? unit;
  final String? subtitle;
  final Color badgeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ThemeColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ThemeColors.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Tab aksen warna (pita sampul dokumen yang membulat)
              Container(
                width: 30,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.micro(
                  fontSize: 9,
                  letterSpacing: 1.1,
                ).copyWith(color: ThemeColors.textSecondary(context)),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      value,
                      style: AppTypography.statValue
                          .copyWith(color: ThemeColors.textPrimary(context)),
                    ),
                    if (unit != null && unit!.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 4),
                      Text(
                        unit!,
                        style: AppTypography.micro(fontSize: 9)
                            .copyWith(color: ThemeColors.textSecondary(context)),
                      ),
                    ],
                  ],
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: ThemeColors.textSecondary(context)
                        .withValues(alpha: 0.85),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}