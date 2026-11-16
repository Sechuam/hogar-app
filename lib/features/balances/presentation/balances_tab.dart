import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/dates.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../auth/session_controller.dart';
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

    final me = ref.watch(sessionProvider).value?.id;

    return RefreshIndicator(
      onRefresh: refresh,
      child: AsyncView(
        value: balances,
        onRetry: refresh,
        data: (b) {
          final mine = b.members.where((m) => m.userId == me).firstOrNull;
          return ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (mine != null) _MyBalanceCard(balance: mine.balance, currency: b.currency),
                const SectionHeader('Saldos'),
                Card(
                  child: Column(
                    children: [
                      for (final (i, m) in b.members.indexed) ...[
                        if (i > 0) const Divider(indent: 72),
                        _BalanceRow(
                          name: memberName(members, m.userId, unknown: m.active ? '…' : 'Ex-miembro'),
                          balance: m,
                          currency: b.currency,
                        ),
                      ],
                    ],
                  ),
                ),
                const SectionHeader('Pagos sugeridos'),
                if (b.settled)
                  const EmptyState(icon: Icons.verified_outlined, message: 'Todo está saldado.')
                else
                  AsyncView(
                    value: transfers,
                    onRetry: () => ref.invalidate(suggestedTransfersProvider(householdId)),
                    data: (list) => Column(
                      children: [
                        for (final t in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TransferCard(
                              transfer: t,
                              from: memberName(members, t.fromUserId),
                              to: memberName(members, t.toUserId),
                              currency: b.currency,
                              onSettle: () => _settle(context, ref, t, members, b.currency),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Son los pagos mínimos para quedar en paz. La app no mueve dinero: '
                            'cuando alguien pague, regístralo aquí.',
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

class _MyBalanceCard extends StatelessWidget {
  const _MyBalanceCard({required this.balance, required this.currency});

  final Decimal balance;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = MoneyColors.of(context);
    final (label, icon, background) = balance > Decimal.zero
        ? ('Te deben', Icons.trending_up_rounded, colors.positiveContainer)
        : balance < Decimal.zero
        ? ('Debes', Icons.trending_down_rounded, colors.negativeContainer)
        : ('Estás en paz', Icons.check_circle_outline_rounded, theme.colorScheme.secondaryContainer);
    final foreground = balance > Decimal.zero
        ? colors.positive
        : balance < Decimal.zero
        ? colors.negative
        : theme.colorScheme.onSecondaryContainer;
    return HighlightCard(
      color: background,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu saldo', style: theme.textTheme.labelLarge?.copyWith(color: foreground)),
                const SizedBox(height: 4),
                Text(label, style: theme.textTheme.titleMedium?.copyWith(color: foreground)),
                if (balance != Decimal.zero)
                  AmountText(
                    balance.abs(),
                    currency,
                    style: theme.textTheme.headlineMedium?.copyWith(color: foreground),
                  ),
              ],
            ),
          ),
          Icon(icon, size: 48, color: foreground.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.name, required this.balance, required this.currency});

  final String name;
  final MemberBalance balance;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final value = balance.balance;
    final label = value > Decimal.zero
        ? 'le deben'
        : value < Decimal.zero
        ? 'debe'
        : 'en paz';
    return ListTile(
      leading: Opacity(
        opacity: balance.active ? 1 : 0.5,
        child: MemberAvatar(id: balance.userId, name: name),
      ),
      title: Text(balance.active || name == 'Ex-miembro' ? name : '$name (ya no está)'),
      subtitle: Text(label),
      trailing: AmountText(value, currency, signed: true),
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MemberAvatar(id: transfer.fromUserId, name: from),
                Expanded(
                  child: Column(
                    children: [
                      AmountText(transfer.amount, currency),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(child: Divider(color: theme.colorScheme.outline)),
                          Icon(Icons.arrow_forward_rounded, size: 18, color: theme.colorScheme.outline),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
                MemberAvatar(id: transfer.toUserId, name: to),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('$from paga a $to', style: theme.textTheme.bodyMedium)),
                FilledButton.tonal(onPressed: onSettle, child: const Text('Registrar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
