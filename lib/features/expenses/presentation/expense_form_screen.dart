import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/dates.dart';
import '../../../core/ui/widgets.dart';
import '../../auth/session_controller.dart';
import '../../balances/data/balances_repository.dart';
import '../../households/data/households_repository.dart';
import '../data/expenses_repository.dart';
import 'expenses_tab.dart';

/// Alta de un gasto. El reparto lo calcula la API con la política del hogar.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, required this.householdId});

  final String householdId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.groceries;
  DateTime _date = Dates.today();
  String? _paidBy;
  bool _saving = false;
  Map<String, String> _fieldErrors = const {};

  String get _id => widget.householdId;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: Dates.today().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save(String paidBy) async {
    setState(() => _fieldErrors = const {});
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final expense = await ref
          .read(expensesRepositoryProvider)
          .create(
            _id,
            NewExpense(
              amount: Money.parseInput(_amount.text)!,
              description: _description.text,
              category: _category,
              date: _date,
              paidBy: paidBy,
            ),
          );
      ref
        ..invalidate(expensesProvider(_id))
        ..invalidate(balancesProvider(_id))
        ..invalidate(suggestedTransfersProvider(_id));
      if (mounted) {
        // El aviso se muestra en la pantalla del hogar, que es adonde se vuelve.
        final messenger = ScaffoldMessenger.of(context);
        context.go('/households/$_id');
        for (final warning in expense.warningMessages) {
          messenger.showSnackBar(SnackBar(content: Text(warning)));
        }
      }
    } on ApiException catch (e) {
      setState(() => _fieldErrors = e.fieldErrors);
      if (e.fieldErrors.isEmpty && mounted) {
        showError(context, e);
      }
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
    final members = ref.watch(membersProvider(_id));
    final me = ref.watch(sessionProvider).value?.id;
    final household = ref.watch(householdProvider(_id)).value;
    final currency = household?.currency ?? 'EUR';
    final proportional = household?.splitPolicy == 'PROPORTIONAL';

    final list = members.value;
    final paidBy = list == null || list.isEmpty
        ? null
        : _paidBy ?? (list.any((m) => m.userId == me) ? me : list.first.userId)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto')),
      // Fijo abajo: siempre visible, aunque el formulario no quepa en pantalla.
      bottomNavigationBar: paidBy == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ContentWidth(
                  child: FilledButton.icon(
                    key: const Key('save'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _saving ? null : () => _save(paidBy),
                    icon: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: const Text('Guardar gasto'),
                  ),
                ),
              ),
            ),
      body: AsyncView(
        value: members,
        onRetry: () => ref.invalidate(membersProvider(_id)),
        data: (list) {
          final theme = Theme.of(context);
          return Form(
            key: _form,
            child: ContentWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  TextFormField(
                    key: const Key('amount'),
                    controller: _amount,
                    autofocus: true,
                    style: theme.textTheme.headlineMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    decoration: InputDecoration(
                      labelText: 'Importe',
                      hintText: '0,00',
                      suffixText: currency == 'EUR' ? '€' : currency,
                      suffixStyle: theme.textTheme.headlineSmall,
                      errorText: _fieldErrors['amount'],
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => Money.parseInput(v ?? '') == null
                        ? 'Escribe un importe mayor que 0 con 2 decimales como mucho'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('description'),
                    controller: _description,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Compra semanal, luz de octubre…',
                      prefixIcon: const Icon(Icons.edit_note),
                      errorText: _fieldErrors['description'],
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 200,
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Describe el gasto' : null,
                  ),
                  const SectionHeader('Categoría', padding: EdgeInsets.fromLTRB(4, 4, 4, 8)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in ExpenseCategory.values)
                        ChoiceChip(
                          avatar: Icon(categoryIcon(c), color: categoryColor(c, theme.brightness)),
                          label: Text(c.label),
                          selected: _category == c,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                    ],
                  ),
                  const SectionHeader('Pagó'),
                  Wrap(
                    key: const Key('paidBy'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in list)
                        ChoiceChip(
                          avatar: MemberAvatar(id: m.userId, name: m.displayName, radius: 12),
                          label: Text(m.userId == me ? '${m.displayName} (yo)' : m.displayName),
                          selected: paidBy == m.userId,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _paidBy = m.userId),
                        ),
                    ],
                  ),
                  if (_fieldErrors['paidBy'] case final error?)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(error, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  const SectionHeader('Fecha'),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: Text(Dates.relativeDay(_date)),
                      subtitle: _fieldErrors['date'] != null
                          ? Text(_fieldErrors['date']!, style: TextStyle(color: theme.colorScheme.error))
                          : proportional
                          ? Text('Se reparte según los ingresos de ${Dates.formatMonth(Dates.monthOf(_date))}')
                          : Text(Dates.format(_date)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: _pickDate,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
