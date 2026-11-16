import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/charts.dart';
import '../../../core/ui/dates.dart';
import '../../../core/ui/motion.dart';
import '../../../core/ui/widgets.dart';
import '../../auth/session_controller.dart';
import '../../balances/data/balances_repository.dart';
import '../../households/data/households_repository.dart';
import '../../households/presentation/household_screen.dart';
import '../../invoices/presentation/invoice_section.dart';
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AsyncView(
          value: first,
          loading: const SkeletonList(),
          onRetry: () => ref.invalidate(expensesProvider(_id)),
          data: (page) {
            final pages = [page, ..._more];
            final expenses = [for (final p in pages) ...p.items];
            final last = pages.last;
            if (expenses.isEmpty) {
              return ListView(
                children: [
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Todavía no hay gastos',
                    message: 'Apunta la compra, el alquiler o la luz y Hogar calcula quién debe a quién.',
                    action: FilledButton.icon(
                      onPressed: () => context.go('/households/$_id/expenses/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Apuntar un gasto'),
                    ),
                  ),
                ],
              );
            }
            final me = ref.watch(sessionProvider).value?.id;
            final month = _monthSummary(expenses, last, me);
            final byDay = <DateTime, List<Expense>>{};
            for (final expense in expenses) {
              byDay.putIfAbsent(expense.date, () => []).add(expense);
            }
            return ContentWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                children: [
                  if (month != null)
                    Appear(
                      child: _MonthCard(summary: month, currency: expenses.first.currency),
                    ),
                  for (final (g, MapEntry(key: day, value: items)) in byDay.entries.indexed)
                    Appear(
                      index: g + 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(Dates.relativeDay(day)),
                          Card(
                            child: Column(
                              children: [
                                for (final (i, expense) in items.indexed) ...[
                                  if (i > 0) const Divider(indent: 72),
                                  _ExpenseTile(
                                    expense: expense,
                                    members: members,
                                    mine: expense.paidBy == me,
                                    onTap: () => _details(expense, members),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (last.hasMore)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _loadingMore
                            ? const CircularProgressIndicator()
                            : OutlinedButton.icon(
                                onPressed: () => _loadMore(last),
                                icon: const Icon(Icons.expand_more),
                                label: const Text('Cargar más'),
                              ),
                      ),
                    ),
                  if (!last.hasMore && plan?.historyStart != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Plan FREE: se muestran los gastos desde el ${Dates.format(plan!.historyStart!)}. '
                              'Los balances siempre incluyen todo el histórico.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Total del mes en curso, solo si ya están cargados todos sus gastos (la lista va por fecha
  /// descendente): con una página a medias el total sería engañoso.
  _MonthSummary? _monthSummary(List<Expense> expenses, ExpensePage last, String? me) {
    final start = Dates.monthOf(Dates.today());
    final complete = !last.hasMore || expenses.last.date.isBefore(start);
    if (!complete) {
      return null;
    }
    final current = expenses.where((e) => !e.date.isBefore(start)).toList();
    final byCategory = <ExpenseCategory, Decimal>{};
    for (final e in current) {
      byCategory.update(e.category, (sum) => sum + e.amount, ifAbsent: () => e.amount);
    }
    return _MonthSummary(
      month: start,
      count: current.length,
      total: current.fold(Decimal.zero, (sum, e) => sum + e.amount),
      paidByMe: current.where((e) => e.paidBy == me).fold(Decimal.zero, (sum, e) => sum + e.amount),
      // De mayor a menor: la barra y la leyenda empiezan por lo que más pesa.
      byCategory: byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Future<void> _details(Expense expense, List<Member> members) async {
    final household = ref.read(householdProvider(_id)).value;
    final me = ref.read(sessionProvider).value?.id;
    final canDelete = me == expense.paidBy || me == expense.createdBy || (household?.isOwner ?? false);
    final delete = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ExpenseDetails(
        householdId: _id,
        expense: expense,
        members: members,
        canDelete: canDelete,
        // El icono de la lista refleja la factura al momento.
        onInvoiceChanged: () => ref.invalidate(expensesProvider(_id)),
      ),
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

/// Color de cada categoría, legible en tema claro y oscuro.
Color categoryColor(ExpenseCategory category, Brightness brightness) {
  final hue = switch (category) {
    ExpenseCategory.rent => 265.0,
    ExpenseCategory.groceries => 140.0,
    ExpenseCategory.electricity => 45.0,
    ExpenseCategory.water => 200.0,
    ExpenseCategory.gas => 15.0,
    ExpenseCategory.internet => 225.0,
    ExpenseCategory.cleaning => 175.0,
    ExpenseCategory.homeSupplies => 320.0,
    ExpenseCategory.other => 0.0,
  };
  final saturation = category == ExpenseCategory.other ? 0.0 : 0.6;
  return HSLColor.fromAHSL(1, hue, saturation, brightness == Brightness.light ? 0.38 : 0.70).toColor();
}

class _MonthSummary {
  const _MonthSummary({
    required this.month,
    required this.count,
    required this.total,
    required this.paidByMe,
    required this.byCategory,
  });

  final DateTime month;
  final int count;
  final Decimal total;
  final Decimal paidByMe;
  final List<MapEntry<ExpenseCategory, Decimal>> byCategory;
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.summary, required this.currency});

  final _MonthSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = theme.colorScheme.onPrimaryContainer;
    final count = summary.count == 1 ? '1 gasto' : '${summary.count} gastos';
    return HighlightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gastado en ${Dates.formatMonth(summary.month)}',
            style: theme.textTheme.labelLarge?.copyWith(color: on),
          ),
          const SizedBox(height: 4),
          AnimatedAmount(summary.total, currency, style: theme.textTheme.headlineMedium?.copyWith(color: on)),
          const SizedBox(height: 4),
          Text(
            '$count · has pagado ${Money.format(summary.paidByMe, currency)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: on.withValues(alpha: 0.8)),
          ),
          if (summary.total > Decimal.zero) ...[
            const SizedBox(height: 16),
            SegmentBar(
              segments: [
                for (final MapEntry(key: category, value: amount) in summary.byCategory)
                  Segment(
                    weight: (amount * Decimal.fromInt(100)).toBigInt().toInt(),
                    color: categoryColor(category, theme.brightness),
                    label: category.label,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final MapEntry(key: category, value: amount) in summary.byCategory.take(3))
                  _Legend(
                    color: categoryColor(category, theme.brightness),
                    text: '${category.label} ${_percent(amount, summary.total)}',
                    textColor: on,
                  ),
                if (summary.byCategory.length > 3)
                  _Legend(
                    color: on.withValues(alpha: 0.4),
                    text: '+${summary.byCategory.length - 3} más',
                    textColor: on,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Porcentaje entero de [part] sobre [total] (`42 %`), redondeado: solo es una pista visual.
String _percent(Decimal part, Decimal total) {
  final value = (part * Decimal.fromInt(100) / total).toDecimal(scaleOnInfinitePrecision: 0).round();
  return '$value %';
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text, required this.textColor});

  final Color color;
  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: textColor)),
    ],
  );
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.members, required this.mine, required this.onTap});

  final Expense expense;
  final List<Member> members;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: TonalIcon(categoryIcon(expense.category), color: categoryColor(expense.category, theme.brightness)),
      title: Text(expense.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              mine ? 'Pagaste tú' : 'Pagó ${memberName(members, expense.paidBy)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (expense.hasInvoice) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Con factura',
              child: Icon(
                Icons.receipt_long_outlined,
                key: const Key('hasInvoice'),
                size: 16,
                color: theme.colorScheme.primary,
                semanticLabel: 'Con factura',
              ),
            ),
          ],
        ],
      ),
      trailing: AmountText(expense.amount, expense.currency),
      onTap: onTap,
    );
  }
}

class _ExpenseDetails extends StatelessWidget {
  const _ExpenseDetails({
    required this.householdId,
    required this.expense,
    required this.members,
    required this.canDelete,
    required this.onInvoiceChanged,
  });

  final String householdId;
  final VoidCallback onInvoiceChanged;
  final Expense expense;
  final List<Member> members;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final proportional = expense.splitPolicyApplied == 'PROPORTIONAL';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TonalIcon(
                  categoryIcon(expense.category),
                  color: categoryColor(expense.category, theme.brightness),
                  size: 52,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense.description, style: theme.textTheme.titleLarge),
                      Text(
                        '${expense.category.label} · ${Dates.format(expense.date)}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AmountText(expense.amount, expense.currency, style: theme.textTheme.headlineMedium),
            Text(
              'Pagó ${memberName(members, expense.paidBy)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            SectionHeader(
              'Reparto ${proportional ? 'proporcional a ingresos' : 'a partes iguales'}',
              padding: const EdgeInsets.only(top: 24, bottom: 8),
            ),
            for (final share in expense.shares)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    MemberAvatar(id: share.userId, name: memberName(members, share.userId), radius: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(memberName(members, share.userId)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: expense.amount == Decimal.zero ? 0 : (share.amount / expense.amount).toDouble(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AmountText(share.amount, expense.currency, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            for (final warning in expense.warningMessages)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: scheme.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(warning, style: TextStyle(color: scheme.onSecondaryContainer)),
                    ),
                  ],
                ),
              ),
            // Quien puede borrar el gasto es quien puede tocar su factura (misma regla en la API).
            InvoiceSection(
              householdId: householdId,
              expenseId: expense.id,
              canEdit: canDelete,
              onChanged: onInvoiceChanged,
            ),
            if (canDelete) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error, minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Borrar gasto'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
