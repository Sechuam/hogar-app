import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/money/money.dart';
import '../../../core/providers.dart';
import '../../../core/ui/dates.dart';

/// Categorías del contrato, con su etiqueta en la UI.
enum ExpenseCategory {
  rent('RENT', 'Alquiler'),
  groceries('GROCERIES', 'Compra'),
  electricity('ELECTRICITY', 'Luz'),
  water('WATER', 'Agua'),
  gas('GAS', 'Gas'),
  internet('INTERNET', 'Internet'),
  cleaning('CLEANING', 'Limpieza'),
  homeSupplies('HOME_SUPPLIES', 'Cosas de casa'),
  other('OTHER', 'Otros');

  const ExpenseCategory(this.api, this.label);

  final String api;
  final String label;

  static ExpenseCategory fromApi(String value) =>
      values.firstWhere((c) => c.api == value, orElse: () => ExpenseCategory.other);
}

class Share {
  const Share({required this.userId, required this.amount});

  factory Share.fromJson(Json json) => Share(userId: json['userId'] as String, amount: Money.fromJson(json['amount']));

  final String userId;
  final Decimal amount;
}

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.currency,
    required this.description,
    required this.category,
    required this.date,
    required this.paidBy,
    required this.createdBy,
    required this.splitPolicyApplied,
    required this.shares,
    required this.warnings,
  });

  factory Expense.fromJson(Json json) => Expense(
    id: json['id'] as String,
    amount: Money.fromJson(json['amount']),
    currency: json['currency'] as String,
    description: json['description'] as String,
    category: ExpenseCategory.fromApi(json['category'] as String),
    date: Dates.fromApi(json['date'] as String),
    paidBy: json['paidBy'] as String,
    createdBy: json['createdBy'] as String,
    splitPolicyApplied: json['splitPolicyApplied'] as String,
    shares: (json['shares'] as List).map((s) => Share.fromJson(s as Json)).toList(),
    warnings: (json['warnings'] as List? ?? const []).cast<String>(),
  );

  final String id;
  final Decimal amount;
  final String currency;
  final String description;
  final ExpenseCategory category;
  final DateTime date;
  final String paidBy;
  final String createdBy;
  final String splitPolicyApplied;
  final List<Share> shares;

  /// Códigos de aviso de la API (p. ej. `PROPORTIONAL_FALLBACK_NO_INCOME`).
  final List<String> warnings;

  /// Avisos en texto para la UI.
  List<String> get warningMessages => [
    for (final warning in warnings)
      switch (warning) {
        'PROPORTIONAL_FALLBACK_NO_INCOME' =>
          'Nadie tenía ingresos ese mes: se repartió a partes iguales en vez de proporcional.',
        _ => warning,
      },
  ];
}

/// Datos de un gasto nuevo, tal como los valida el formulario.
class NewExpense {
  const NewExpense({
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    required this.paidBy,
  });

  final Decimal amount;
  final String description;
  final ExpenseCategory category;
  final DateTime date;
  final String paidBy;

  Json toJson() => {
    'amount': Money.toJson(amount),
    'description': description.trim(),
    'category': category.api,
    'date': Dates.toApi(date),
    'paidBy': paidBy,
  };
}

class ExpensePage {
  const ExpensePage({required this.items, required this.page, required this.totalPages});

  final List<Expense> items;
  final int page;
  final int totalPages;

  bool get hasMore => page + 1 < totalPages;
}

class ExpensesRepository {
  ExpensesRepository(this._api);

  static const pageSize = 30;
  final ApiClient _api;

  Future<ExpensePage> list(String householdId, {int page = 0}) async {
    final json =
        await _api.get('/api/households/$householdId/expenses', query: {'page': page, 'size': pageSize}) as Json;
    return ExpensePage(
      items: (json['content'] as List).map((e) => Expense.fromJson(e as Json)).toList(),
      page: json['page'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  Future<Expense> create(String householdId, NewExpense expense) async =>
      Expense.fromJson(await _api.post('/api/households/$householdId/expenses', body: expense.toJson()) as Json);

  Future<void> delete(String householdId, String expenseId) =>
      _api.delete('/api/households/$householdId/expenses/$expenseId');
}

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(ref.watch(apiClientProvider)),
);

/// Primera página de gastos de un hogar; "cargar más" pide las siguientes desde la pantalla.
final expensesProvider = FutureProvider.family<ExpensePage, String>(
  (ref, householdId) => ref.watch(expensesRepositoryProvider).list(householdId),
);
