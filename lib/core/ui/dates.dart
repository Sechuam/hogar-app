/// Fechas de negocio (sin hora) entre la API (`yyyy-MM-dd`) y la UI (`15/11/2026`).
abstract final class Dates {
  static DateTime fromApi(String value) {
    final parts = value.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static DateTime? fromApiOrNull(Object? value) => value is String ? fromApi(value) : null;

  static String toApi(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

  static String format(DateTime date) => '${_two(date.day)}/${_two(date.month)}/${date.year}';

  static DateTime today([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
