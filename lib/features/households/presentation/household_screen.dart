import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../balances/presentation/balances_tab.dart';
import '../../expenses/presentation/expenses_tab.dart';
import '../../../core/ui/motion.dart';
import '../../../core/ui/widgets.dart';
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

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> with SingleTickerProviderStateMixin {
  int _tab = 0;

  /// Transición al cambiar de pestaña (fundido y un leve desplazamiento). Se anima el IndexedStack
  /// entero, no cada pestaña, para no perder su estado (scroll, páginas cargadas).
  late final AnimationController _fade = AnimationController(vsync: this, duration: Motion.medium, value: 1);

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _select(int tab) {
    if (tab == _tab) {
      return;
    }
    setState(() => _tab = tab);
    if (!Motion.reduced(context)) {
      _fade.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(householdProvider(widget.householdId));
    final members = ref.watch(membersProvider(widget.householdId)).value ?? const <Member>[];
    final id = widget.householdId;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        titleSpacing: 0,
        title: _Title(household: household.value),
        actions: [
          if (members.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _select(3),
                child: _AvatarStack(members: members),
              ),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fade,
        builder: (context, child) {
          final t = Motion.curve.transform(_fade.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
          );
        },
        child: IndexedStack(
          index: _tab,
          children: [
            ExpensesTab(householdId: id),
            BalancesTab(householdId: id),
            TasksTab(householdId: id),
            HouseholdInfoTab(householdId: id),
          ],
        ),
      ),
      // Un único botón flotante en la pantalla (no uno por pestaña): así los mensajes inferiores lo
      // desplazan en vez de taparlo, y cambia con una transición al cambiar de pestaña.
      floatingActionButton: AnimatedSwitcher(
        duration: Motion.medium,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Motion.curve),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: switch (_tab) {
          0 => FloatingActionButton.extended(
            key: const ValueKey('new-expense'),
            heroTag: 'new-expense',
            onPressed: () => context.go('/households/$id/expenses/new'),
            icon: const Icon(Icons.add),
            label: const Text('Gasto'),
          ),
          2 => FloatingActionButton.extended(
            key: const ValueKey('new-task'),
            heroTag: 'new-task',
            onPressed: () => createTask(context, ref, id),
            icon: const Icon(Icons.add_task),
            label: const Text('Tarea'),
          ),
          _ => const SizedBox.shrink(key: ValueKey('none')),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Gastos',
          ),
          NavigationDestination(
            icon: Icon(Icons.balance_outlined),
            selectedIcon: Icon(Icons.balance),
            label: 'Balances',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tareas',
          ),
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Hogar'),
        ],
      ),
    );
  }
}

/// Nombre del hogar con una línea de contexto debajo (plan y miembros).
class _Title extends StatelessWidget {
  const _Title({required this.household});

  final Household? household;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = household;
    if (h == null) {
      return const SizedBox.shrink();
    }
    final members = h.memberCount == 1 ? '1 miembro' : '${h.memberCount} miembros';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge),
        Text(
          'Plan ${h.plan} · $members',
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Avatares superpuestos de los primeros miembros (y "+N" si hay más).
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.members});

  final List<Member> members;

  static const _max = 3;
  static const _radius = 15.0;

  /// Solape mínimo: lo justo para que se vean agrupados sin tapar las iniciales del de al lado.
  static const _step = _radius * 2 - 2;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(_max).toList();
    final extra = members.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    final ring = Theme.of(context).colorScheme.surface;
    Widget ringed(Widget child) => Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
      child: child,
    );
    return Semantics(
      label: '${members.length} miembros',
      child: SizedBox(
        width: _radius * 2 + 4 + (count - 1) * _step,
        height: _radius * 2 + 4,
        child: Stack(
          children: [
            for (final (i, m) in shown.indexed)
              Positioned(
                left: i * _step,
                child: ringed(MemberAvatar(id: m.userId, name: m.displayName, radius: _radius)),
              ),
            if (extra > 0)
              Positioned(
                left: shown.length * _step,
                child: ringed(
                  CircleAvatar(
                    radius: _radius,
                    child: Text('+$extra', style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
              ),
          ],
        ),
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
