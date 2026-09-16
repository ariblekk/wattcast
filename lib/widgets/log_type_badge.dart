import 'package:flutter/material.dart';

import '../models/watt_log.dart';
import '../theme/app_typography.dart';
import '../theme/theme_colors.dart';

/// Penanda tipe log bergaya editorial: titik warna + label kapital
/// tanpa kotak/ikon latar.
class LogTypeBadge extends StatelessWidget {
  const LogTypeBadge({super.key, required this.type, this.compact = false});

  final LogType type;
  final bool compact;

  String get _label {
    switch (type) {
      case LogType.purchase:
        return 'Beli Token';
      case LogType.calibration:
        return 'Kalibrasi';
      case LogType.initial:
        return 'Pencatatan Awal';
    }
  }

  Color _color(BuildContext context) {
    switch (type) {
      case LogType.purchase:
        return ThemeColors.success(context);
      case LogType.calibration:
        return ThemeColors.warning(context);
      case LogType.initial:
        return ThemeColors.accent(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _color(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: compact ? 5 : 6,
          height: compact ? 5 : 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: compact ? 3 : 5),
        Text(
          _label,
          style: AppTypography.micro(
            fontSize: compact ? 8 : 9,
            letterSpacing: 1.2,
          ).copyWith(color: color),
        ),
      ],
    );
  }
}