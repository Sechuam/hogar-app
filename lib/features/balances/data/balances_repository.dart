import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/money/money.dart';
import '../../../core/providers.dart';
import '../../../core/ui/dates.dart';

class MemberBalance {
  const MemberBalance({required this.userId, required this.active, required this.balance});

  factory MemberBalance.fromJson(Json json) => MemberBalance(
    userId: json['userId'] as String,
    active: json['active'] as bool,
    balance: Money.fromJson(json['balance']),
  );

  final String userId;

  /// `false` si ya no es miembro (sus deudas siguen contando).
  final bool active;

  /// Positivo: le deben; negativo: debe.
  final Decimal balance;
}

class Balances {
  const Balances({required this.currency, required this.members, required this.settled});

  factory Balances.fromJson(Json json) => Balances(
    currency: json['currency'] as String,
    members: (json['members'] as List).map((m) => MemberBalance.fromJson(m as Json)).toList(),
    settled: json['settled'] as bool,
  );

  final String currency;
  final List<MemberBalance> members;
  final bool settled;
}

class Transfer {
  const Transfer({required this.fromUserId, required this.toUserId, required this.amount});

  factory Transfer.fromJson(Json json) => Transfer(
    fromUserId: json['fromUserId'] as String,
    toUserId: json['toUserId'] as String,
    amount: Money.fromJson(json['amount']),
  );

  final String fromUserId;
  final String toUserId;
  final Decimal amount;
}

class BalancesRepository {
  BalancesRepository(this._api);

  final ApiClient _api;

  Future<Balances> balances(String householdId) async =>
      Balances.fromJson(await _api.get('/api/households/$householdId/balances') as Json);

  Future<List<Transfer>> suggested(String householdId) async {
    final json = await _api.get('/api/households/$householdId/settlements/suggested') as Json;
    return (json['transfers'] as List).map((t) => Transfer.fromJson(t as Json)).toList();
  }

  /// Registra un pago ya hecho por fuera de la app (la app no mueve dinero).
  Future<void> settle(String householdId, Transfer transfer, DateTime date) => _api.post(
    '/api/households/$householdId/settlements',
    body: {
      'fromUserId': transfer.fromUserId,
      'toUserId': transfer.toUserId,
      'amount': Money.toJson(transfer.amount),
      'date': Dates.toApi(date),
    },
  );
}

final balancesRepositoryProvider = Provider<BalancesRepository>(
  (ref) => BalancesRepository(ref.watch(apiClientProvider)),
);

final balancesProvider = FutureProvider.family<Balances, String>(
  (ref, householdId) => ref.watch(balancesRepositoryProvider).balances(householdId),
);

final suggestedTransfersProvider = FutureProvider.family<List<Transfer>, String>(
  (ref, householdId) => ref.watch(balancesRepositoryProvider).suggested(householdId),
);
