import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/dates.dart';
import '../../households/data/households_repository.dart';
import '../../households/presentation/household_screen.dart';
import '../data/balances_repository.dart';

/// Saldo de cada miembro y los pagos mínimos para quedar en paz. Registrar un pago solo lo anota:
/// la app no mueve dinero.
class BalancesTab extends ConsumerWidget {
  const BalancesTab({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(balancesProvider(householdId));
    final transfers = ref.watch(suggestedTransfersProvider(householdId));
    final members = ref.watch(membersProvider(householdId)).value ?? const <Member>[];

    final b = balances.value;
    if (b != null) {
      refreshMembersIfStale(ref, householdId, [
        for (final m in b.members)
          if (m.active) m.userId,
      ]);
    }

    Future<void> refresh() async {
      ref
        ..invalidate(membersProvider(householdId))
        ..invalidate(suggestedTransfersProvider(householdId));
      ref.invalidate(balancesProvider(householdId));
      await ref.read(balancesProvider(householdId).future);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: AsyncView(
        value: balances,
        onRetry: refresh,
        data: (b) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Saldos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final m in b.members)
                    _BalanceRow(
                      name: memberName(members, m.userId, unknown: m.active ? '…' : 'Ex-miembro'),
                      balance: m,
                      currency: b.currency,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Pagos sugeridos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (b.settled)
              const EmptyState(icon: Icons.verified_outlined, message: 'Todo está saldado.')
            else
              AsyncView(
                value: transfers,
                onRetry: () => ref.invalidate(suggestedTransfersProvider(householdId)),
                data: (list) => Column(
                  children: [
                    for (final t in list)
                      _TransferCard(
                        transfer: t,
                        from: memberName(members, t.fromUserId),
                        to: memberName(members, t.toUserId),
                        currency: b.currency,
                        onSettle: () => _settle(context, ref, t, members, b.currency),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _settle(
    BuildContext context,
    WidgetRef ref,
    Transfer transfer,
    List<Member> members,
    String currency,
  ) async {
    final from = memberName(members, transfer.fromUserId);
    final to = memberName(members, transfer.toUserId);
    final amount = Money.format(transfer.amount, currency);
    final ok = await confirm(
      context,
      title: 'Registrar pago',
      message:
          '¿$from ya ha pagado $amount a $to?\n\n'
          'La app no mueve dinero: solo anota el pago para actualizar los saldos.',
      confirmLabel: 'Registrar',
    );
    if (!ok) {
      return;
    }
    try {
      await ref.read(balancesRepositoryProvider).settle(householdId, transfer, Dates.today());
      ref
        ..invalidate(balancesProvider(householdId))
        ..invalidate(suggestedTransfersProvider(householdId));
      if (context.mounted) {
        showMessage(context, 'Pago registrado: $from → $to, $amount');
      }
    } catch (e) {
      if (context.mounted) {
        showError(context, e);
      }
    }
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.name, required this.balance, required this.currency});

  final String name;
  final MemberBalance balance;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = balance.balance;
    final (label, color) = value > Decimal.zero
        ? ('le deben', Colors.green.shade700)
        : value < Decimal.zero
        ? ('debe', scheme.error)
        : ('en paz', scheme.outline);
    return ListTile(
      title: Text(balance.active || name == 'Ex-miembro' ? name : '$name (ya no está)'),
      subtitle: Text(label),
      trailing: Text(
        Money.format(value, currency),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.transfer,
    required this.from,
    required this.to,
    required this.currency,
    required this.onSettle,
  });

  final Transfer transfer;
  final String from;
  final String to;
  final String currency;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: Text('$from paga a $to'),
        subtitle: Text(Money.format(transfer.amount, currency)),
        trailing: FilledButton.tonal(onPressed: onSettle, child: const Text('Registrar')),
      ),
    );
  }
}
