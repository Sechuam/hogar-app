import 'package:decimal/decimal.dart';

/// Importes con [Decimal] (A-003): nunca `double` para operar ni para enviar.
abstract final class Money {
  static final _input = RegExp(r'^\d{1,17}([.,]\d{1,2})?$');

  /// Importe que llega de la API (número JSON, ya decodificado como `num`, o texto).
  static Decimal fromJson(Object? value) {
    if (value is int) {
      return Decimal.fromInt(value);
    }
    if (value is num || value is String) {
      return Decimal.parse(value.toString());
    }
    throw FormatException('Importe no válido: $value');
  }

  /// Importe para el cuerpo de una petición: texto con 2 decimales (`"42.18"`).
  static String toJson(Decimal amount) => amount.toStringAsFixed(2);

  /// Lo que teclea el usuario: `12`, `12,5`, `12.50`. `null` si no es un importe positivo válido
  /// (máximo 17 cifras enteras y 2 decimales, como la API).
  static Decimal? parseInput(String text) {
    final trimmed = text.trim().replaceAll(' ', '');
    if (!_input.hasMatch(trimmed)) {
      return null;
    }
    final value = Decimal.parse(trimmed.replaceAll(',', '.'));
    return value > Decimal.zero ? value : null;
  }

  /// `1234.5` → `1.234,50 €` (EUR) o `1.234,50 USD` (resto). El signo negativo va delante.
  static String format(Decimal amount, String currency) {
    final negative = amount < Decimal.zero;
    final fixed = amount.abs().toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    final integer = fixed.substring(0, dot);
    final decimals = fixed.substring(dot + 1);
    final grouped = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      if (i > 0 && (integer.length - i) % 3 == 0) {
        grouped.write('.');
      }
      grouped.write(integer[i]);
    }
    final symbol = currency == 'EUR' ? '€' : currency;
    return '${negative ? '-' : ''}$grouped,$decimals $symbol';
  }
}
