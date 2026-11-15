import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/ui/dates.dart';

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.splitPolicy,
    required this.plan,
    required this.currency,
    required this.myRole,
    required this.memberCount,
  });

  factory Household.fromJson(Json json) => Household(
    id: json['id'] as String,
    name: json['name'] as String,
    splitPolicy: json['splitPolicy'] as String,
    plan: json['plan'] as String,
    currency: json['currency'] as String,
    myRole: json['myRole'] as String,
    memberCount: json['memberCount'] as int,
  );

  final String id;
  final String name;

  /// `EQUAL` o `PROPORTIONAL`.
  final String splitPolicy;

  /// `FREE` o `PREMIUM`.
  final String plan;
  final String currency;

  /// `OWNER` o `MEMBER`.
  final String myRole;
  final int memberCount;

  bool get isOwner => myRole == 'OWNER';
}

class Member {
  const Member({required this.userId, required this.displayName, required this.email, required this.role});

  factory Member.fromJson(Json json) => Member(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
  );

  final String userId;
  final String displayName;
  final String email;
  final String role;
}

class Invitation {
  const Invitation({required this.code, required this.expiresAt});

  factory Invitation.fromJson(Json json) =>
      Invitation(code: json['code'] as String, expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal());

  final String code;
  final DateTime expiresAt;
}

/// Plan del hogar con sus límites (`null` = sin límite) y el uso actual.
class PlanInfo {
  const PlanInfo({
    required this.plan,
    required this.maxMembers,
    required this.maxStorageBytes,
    required this.historyMonths,
    required this.members,
    required this.storageBytes,
    required this.historyStart,
  });

  factory PlanInfo.fromJson(Json json) {
    final limits = json['limits'] as Json;
    final usage = json['usage'] as Json;
    return PlanInfo(
      plan: json['plan'] as String,
      maxMembers: limits['maxMembers'] as int?,
      maxStorageBytes: limits['maxStorageBytes'] as int?,
      historyMonths: limits['historyMonths'] as int?,
      members: usage['members'] as int,
      storageBytes: usage['storageBytes'] as int,
      historyStart: Dates.fromApiOrNull(usage['historyStart']),
    );
  }

  final String plan;
  final int? maxMembers;
  final int? maxStorageBytes;
  final int? historyMonths;
  final int members;
  final int storageBytes;
  final DateTime? historyStart;

  bool get isPremium => plan == 'PREMIUM';
}

class HouseholdsRepository {
  HouseholdsRepository(this._api);

  final ApiClient _api;

  Future<List<Household>> mine() async =>
      (await _api.get('/api/households') as List).map((h) => Household.fromJson(h as Json)).toList();

  Future<Household> get(String id) async => Household.fromJson(await _api.get('/api/households/$id') as Json);

  Future<Household> create(String name, {String splitPolicy = 'EQUAL'}) async => Household.fromJson(
    await _api.post('/api/households', body: {'name': name.trim(), 'splitPolicy': splitPolicy}) as Json,
  );

  Future<Household> join(String code) async =>
      Household.fromJson(await _api.post('/api/invitations/${Uri.encodeComponent(code.trim())}/accept') as Json);

  Future<List<Member>> members(String householdId) async =>
      (await _api.get('/api/households/$householdId/members') as List).map((m) => Member.fromJson(m as Json)).toList();

  Future<Invitation> invite(String householdId) async =>
      Invitation.fromJson(await _api.post('/api/households/$householdId/invitations', body: const {}) as Json);

  Future<PlanInfo> plan(String householdId) async =>
      PlanInfo.fromJson(await _api.get('/api/households/$householdId/plan') as Json);

  /// Cambia la política de reparto de los gastos nuevos (solo OWNER; los ya creados no cambian).
  Future<Household> updateSplitPolicy(String householdId, String splitPolicy) async =>
      Household.fromJson(await _api.patch('/api/households/$householdId', body: {'splitPolicy': splitPolicy}) as Json);

  Future<void> leave(String householdId) => _api.post('/api/households/$householdId/leave');
}

final householdsRepositoryProvider = Provider<HouseholdsRepository>(
  (ref) => HouseholdsRepository(ref.watch(apiClientProvider)),
);

final myHouseholdsProvider = FutureProvider<List<Household>>((ref) => ref.watch(householdsRepositoryProvider).mine());

final householdProvider = FutureProvider.family<Household, String>(
  (ref, id) => ref.watch(householdsRepositoryProvider).get(id),
);

final membersProvider = FutureProvider.family<List<Member>, String>(
  (ref, householdId) => ref.watch(householdsRepositoryProvider).members(householdId),
);

final planProvider = FutureProvider.family<PlanInfo, String>(
  (ref, householdId) => ref.watch(householdsRepositoryProvider).plan(householdId),
);
