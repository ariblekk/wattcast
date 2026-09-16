import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meter.dart';
import '../../providers/watt_provider.dart';
import '../../theme/theme_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Sheet form untuk menambah atau mengedit meteran (nama wajib, nomor opsional).
class MeterFormSheet extends StatefulWidget {
  const MeterFormSheet({super.key, this.existing});

  final Meter? existing;

  static Future<void> show(BuildContext context, {Meter? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MeterFormSheet(existing: existing),
    );
  }

  @override
  State<MeterFormSheet> createState() => _MeterFormSheetState();
}

class _MeterFormSheetState extends State<MeterFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _tariffCtrl;
  bool _tariffPrefilled = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _numberCtrl = TextEditingController(text: widget.existing?.number ?? '');
    _tariffCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isEdit && !_tariffPrefilled) {
      _tariffPrefilled = true;
      final double? tariff =
          context.read<WattProvider>().tariffForMeterId(widget.existing!.id!);
      if (tariff != null) {
        _tariffCtrl.text = Formatters.rawDecimal(tariff);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _tariffCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama meteran wajib diisi';
    }
    return null;
  }

  String? _validateTariff(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final double? parsed = Formatters.parseDecimal(value);
    if (parsed == null || parsed <= 0) {
      return 'Tarif harus lebih dari 0';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama meteran wajib diisi')),
      );
      return;
    }

    final String tariffRaw = _tariffCtrl.text.trim();
    double? tariff;
    if (tariffRaw.isNotEmpty) {
      final double? parsed = Formatters.parseDecimal(tariffRaw);
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarif tidak valid')),
        );
        return;
      }
      tariff = parsed;
    }

    final WattProvider provider = context.read<WattProvider>();
    final String number = _numberCtrl.text.trim();
    if (_isEdit) {
      final Meter updated = widget.existing!
          .copyWith(name: name, number: number);
      await provider.updateMeter(updated);
      await provider.setTariffForMeter(updated.id!, tariff);
    } else {
      final Meter saved = await provider.addMeter(name: name, number: number);
      await provider.setTariffForMeter(saved.id!, tariff);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: ThemeColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _isEdit ? 'Edit Meteran' : 'Tambah Meteran',
                  style: AppTypography.headingMedium,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),

          AppTextField(
            label: 'Nama Meteran',
            hint: 'misal Rumah, Kos, Ruko',
            controller: _nameCtrl,
            validator: _validateName,
            autofocus: !_isEdit,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Nomor Meter',
            hint: 'opsional, misal 5241001234',
            controller: _numberCtrl,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Tarif per kWh (Rp)',
            hint: 'opsional, misal 1444',
            controller: _tariffCtrl,
            prefix: 'Rp',
            decimal: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            validator: _validateTariff,
          ),
          const SizedBox(height: 8),
          Text(
            'Setiap meteran bisa punya tarif berbeda (misal subsidi vs '
            'non-subsidi). Kosongkan jika belum tahu; tarif otomatis '
            'dihitung dari pembelian token.',
            style: AppTypography.caption.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: _isEdit ? 'Simpan Meteran' : 'Tambah Meteran',
            icon: Icons.save_outlined,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}