import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hogar_app/core/money/money.dart';
import 'package:hogar_app/core/ui/dates.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  group('Money', () {
    test('lee importes de la API como Decimal exacto', () {
      expect(Money.fromJson(42.18), d('42.18'));
      expect(Money.fromJson(0.1), d('0.1'));
      expect(Money.fromJson(100), d('100'));
      expect(Money.fromJson('12.34'), d('12.34'));
      expect(Money.fromJson(1234567890123.45), d('1234567890123.45'));
      expect(() => Money.fromJson(null), throwsFormatException);
    });

    test('envía siempre texto con dos decimales', () {
      expect(Money.toJson(d('42.1')), '42.10');
      expect(Money.toJson(d('7')), '7.00');
    });

    test('acepta coma o punto decimal y como mucho dos decimales', () {
      expect(Money.parseInput('12'), d('12'));
      expect(Money.parseInput(' 12,5 '), d('12.5'));
      expect(Money.parseInput('0.01'), d('0.01'));
      for (final bad in ['', '0', '0,00', '-3', '12,345', '1.234,56', 'abc', '12.', '1e3', '123456789012345678']) {
        expect(Money.parseInput(bad), isNull, reason: bad);
      }
    });

    test('formatea en español con separador de miles', () {
      expect(Money.format(d('1234.5'), 'EUR'), '1.234,50 €');
      expect(Money.format(d('0.05'), 'EUR'), '0,05 €');
      expect(Money.format(d('-293.33'), 'EUR'), '-293,33 €');
      expect(Money.format(d('1000000'), 'USD'), '1.000.000,00 USD');
      expect(Money.format(d('999'), 'EUR'), '999,00 €');
    });
  });

  group('Dates', () {
    test('ida y vuelta con el formato de la API', () {
      final date = Dates.fromApi('2026-03-05');
      expect(date, DateTime(2026, 3, 5));
      expect(Dates.toApi(date), '2026-03-05');
      expect(Dates.format(date), '05/03/2026');
      expect(Dates.fromApiOrNull(null), isNull);
      expect(Dates.today(DateTime(2026, 11, 15, 23, 59)), DateTime(2026, 11, 15));
    });
  });
}
