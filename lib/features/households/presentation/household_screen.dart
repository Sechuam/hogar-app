import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../balances/presentation/balances_tab.dart';
import '../../expenses/presentation/expenses_tab.dart';
import '../../tasks/presentation/tasks_tab.dart';
import '../data/households_repository.dart';
import 'household_info_tab.dart';

/// Un hogar: gastos, balances, tareas y datos del hogar en pestañas.
class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(householdProvider(widget.householdId));
    final id = widget.householdId;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(household.value?.name ?? ''),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          ExpensesTab(householdId: id),
          BalancesTab(householdId: id),
          TasksTab(householdId: id),
          HouseholdInfoTab(householdId: id),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Gastos'),
          NavigationDestination(icon: Icon(Icons.balance_outlined), label: 'Balances'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), label: 'Tareas'),
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Hogar'),
        ],
      ),
    );
  }
}

/// Nombre de un miembro a partir de la lista de miembros activos; [unknown] si no está en ella (quien
/// dejó el hogar sigue apareciendo en gastos y saldos).
String memberName(List<Member> members, String userId, {String unknown = 'Ex-miembro'}) {
  for (final member in members) {
    if (member.userId == userId) {
      return member.displayName;
    }
  }
  return unknown;
}

/// Si otra pantalla dice que [activeUserIds] son miembros activos pero la lista de miembros en caché
/// no los tiene (alguien se unió después de cargarla), la recarga una vez.
void refreshMembersIfStale(WidgetRef ref, String householdId, Iterable<String> activeUserIds) {
  final members = ref.read(membersProvider(householdId));
  final known = members.value;
  if (known == null || members.isLoading) {
    return;
  }
  final missing = activeUserIds.where((id) => !known.any((m) => m.userId == id)).toList()..sort();
  // Una sola recarga por conjunto de ausentes: si siguen faltando, no se reintenta en bucle.
  if (missing.isNotEmpty && _membersReloadedFor.add('$householdId:${missing.join(',')}')) {
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidate(membersProvider(householdId)));
  }
}

final _membersReloadedFor = <String>{};
