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

  test('días relativos y cortos', () {
    final now = DateTime(2026, 11, 16, 9);

    expect(Dates.relativeDay(DateTime(2026, 11, 16), now), 'Hoy');
    expect(Dates.relativeDay(DateTime(2026, 11, 15), now), 'Ayer');
    expect(Dates.relativeDay(DateTime(2026, 11, 17), now), 'Mañana');
    expect(Dates.relativeDay(DateTime(2026, 11, 14), now), 'Sábado, 14 de noviembre');
    expect(Dates.relativeDay(DateTime(2025, 3, 2), now), 'Domingo, 2 de marzo de 2025');
    expect(Dates.shortDay(DateTime(2026, 11, 20), now), '20 nov');
    expect(Dates.shortDay(DateTime(2027, 1, 5), now), '5 ene 2027');
    // El cambio de hora de octubre no convierte "ayer" en "hoy".
    expect(Dates.relativeDay(DateTime(2026, 10, 25), DateTime(2026, 10, 26, 0, 30)), 'Ayer');
  });
}
