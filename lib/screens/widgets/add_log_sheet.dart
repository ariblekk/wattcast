import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/watt_log.dart';
import '../../providers/watt_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Modal bottom sheet untuk input log (INITIAL / PURCHASE / CALIBRATION)
/// atau mengubah log yang sudah ada ([existingLog]).
///
/// Pada PURCHASE: user memasukkan nominal bayar, lalu field
/// "KWh Setelah Diisi" di-prefill otomatis (saldo terakhir + nominal ÷ tarif
/// tersimpan). Nilai prefill bisa diedit sesuai display meter — selisihnya
/// menjadi kWh terisi, dan sekaligus mengoreksi saldo (mini-kalibrasi).
class AddLogSheet extends StatefulWidget {
  const AddLogSheet({
    super.key,
    this.initialType = LogType.purchase,
    this.existingLog,
  });

  final LogType initialType;
  final WattLog? existingLog;

  static Future<void> show(
    BuildContext context, {
    LogType initialType = LogType.purchase,
    WattLog? existingLog,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) =>
          AddLogSheet(initialType: initialType, existingLog: existingLog),
    );
  }

  @override
  State<AddLogSheet> createState() => _AddLogSheetState();
}

class _AddLogSheetState extends State<AddLogSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _afterCtrl = TextEditingController();
  final TextEditingController _remainingCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  late LogType _type;
  bool _prefilled = false;
  bool _submitted = false;
  bool _saving = false;

  /// `true` bila user mengubah field "KWh Setelah Diisi" secara manual,
  /// sehingga prefill otomatis tidak lagi menimpanya.
  bool _afterTouched = false;

  bool get _isPurchase => _type == LogType.purchase;
  bool get _isEditing => widget.existingLog != null;

  /// Nominal token standar PLN.
  static const List<int> _standardNominals = <int>[
    20000,
    50000,
    100000,
    250000,
    500000,
    1000000,
  ];

  static String _nominalLabel(int nominal) {
    if (nominal >= 1000000) {
      final int juta = nominal ~/ 1000000;
      return 'Rp${juta}jt';
    }
    return 'Rp${nominal ~/ 1000}rb';
  }

  /// Saldo dasar sebelum pembelian: sisa kWh log sebelumnya (meter yang sama),
  /// atau 0 bila belum ada data.
  double get _baseRemaining {
    final WattProvider provider = context.read<WattProvider>();
    final WattLog? existing = widget.existingLog;
    if (existing != null) {
      final List<WattLog> older = provider.logs
          .where(
            (WattLog l) =>
                l.meterId == existing.meterId &&
                !l.timestamp.isAfter(existing.timestamp) &&
                l.id != existing.id,
          )
          .toList();
      return older.isEmpty ? 0 : older.first.remainingKwh;
    }
    return provider.latestLog?.remainingKwh ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _type = widget.existingLog?.logType ?? widget.initialType;
    _amountCtrl.addListener(_onAmountChanged);

    final WattLog? existing = widget.existingLog;
    if (existing != null) {
      if (existing.isPurchase) {
        _afterCtrl.text = Formatters.rawDecimal(existing.remainingKwh);
      } else {
        _remainingCtrl.text = Formatters.rawDecimal(existing.remainingKwh);
      }
      _amountCtrl.text = Formatters.rawDecimal(existing.amountPaid);
      _notesCtrl.text = existing.notes;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefilled) {
      _prefilled = true;
      if (!_isEditing) {
        final WattLog? latest = context.read<WattProvider>().latestLog;
        if (_isPurchase) {
          _syncPurchaseEstimate();
        } else if (latest != null) {
          // INITIAL / CALIBRATION: prefill sisa kWh dari log terakhir.
          _remainingCtrl.text = Formatters.rawDecimal(latest.remainingKwh);
        }
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _afterCtrl.dispose();
    _remainingCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    _syncPurchaseEstimate();
    setState(() {});
  }

  /// Update prefill "KWh Setelah Diisi" saat nominal berubah,
  /// selama user belum mengedit field itu manual.
  void _syncPurchaseEstimate() {
    if (!_isPurchase || _afterTouched || _isEditing) return;
    final double amount = Formatters.parseDecimal(_amountCtrl.text) ?? 0;
    final WattProvider provider = context.read<WattProvider>();
    final double? tariff = provider.tariffPerKwh;
    final double estKwh = (tariff != null && tariff > 0) ? amount / tariff : 0;
    final double preview = _baseRemaining + estKwh;
    final String text = Formatters.rawDecimal(preview);
    if (_afterCtrl.text != text) {
      _afterCtrl.text = text;
      _afterCtrl.selection = TextSelection.collapsed(offset: text.length);
    }
    setState(() {});
  }

  // ===== Validasi =====

  String? _validateRequiredDouble(
    String? value, {
    required String label,
    bool mustBePositive = false,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$label wajib diisi';
    }
    final double? parsed = Formatters.parseDecimal(value);
    if (parsed == null) {
      return '$label tidak valid';
    }
    if (parsed < 0) {
      return '$label tidak boleh negatif';
    }
    if (mustBePositive && parsed <= 0) {
      return '$label harus lebih dari 0';
    }
    return null;
  }

  String? _validateAfter(String? value) {
    final String? err = _validateRequiredDouble(
      value,
      label: 'KWh setelah diisi',
    );
    if (err != null) return err;
    final double after = Formatters.parseDecimal(value!)!;
    final double base = _isPurchase ? _baseRemaining : 0;
    if (_isPurchase && after <= base) {
      return 'KWh setelah diisi harus lebih besar dari saldo sebelumnya '
          '(${Formatters.rawDecimal(base)} kWh)';
    }
    return null;
  }

  String? _validateRemaining(String? value) =>
      _validateRequiredDouble(value, label: 'Sisa kWh', mustBePositive: true);

  String? _validateAmount(String? value) => _validateRequiredDouble(
    value,
    label: 'Nominal token',
    mustBePositive: true,
  );

  // ===== Aksi simpan =====

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    final WattLog? existing = widget.existingLog;
    final double after = Formatters.parseDecimal(_afterCtrl.text) ?? 0;
    final double amountPaid = _isPurchase
        ? (Formatters.parseDecimal(_amountCtrl.text) ?? 0)
        : 0;
    final double purchased = _isPurchase && after > _baseRemaining
        ? after - _baseRemaining
        : 0;

    final WattLog log = WattLog(
      id: existing?.id,
      timestamp: existing?.timestamp ?? DateTime.now(),
      logType: _type,
      kwhPurchased: purchased,
      remainingKwh: _isPurchase
          ? after
          : (Formatters.parseDecimal(_remainingCtrl.text) ?? 0),
      amountPaid: amountPaid,
      notes: _notesCtrl.text.trim(),
    );

    if (_isEditing) {
      await context.read<WattProvider>().updateLog(log);
    } else {
      await context.read<WattProvider>().addLog(log);
    }

    if (!mounted) return;
    final double? implied = (_isPurchase && purchased > 0 && amountPaid > 0)
        ? amountPaid / purchased
        : null;
    String message = _isEditing
        ? 'Pencatatan berhasil diperbarui'
        : 'Pencatatan berhasil disimpan';
    if (implied != null && implied > 0) {
      message = '$message · Tarif ${Formatters.rawDecimal(implied)}/kWh';
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Navigator.pop(context);
  }

  // ===== UI =====

  /// Chip pilihan cepat nominal token standar.
  Widget _buildNominalChip(int nominal) {
    final bool selected =
        (Formatters.parseDecimal(_amountCtrl.text) ?? -1) == nominal;
    return GestureDetector(
      onTap: () {
        _amountCtrl.text = Formatters.rawDecimal(nominal.toDouble());
        _syncPurchaseEstimate();
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : ThemeColors.border(context),
          ),
        ),
        child: Text(
          _nominalLabel(nominal),
          style: AppTypography.caption.copyWith(
            fontSize: 11.5,
            color: selected
                ? AppColors.primaryForeground
                : ThemeColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  String get _typeHint {
    switch (_type) {
      case LogType.purchase:
        return 'Nominal tidak termasuk biaya admin/layanan.';
      case LogType.calibration:
        return 'Perbarui sisa kWh meter sesuai pembacaan terbaru.';
      case LogType.initial:
        return 'Pencatatan pertama untuk mulai memantau pemakaian.';
    }
  }

  /// Teks info di bawah form purchase: kWh terisi, tarif implied, dsb.
  String get _purchaseInfoText {
    final double amount = Formatters.parseDecimal(_amountCtrl.text) ?? 0;
    final double after = Formatters.parseDecimal(_afterCtrl.text) ?? 0;
    final double base = _baseRemaining;
    final double filled = after > base ? after - base : 0;
    final WattProvider provider = context.read<WattProvider>();
    if (!provider.hasTariff && filled <= 0) {
      return 'Tarif belum tersimpan — isi KWh setelah diisi sesuai display '
          'meter, tarif akan dipelajari otomatis.';
    }
    final StringBuffer sb = StringBuffer(
      'KWh terisi: ${Formatters.rawDecimal(filled)}',
    );
    if (filled > 0 && amount > 0) {
      sb.write(' · Rp.${Formatters.rawDecimal(amount / filled)}/kWh');
    }
    if (provider.hasTariff) {
      sb.write(
        ' · tarif tersimpan Rp.${Formatters.rawDecimal(provider.tariffPerKwh!)}/kWh',
      );
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final AutovalidateMode autoMode = _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          autovalidateMode: autoMode,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Handle sheet
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _isEditing ? 'Ubah Pencatatan' : 'Catat Pemakaian',
                          style: AppTypography.headingMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEditing
                              ? 'Waktu pencatatan tidak dapat diubah.'
                              : 'Sesuaikan tipe pencatatan di bawah.',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: ThemeColors.textSecondary(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pilih tipe log
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<LogType>(
                  segments: const <ButtonSegment<LogType>>[
                    ButtonSegment<LogType>(
                      value: LogType.initial,
                      label: Text('Awal'),
                      icon: Icon(Icons.flag),
                    ),
                    ButtonSegment<LogType>(
                      value: LogType.purchase,
                      label: Text('Beli'),
                      icon: Icon(Icons.add_chart),
                    ),
                    ButtonSegment<LogType>(
                      value: LogType.calibration,
                      label: Text('Kalibrasi'),
                      icon: Icon(Icons.tune),
                    ),
                  ],
                  selected: <LogType>{_type},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<LogType> selection) {
                    setState(() => _type = selection.first);
                    if (_isPurchase && !_isEditing) {
                      _syncPurchaseEstimate();
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(_typeHint, style: AppTypography.caption),
              const SizedBox(height: 20),

              // PURCHASE: nominal → KWh setelah diisi (prefill, editable)
              if (_isPurchase) ...<Widget>[
                Text('Nominal Token', style: AppTypography.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final int nominal in _standardNominals)
                      _buildNominalChip(nominal),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Nominal Token (Rp)',
                  hint: 'misal 50000',
                  controller: _amountCtrl,
                  decimal: true,
                  prefix: 'Rp',
                  validator: _validateAmount,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'KWh Setelah Diisi',
                  hint: 'misal 242,5',
                  controller: _afterCtrl,
                  decimal: true,
                  suffixText: 'kWh',
                  onChanged: (_) => _afterTouched = true,
                  validator: _validateAfter,
                ),
                const SizedBox(height: 6),
                Text(
                  _purchaseInfoText,
                  style: AppTypography.caption.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 14),
              ] else ...<Widget>[
                AppTextField(
                  label: 'Sisa kWh',
                  hint: 'misal 85,5',
                  controller: _remainingCtrl,
                  decimal: true,
                  suffixText: 'kWh',
                  validator: _validateRemaining,
                ),
                const SizedBox(height: 14),
              ],
              AppTextField(
                label: 'Catatan (opsional)',
                hint: 'Catatan tambahan…',
                controller: _notesCtrl,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 24),

              AppButton(
                label: _isEditing ? 'Simpan Perubahan' : 'Simpan Pencatatan',
                icon: Icons.check_circle_outline,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
