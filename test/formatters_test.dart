import 'package:flutter_test/flutter_test.dart';
import 'package:wattcast/utils/formatters.dart';

void main() {
  test('parseDecimal menerima koma maupun titik', () {
    expect(Formatters.parseDecimal('12,5'), 12.5);
    expect(Formatters.parseDecimal('200'), 200.0);
    expect(Formatters.parseDecimal('0.75'), 0.75);
    expect(Formatters.parseDecimal(''), isNull);
    expect(Formatters.parseDecimal('abc'), isNull);
  });

  test('kwh memformat desimal Indonesia', () {
    expect(Formatters.kwh(12.5), '12,5');
    expect(Formatters.kwh(1234.5), '1.234,5');
    expect(Formatters.kwh(0), '0');
    expect(Formatters.kwh(0.25), '0,25');
  });

  test('currency memformat rupiah', () {
    expect(Formatters.currency(250000), 'Rp 250.000');
    expect(Formatters.currency(1234), 'Rp 1.234');
  });
}