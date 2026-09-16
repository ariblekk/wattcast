import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_typography.dart';

/// Input field aplikasi dengan styling konsisten (AppColors & AppTypography).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.validator,
    this.prefix,
    this.suffixText,
    this.decimal = false,
    this.autofocus = false,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  /// Teks prefix di dalam field, misal `Rp`.
  final String? prefix;

  /// Teks suffix di dalam field, misal `kWh`.
  final String? suffixText;

  /// Aktifkan pembatasan input angka desimal (koma / titik).
  final bool decimal;

  final bool autofocus;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  static final List<TextInputFormatter> _decimalFormatter =
      <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
        TextInputFormatter.withFunction((
          TextEditingValue oldValue,
          TextEditingValue newValue,
        ) {
          final String text = newValue.text;
          final int separators = RegExp('[,.]').allMatches(text).length;
          if (separators > 1) return oldValue;
          return newValue;
        }),
      ];

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      keyboardType:
          keyboardType ?? (decimal ? TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
      inputFormatters: decimal ? _decimalFormatter : null,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        suffixText: suffixText,
      ),
      style: AppTypography.bodyMedium,
    );
  }
}
