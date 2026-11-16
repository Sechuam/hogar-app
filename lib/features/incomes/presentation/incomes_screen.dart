import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/dates.dart';
import '../../../core/ui/widgets.dart';
import '../../households/data/households_repository.dart';
import '../../households/presentation/household_screen.dart';
import '../data/incomes_repository.dart';

/// Ingresos del hogar mes a mes (la base del reparto proporcional) y los ingresos propios.
class IncomesScreen extends ConsumerStatefulWidget {
  const IncomesScreen({super.key, required this.householdId, this.initialMonth});

  final String householdId;

  /// Para tests; por defecto, el mes actual.
  final DateTime? initialMonth;

  @override
  ConsumerState<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends ConsumerState<IncomesScreen> {
  late DateTime _month = Dates.monthOf(widget.initialMonth ?? Dates.today());

  String get _id => widget.householdId;

  /// Un ingreso cambia el resumen de cualquier mes: se descartan todos los meses en caché.
  void _invalidate() {
    ref
      ..invalidate(myIncomesProvider(_id))
      ..invalidate(incomeSummaryProvider);
  }

  Future<void> _edit([Income? income]) async {
    final repository = ref.read(incomesRepositoryProvider);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => IncomeForm(
        initial: income,
        onSave: (value) => income == null ? repository.create(_id, value) : repository.update(_id, income.id, value),
      ),
    );
    if (saved ?? false) {
      _invalidate();
    }
  }

  Future<void> _delete(Income income) async {
    final ok = await confirm(
      context,
      title: 'Borrar ingreso',
      message: '¿Borrar "${income.concept}"? Los gastos ya creados mantienen su reparto.',
      confirmLabel: 'Borrar',
    );
    if (!ok) {
      return;
    }
    try {
      await ref.read(incomesRepositoryProvider).delete(_id, income.id);
      _invalidate();
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(incomeSummaryProvider((_id, _month)));
    final mine = ref.watch(myIncomesProvider(_id));
    final members = ref.watch(membersProvider(_id)).value ?? const <Member>[];
    final household = ref.watch(householdProvider(_id)).value;
    final currency = household?.currency ?? 'EUR';

    return Scaffold(
      appBar: AppBar(title: const Text('Ingresos')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-income',
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Ingreso'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _invalidate();
          await ref.read(myIncomesProvider(_id).future);
        },
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
            children: [
              if (household != null && household.splitPolicy != 'PROPORTIONAL')
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Este hogar reparte a partes iguales'),
                    subtitle: Text('Los ingresos solo cuentan si el reparto es proporcional (en la pestaña Hogar).'),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Mes anterior',
                    onPressed: () => setState(() => _month = Dates.addMonths(_month, -1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      Dates.formatMonth(_month),
                      key: const Key('month'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mes siguiente',
                    onPressed: () => setState(() => _month = Dates.addMonths(_month, 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              AsyncView(
                value: summary,
                onRetry: () => ref.invalidate(incomeSummaryProvider((_id, _month))),
                data: (s) => _SummaryCard(summary: s, members: members),
              ),
              const SectionHeader('Mis ingresos'),
              AsyncView(
                value: mine,
                onRetry: () => ref.invalidate(myIncomesProvider(_id)),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        icon: Icons.savings_outlined,
                        message: 'Aún no has apuntado ingresos. Añade tu nómina como recurrente y contará cada mes.',
                      )
                    : Card(
                        child: Column(
                          children: [
                            for (final income in list)
                              ListTile(
                                title: Text(income.concept),
                                subtitle: Text(income.period),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AmountText(income.amount, currency, style: Theme.of(context).textTheme.titleSmall),
                                    IconButton(
                                      tooltip: 'Borrar',
                                      onPressed: () => _delete(income),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                onTap: () => _edit(income),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.members});

  final IncomeSummary summary;
  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = theme.colorScheme.onPrimaryContainer;
    return HighlightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ingresos del hogar', style: theme.textTheme.labelLarge?.copyWith(color: on)),
          const SizedBox(height: 4),
          AmountText(summary.total, summary.currency, style: theme.textTheme.headlineMedium?.copyWith(color: on)),
          if (summary.total == Decimal.zero)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Nadie tiene ingresos este mes: los gastos proporcionales se reparten a partes iguales.',
                style: theme.textTheme.bodySmall?.copyWith(color: on),
              ),
            ),
          const SizedBox(height: 8),
          for (final m in summary.members)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  MemberAvatar(
                    id: m.userId,
                    name: memberName(members, m.userId, unknown: '…'),
                    radius: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                memberName(members, m.userId, unknown: '…'),
                                style: TextStyle(color: on, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '${Money.format(m.amount, summary.currency)} · ${_percent(m.percentage)}',
                              style: TextStyle(color: on, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: m.percentage.toDouble() / 100,
                          color: on,
                          backgroundColor: on.withValues(alpha: 0.15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// `62.50` → `62,5 %`; `100.00` → `100 %`. Solo para mostrar: el cálculo es de la API.
  static String _percent(Decimal value) {
    var text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    return '${text.replaceAll('.', ',')} %';
  }
}

/// Alta o edición de un ingreso propio. Guarda ella misma para poder mostrar en cada campo los
/// errores de validación de la API; devuelve `true` si guardó.
class IncomeForm extends StatefulWidget {
  const IncomeForm({super.key, this.initial, required this.onSave});

  final Income? initial;
  final Future<Object?> Function(NewIncome income) onSave;

  @override
  State<IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends State<IncomeForm> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.initial?.amount.toStringAsFixed(2).replaceAll('.', ','));
  late final _concept = TextEditingController(text: widget.initial?.concept);
  late DateTime _date = widget.initial?.date ?? Dates.today();
  late bool _recurring = widget.initial?.recurring ?? true;
  late DateTime? _endDate = widget.initial?.endDate;
  bool _saving = false;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _amount.dispose();
    _concept.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial, {DateTime? first}) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2000),
    lastDate: Dates.today().add(const Duration(days: 365 * 10)),
  );

  Future<void> _save() async {
    setState(() => _fieldErrors = const {});
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        NewIncome(
          amount: Money.parseInput(_amount.text)!,
          concept: _concept.text,
          date: _date,
          recurring: _recurring,
          endDate: _endDate,
        ),
      );
      if (mounted) {
        Navigator.pop(context, true);
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
    final endDateError = _fieldErrors['endDate'] ?? _fieldErrors['endDateValid'];
    // Con scroll: en pantallas bajas o con el teclado abierto el formulario no cabe.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? 'Nuevo ingreso' : 'Editar ingreso',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextFormField(
              key: const Key('incomeConcept'),
              controller: _concept,
              decoration: InputDecoration(labelText: 'Concepto', errorText: _fieldErrors['concept']),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el concepto (p. ej. Nómina)' : null,
            ),
            TextFormField(
              key: const Key('incomeAmount'),
              controller: _amount,
              decoration: InputDecoration(labelText: 'Importe', errorText: _fieldErrors['amount']),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => Money.parseInput(v ?? '') == null
                  ? 'Escribe un importe mayor que 0 con 2 decimales como mucho'
                  : null,
            ),
            SwitchListTile(
              key: const Key('incomeRecurring'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Se repite cada mes'),
              value: _recurring,
              onChanged: (v) => setState(() => _recurring = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_recurring ? 'Desde' : 'Fecha'),
              subtitle: Text(Dates.format(_date), style: TextStyle(color: _errorColor(_fieldErrors['date']))),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await _pick(_date);
                if (picked != null) {
                  setState(() {
                    _date = picked;
                    if (_endDate != null && _endDate!.isBefore(picked)) {
                      _endDate = null;
                    }
                  });
                }
              },
            ),
            if (_recurring)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hasta'),
                subtitle: Text(
                  endDateError ?? (_endDate == null ? 'Sin fecha de fin' : Dates.format(_endDate!)),
                  style: TextStyle(color: _errorColor(endDateError)),
                ),
                trailing: _endDate == null
                    ? const Icon(Icons.event_outlined)
                    : IconButton(
                        tooltip: 'Quitar fecha de fin',
                        onPressed: () => setState(() => _endDate = null),
                        icon: const Icon(Icons.close),
                      ),
                onTap: () async {
                  final picked = await _pick(_endDate ?? _date, first: _date);
                  if (picked != null) {
                    setState(() => _endDate = picked);
                  }
                },
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('incomeSave'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Color? _errorColor(String? error) => error == null ? null : Theme.of(context).colorScheme.error;
}
