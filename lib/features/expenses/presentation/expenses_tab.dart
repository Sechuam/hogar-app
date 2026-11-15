import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/dates.dart';
import '../../auth/session_controller.dart';
import '../../balances/data/balances_repository.dart';
import '../../households/data/households_repository.dart';
import '../../households/presentation/household_screen.dart';
import '../data/expenses_repository.dart';

/// Gastos del hogar, los más recientes primero, con "cargar más".
class ExpensesTab extends ConsumerStatefulWidget {
  const ExpensesTab({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  /// Páginas siguientes a la primera, pedidas con "cargar más".
  final List<ExpensePage> _more = [];
  bool _loadingMore = false;

  String get _id => widget.householdId;

  Future<void> _refresh() async {
    setState(_more.clear);
    ref
      ..invalidate(planProvider(_id))
      ..invalidate(membersProvider(_id));
    ref.invalidate(expensesProvider(_id));
    await ref.read(expensesProvider(_id).future);
  }

  Future<void> _loadMore(ExpensePage last) async {
    setState(() => _loadingMore = true);
    try {
      final next = await ref.read(expensesRepositoryProvider).list(_id, page: last.page + 1);
      setState(() => _more.add(next));
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Una nueva primera página (alta o borrado de un gasto) invalida las siguientes.
    ref.listen(expensesProvider(_id), (_, _) => setState(_more.clear));
    final first = ref.watch(expensesProvider(_id));
    final members = ref.watch(membersProvider(_id)).value ?? const <Member>[];
    final plan = ref.watch(planProvider(_id)).value;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-expense',
        onPressed: () => context.go('/households/$_id/expenses/new'),
        icon: const Icon(Icons.add),
        label: const Text('Gasto'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AsyncView(
          value: first,
          onRetry: () => ref.invalidate(expensesProvider(_id)),
          data: (page) {
            final pages = [page, ..._more];
            final expenses = [for (final p in pages) ...p.items];
            final last = pages.last;
            if (expenses.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(icon: Icons.receipt_long_outlined, message: 'Todavía no hay gastos.\nApunta el primero.'),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final expense in expenses)
                  _ExpenseTile(expense: expense, members: members, onTap: () => _details(expense, members)),
                if (last.hasMore)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _loadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton(onPressed: () => _loadMore(last), child: const Text('Cargar más')),
                    ),
                  ),
                if (!last.hasMore && plan?.historyStart != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Plan FREE: se muestran los gastos desde el ${Dates.format(plan!.historyStart!)}. '
                      'Los balances siempre incluyen todo el histórico.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _details(Expense expense, List<Member> members) async {
    final household = ref.read(householdProvider(_id)).value;
    final me = ref.read(sessionProvider).value?.id;
    final canDelete = me == expense.paidBy || me == expense.createdBy || (household?.isOwner ?? false);
    final delete = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ExpenseDetails(expense: expense, members: members, canDelete: canDelete),
    );
    if (delete != true || !mounted) {
      return;
    }
    final ok = await confirm(
      context,
      title: 'Borrar gasto',
      message: '¿Borrar "${expense.description}"? Los balances se recalcularán.',
      confirmLabel: 'Borrar',
    );
    if (!ok) {
      return;
    }
    try {
      await ref.read(expensesRepositoryProvider).delete(_id, expense.id);
      ref
        ..invalidate(expensesProvider(_id))
        ..invalidate(balancesProvider(_id))
        ..invalidate(suggestedTransfersProvider(_id));
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }
}

IconData categoryIcon(ExpenseCategory category) => switch (category) {
  ExpenseCategory.rent => Icons.key_outlined,
  ExpenseCategory.groceries => Icons.shopping_cart_outlined,
  ExpenseCategory.electricity => Icons.bolt_outlined,
  ExpenseCategory.water => Icons.water_drop_outlined,
  ExpenseCategory.gas => Icons.local_fire_department_outlined,
  ExpenseCategory.internet => Icons.wifi,
  ExpenseCategory.cleaning => Icons.cleaning_services_outlined,
  ExpenseCategory.homeSupplies => Icons.chair_outlined,
  ExpenseCategory.other => Icons.category_outlined,
};

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.members, required this.onTap});

  final Expense expense;
  final List<Member> members;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Icon(categoryIcon(expense.category))),
      title: Text(expense.description),
      subtitle: Text('Pagó ${memberName(members, expense.paidBy)} · ${Dates.format(expense.date)}'),
      trailing: Text(Money.format(expense.amount, expense.currency), style: Theme.of(context).textTheme.titleMedium),
      onTap: onTap,
    );
  }
}

class _ExpenseDetails extends StatelessWidget {
  const _ExpenseDetails({required this.expense, required this.members, required this.canDelete});

  final Expense expense;
  final List<Member> members;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policy = expense.splitPolicyApplied == 'PROPORTIONAL' ? 'proporcional a ingresos' : 'a partes iguales';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense.description, style: theme.textTheme.titleLarge),
            Text(
              '${expense.category.label} · ${Dates.format(expense.date)} · '
              'pagó ${memberName(members, expense.paidBy)}',
            ),
            const SizedBox(height: 16),
            Text('Reparto $policy', style: theme.textTheme.titleSmall),
            for (final share in expense.shares)
              Row(
                children: [
                  Expanded(child: Text(memberName(members, share.userId))),
                  Text(Money.format(share.amount, expense.currency)),
                ],
              ),
            for (final warning in expense.warningMessages)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(warning, style: theme.textTheme.bodySmall),
              ),
            if (canDelete) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Borrar gasto'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
