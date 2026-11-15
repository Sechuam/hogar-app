import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/core/ui/dates.dart';

void main() {
  test('meses: formato de la API, texto y aritmética con cambio de año', () {
    final november = Dates.monthOf(DateTime(2026, 11, 15));

    expect(november, DateTime(2026, 11));
    expect(Dates.monthToApi(november), '2026-11');
    expect(Dates.formatMonth(november), 'noviembre de 2026');
    expect(Dates.addMonths(november, 2), DateTime(2027, 1));
    expect(Dates.addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
  });
}
