import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/ui/async_view.dart';
import '../../../core/ui/dates.dart';
import '../../auth/session_controller.dart';
import '../data/households_repository.dart';

/// Plan y uso, miembros, invitar y salir del hogar.
class HouseholdInfoTab extends ConsumerWidget {
  const HouseholdInfoTab({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(householdProvider(householdId));
    final members = ref.watch(membersProvider(householdId));
    final plan = ref.watch(planProvider(householdId));
    final me = ref.watch(sessionProvider).value?.id;

    Future<void> refresh() async {
      ref
        ..invalidate(householdProvider(householdId))
        ..invalidate(planProvider(householdId));
      ref.invalidate(membersProvider(householdId));
      await ref.read(membersProvider(householdId).future);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncView(
            value: plan,
            onRetry: refresh,
            data: (p) => PlanCard(plan: p),
          ),
          const SizedBox(height: 16),
          Text('Reparto de gastos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (household.value case final h?) SplitPolicyCard(household: h),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('Miembros', style: Theme.of(context).textTheme.titleMedium)),
              if (household.value?.isOwner ?? false)
                TextButton.icon(
                  onPressed: () => _invite(context, ref),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Invitar'),
                ),
            ],
          ),
          AsyncView(
            value: members,
            onRetry: refresh,
            data: (list) => Card(
              child: Column(
                children: [
                  for (final m in list)
                    ListTile(
                      leading: CircleAvatar(child: Text(m.displayName.characters.first.toUpperCase())),
                      title: Text(m.userId == me ? '${m.displayName} (yo)' : m.displayName),
                      subtitle: Text(m.email),
                      trailing: m.role == 'OWNER' ? const Chip(label: Text('Propietario')) : null,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _leave(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Salir del hogar'),
          ),
        ],
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    try {
      final invitation = await ref.read(householdsRepositoryProvider).invite(householdId);
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de invitación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                invitation.code,
                key: const Key('invitationCode'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              Text(
                'Válido hasta el ${Dates.format(invitation.expiresAt)}. '
                'Quien lo reciba lo usa en "Unirme con un código".',
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invitation.code));
                if (context.mounted) {
                  Navigator.pop(context);
                  showMessage(context, 'Código copiado');
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Hecho')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        showError(context, e);
      }
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Salir del hogar',
      message: 'Dejarás de ver este hogar. Tus gastos y saldos se conservan para el resto.',
      confirmLabel: 'Salir',
    );
    if (!ok) {
      return;
    }
    try {
      await ref.read(householdsRepositoryProvider).leave(householdId);
      ref.invalidate(myHouseholdsProvider);
      if (context.mounted) {
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) {
        showError(context, e);
      }
    }
  }
}

/// Política de reparto de los gastos nuevos (la cambia el OWNER) y acceso a los ingresos.
class SplitPolicyCard extends ConsumerStatefulWidget {
  const SplitPolicyCard({super.key, required this.household});

  final Household household;

  @override
  ConsumerState<SplitPolicyCard> createState() => _SplitPolicyCardState();
}

class _SplitPolicyCardState extends ConsumerState<SplitPolicyCard> {
  bool _saving = false;

  Future<void> _change(String policy) async {
    final proportional = policy == 'PROPORTIONAL';
    final ok = await confirm(
      context,
      title: proportional ? 'Reparto proporcional' : 'Reparto a partes iguales',
      message:
          '${proportional ? 'Cada gasto nuevo se repartirá según los ingresos de cada miembro en el mes del gasto.' : 'Cada gasto nuevo se repartirá a partes iguales.'}'
          '\n\nLos gastos ya creados conservan su reparto.',
      confirmLabel: 'Cambiar',
    );
    if (!ok) {
      return;
    }
    setState(() => _saving = true);
    try {
      final id = widget.household.id;
      await ref.read(householdsRepositoryProvider).updateSplitPolicy(id, policy);
      ref
        ..invalidate(householdProvider(id))
        ..invalidate(myHouseholdsProvider);
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.household;
    final proportional = h.splitPolicy == 'PROPORTIONAL';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'EQUAL', label: Text('A partes iguales'), icon: Icon(Icons.drag_handle)),
                ButtonSegment(
                  value: 'PROPORTIONAL',
                  label: Text('Según ingresos'),
                  icon: Icon(Icons.pie_chart_outline),
                ),
              ],
              selected: {h.splitPolicy},
              onSelectionChanged: h.isOwner && !_saving ? (s) => _change(s.single) : null,
            ),
            const SizedBox(height: 8),
            Text(
              [
                proportional
                    ? 'Cada uno paga en proporción a sus ingresos del mes del gasto.'
                    : 'Cada gasto se divide a partes iguales entre los miembros.',
                if (!h.isOwner) 'Solo el propietario puede cambiarlo.',
              ].join(' '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/households/${h.id}/incomes'),
              icon: const Icon(Icons.savings_outlined),
              label: const Text('Ingresos del hogar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plan del hogar con el uso frente a sus límites.
class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan});

  final PlanInfo plan;

  static String _megabytes(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Plan ${plan.plan}', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (plan.isPremium) const Icon(Icons.workspace_premium_outlined),
              ],
            ),
            if (plan.isPremium)
              const Text('Sin límites de miembros, facturas ni historial.')
            else ...[
              const SizedBox(height: 12),
              _Usage(
                label: 'Miembros',
                value: '${plan.members} de ${plan.maxMembers}',
                ratio: plan.members / plan.maxMembers!,
              ),
              _Usage(
                label: 'Facturas',
                value: '${_megabytes(plan.storageBytes)} de ${_megabytes(plan.maxStorageBytes!)}',
                ratio: plan.storageBytes / plan.maxStorageBytes!,
              ),
              if (plan.historyStart != null)
                Text(
                  'Historial visible desde el ${Dates.format(plan.historyStart!)}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Usage extends StatelessWidget {
  const _Usage({required this.label, required this.value, required this.ratio});

  final String label;
  final String value;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final full = ratio >= 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(value),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: ratio.clamp(0, 1), color: full ? Theme.of(context).colorScheme.error : null),
        ],
      ),
    );
  }
}
