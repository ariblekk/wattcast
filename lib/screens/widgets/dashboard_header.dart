import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/watt_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_colors.dart';
import '../../utils/formatters.dart';
import 'settings_sheet.dart';

/// Masthead aplikasi: judul tinta + total bayar + tombol pengaturan.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.mini});

  final bool mini;

  Widget _gearBadge(BuildContext context, String totalText) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          decoration: BoxDecoration(
            color: ThemeColors.surface(context).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: ThemeColors.border(context).withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                totalText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headingMedium.copyWith(
                  fontSize: 16,
                  color: ThemeColors.textPrimary(context),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => SettingsSheet.show(context),
                icon: const Icon(Icons.settings_outlined, size: 18),
                color: ThemeColors.textSecondary(context),
                tooltip: 'Pengaturan',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WattProvider provider = context.watch<WattProvider>();
    final String totalText = provider.totalAmountPaid > 0
        ? Formatters.currency(provider.totalAmountPaid)
        : 'Rp 0';

    return SizedBox(
      height: 74,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 6, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (mini)
              _gearBadge(context, totalText)
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    totalText,
                    style: AppTypography.headingMedium.copyWith(
                      color: AppColors.topForeground,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    onPressed: () => SettingsSheet.show(context),
                    icon: const Icon(Icons.settings_outlined, size: 22),
                    color: AppColors.topForegroundMuted,
                    tooltip: 'Pengaturan',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class DashboardTitle extends StatelessWidget {
  const DashboardTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 6, 0),
      child: Text(
        'WattCast',
        style: AppTypography.serifDisplay.copyWith(
          color: AppColors.topForeground,
        ),
      ),
    );
  }
}
