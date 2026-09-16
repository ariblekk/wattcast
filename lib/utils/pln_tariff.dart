/// Referensi tarif listrik PLN (penyesuaian tarif dibekukan 2025)
/// untuk membandingkan tarif efektif yang terdeteksi dari pembelian.
class PlnTariffReference {
  const PlnTariffReference({
    required this.va,
    required this.rate,
    required this.reasonable,
  });

  final int va;
  final double rate;
  final bool reasonable;
}

/// Klaster tarif resmi PLN per daya (R-1/TR), Rp/kWh.
class PlnTariff {
  PlnTariff._();

  static const List<int> tiersVa = <int>[450, 900, 1300, 2200, 3500, 5500, 6600];
  static const List<double> tiersRate = <double>[
    415, // 450 VA (bersubsidi)
    1352, // 900 VA (bersubsidi)
    1444.7, // 1300 VA
    1444.7, // 2200 VA
    1699.53, // 3500–5500 VA
    1699.53, // 5500 VA
    1699.53, // 6600 VA ke atas
  ];

  /// Mencari klaster terdekat dari [tariff]; `reasonable` bernilai `true`
  /// bila selisihnya ≤ 15% dari tarif resmi klaster terdekat.
  static PlnTariffReference? referenceFor(double tariff) {
    if (tariff <= 0) return null;

    int bestIndex = 0;
    double bestDiff = double.infinity;
    for (int i = 0; i < tiersRate.length; i++) {
      final double diff = (tariff - tiersRate[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }

    final double rate = tiersRate[bestIndex];
    final bool reasonable = bestDiff <= rate * 0.15;
    return PlnTariffReference(
      va: tiersVa[bestIndex],
      rate: rate,
      reasonable: reasonable,
    );
  }
}