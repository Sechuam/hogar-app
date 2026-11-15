import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/money/money.dart';
import '../../../core/providers.dart';
import '../../../core/ui/dates.dart';
import '../../auth/session_controller.dart';

/// Ingreso de un miembro: puntual (cuenta en el mes de [date]) o recurrente (cada mes desde [date]
/// hasta [endDate], o sin fin).
class Income {
  const Income({
    required this.id,
    required this.userId,
    required this.amount,
    required this.concept,
    required this.date,
    required this.recurring,
    required this.endDate,
  });

  factory Income.fromJson(Json json) => Income(
    id: json['id'] as String,
    userId: json['userId'] as String,
    amount: Money.fromJson(json['amount']),
    concept: json['concept'] as String,
    date: Dates.fromApi(json['date'] as String),
    recurring: json['recurring'] as bool,
    endDate: Dates.fromApiOrNull(json['endDate']),
  );

  final String id;
  final String userId;
  final Decimal amount;
  final String concept;
  final DateTime date;
  final bool recurring;
  final DateTime? endDate;

  /// `el 15/11/2026`, `cada mes desde el 01/11/2026` o `cada mes del 01/11/2026 al 31/12/2026`.
  String get period {
    if (!recurring) {
      return 'el ${Dates.format(date)}';
    }
    return endDate == null
        ? 'cada mes desde el ${Dates.format(date)}'
        : 'cada mes del ${Dates.format(date)} al ${Dates.format(endDate!)}';
  }
}

/// Alta o reemplazo de un ingreso propio, tal como lo valida el formulario.
class NewIncome {
  const NewIncome({
    required this.amount,
    required this.concept,
    required this.date,
    required this.recurring,
    this.endDate,
  });

  final Decimal amount;
  final String concept;
  final DateTime date;
  final bool recurring;
  final DateTime? endDate;

  Json toJson() => {
    'amount': Money.toJson(amount),
    'concept': concept.trim(),
    'date': Dates.toApi(date),
    'recurring': recurring,
    // La API rechaza `endDate` en ingresos puntuales.
    if (recurring && endDate != null) 'endDate': Dates.toApi(endDate!),
  };
}

class MemberIncome {
  const MemberIncome({required this.userId, required this.amount, required this.percentage});

  factory MemberIncome.fromJson(Json json) => MemberIncome(
    userId: json['userId'] as String,
    amount: Money.fromJson(json['amount']),
    percentage: Money.fromJson(json['percentage']),
  );

  final String userId;
  final Decimal amount;

  /// Sobre el total del mes; los de todos suman 100 (o todos 0 si nadie tiene ingresos).
  final Decimal percentage;
}

/// Ingresos computables de cada miembro activo en un mes: la base del reparto proporcional.
class IncomeSummary {
  const IncomeSummary({required this.currency, required this.total, required this.members});

  factory IncomeSummary.fromJson(Json json) => IncomeSummary(
    currency: json['currency'] as String,
    total: Money.fromJson(json['total']),
    members: (json['members'] as List).map((m) => MemberIncome.fromJson(m as Json)).toList(),
  );

  final String currency;
  final Decimal total;
  final List<MemberIncome> members;
}

class IncomesRepository {
  IncomesRepository(this._api);

  /// Máximo de la API; nadie registra cien fuentes de ingresos.
  static const pageSize = 100;
  final ApiClient _api;

  Future<IncomeSummary> summary(String householdId, DateTime month) async => IncomeSummary.fromJson(
    await _api.get('/api/households/$householdId/incomes/summary', query: {'month': Dates.monthToApi(month)}) as Json,
  );

  Future<List<Income>> ofUser(String householdId, String userId) async {
    final json =
        await _api.get('/api/households/$householdId/incomes', query: {'userId': userId, 'size': pageSize}) as Json;
    return (json['content'] as List).map((i) => Income.fromJson(i as Json)).toList();
  }

  Future<Income> create(String householdId, NewIncome income) async =>
      Income.fromJson(await _api.post('/api/households/$householdId/incomes', body: income.toJson()) as Json);

  Future<Income> update(String householdId, String incomeId, NewIncome income) async =>
      Income.fromJson(await _api.put('/api/households/$householdId/incomes/$incomeId', body: income.toJson()) as Json);

  Future<void> delete(String householdId, String incomeId) =>
      _api.delete('/api/households/$householdId/incomes/$incomeId');
}

final incomesRepositoryProvider = Provider<IncomesRepository>((ref) => IncomesRepository(ref.watch(apiClientProvider)));

/// Resumen de un mes: `(householdId, primer día del mes)`.
final incomeSummaryProvider = FutureProvider.family<IncomeSummary, (String, DateTime)>(
  (ref, key) => ref.watch(incomesRepositoryProvider).summary(key.$1, key.$2),
);

/// Ingresos propios del usuario con sesión en un hogar (los de los demás solo se ven en el resumen).
final myIncomesProvider = FutureProvider.family<List<Income>, String>((ref, householdId) async {
  final me = await ref.watch(sessionProvider.future);
  return me == null ? const [] : ref.watch(incomesRepositoryProvider).ofUser(householdId, me.id);
});
