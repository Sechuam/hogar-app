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

  /// Primer día del mes de [date]: así se representa un mes en la app.
  static DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

  /// Mes para la API: `2026-11`.
  static String monthToApi(DateTime month) => '${month.year.toString().padLeft(4, '0')}-${_two(month.month)}';

  /// `noviembre de 2026`.
  static String formatMonth(DateTime month) => '${_months[month.month - 1]} de ${month.year}';

  /// Mes siguiente (o anterior con [delta] negativo).
  static DateTime addMonths(DateTime month, int delta) => DateTime(month.year, month.month + delta);

  /// Cabecera de un día en una lista: `Hoy`, `Ayer`, `Lunes, 10 de noviembre` (con el año si no es el
  /// actual).
  static String relativeDay(DateTime date, [DateTime? now]) {
    final today = Dates.today(now);
    final day = DateTime(date.year, date.month, date.day);
    // En UTC: un cambio de hora no convierte "ayer" en un día de 23 horas.
    final diff = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
    if (diff == 0) {
      return 'Hoy';
    }
    if (diff == 1) {
      return 'Ayer';
    }
    if (diff == -1) {
      return 'Mañana';
    }
    final weekday = _weekdays[day.weekday - 1];
    final label = '${weekday[0].toUpperCase()}${weekday.substring(1)}, ${day.day} de ${_months[day.month - 1]}';
    return day.year == today.year ? label : '$label de ${day.year}';
  }

  /// Fecha corta para subtítulos: `Hoy`, `Ayer`, `Mañana`, `14 nov` (y el año si no es el actual).
  static String shortDay(DateTime date, [DateTime? now]) {
    final relative = relativeDay(date, now);
    if (relative == 'Hoy' || relative == 'Ayer' || relative == 'Mañana') {
      return relative;
    }
    final label = '${date.day} ${_months[date.month - 1].substring(0, 3)}';
    return date.year == Dates.today(now).year ? label : '$label ${date.year}';
  }

  static const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

  static const _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static String _two(int value) => value.toString().padLeft(2, '0');
}
