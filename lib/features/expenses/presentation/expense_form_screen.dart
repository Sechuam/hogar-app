import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/dates.dart';
import '../../auth/session_controller.dart';
import '../../balances/data/balances_repository.dart';
import '../../households/data/households_repository.dart';
import '../data/expenses_repository.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto')),
      body: AsyncView(
        value: members,
        onRetry: () => ref.invalidate(membersProvider(_id)),
        data: (list) {
          final paidBy = _paidBy ?? (list.any((m) => m.userId == me) ? me : list.first.userId)!;
          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  key: const Key('amount'),
                  controller: _amount,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Importe',
                    suffixText: currency == 'EUR' ? '€' : currency,
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
                  decoration: InputDecoration(labelText: 'Descripción', errorText: _fieldErrors['description']),
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 200,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Describe el gasto' : null,
                ),
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [for (final c in ExpenseCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
                  onChanged: (c) => setState(() => _category = c!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('paidBy'),
                  initialValue: paidBy,
                  decoration: InputDecoration(labelText: 'Pagó', errorText: _fieldErrors['paidBy']),
                  items: [
                    for (final m in list)
                      DropdownMenuItem(
                        value: m.userId,
                        child: Text(m.userId == me ? '${m.displayName} (yo)' : m.displayName),
                      ),
                  ],
                  onChanged: (v) => setState(() => _paidBy = v),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha',
                    errorText: _fieldErrors['date'],
                    helperText: proportional
                        ? 'Se reparte según los ingresos de ${Dates.formatMonth(Dates.monthOf(_date))}'
                        : null,
                  ),
                  child: InkWell(
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        Expanded(child: Text(Dates.format(_date))),
                        const Icon(Icons.calendar_today_outlined, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('save'),
                  onPressed: _saving ? null : () => _save(paidBy),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
