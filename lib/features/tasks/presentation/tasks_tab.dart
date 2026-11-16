import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/charts.dart';
import '../../../core/ui/dates.dart';
import '../../../core/ui/motion.dart';
import '../../../core/ui/widgets.dart';
import '../../households/data/households_repository.dart';
import '../../households/presentation/household_screen.dart';
import '../data/tasks_repository.dart';

/// Tareas pendientes. Al completar una periódica, la API crea la siguiente repetición.
class TasksTab extends ConsumerWidget {
  const TasksTab({super.key, required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(pendingTasksProvider(householdId));
    final members = ref.watch(membersProvider(householdId)).value ?? const <Member>[];
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pendingTasksProvider(householdId).future),
        child: AsyncView(
          value: tasks,
          loading: const SkeletonList(highlight: true, cards: 2),
          onRetry: () => ref.invalidate(pendingTasksProvider(householdId)),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: [
                  EmptyState(
                    icon: Icons.task_alt,
                    title: 'Nada pendiente',
                    message: 'Apunta las tareas de casa; las periódicas se repiten solas al completarlas.',
                    action: FilledButton.icon(
                      onPressed: () => createTask(context, ref, householdId),
                      icon: const Icon(Icons.add_task),
                      label: const Text('Nueva tarea'),
                    ),
                  ),
                ],
              );
            }
            final today = Dates.today();
            final groups = <String, List<HouseTask>>{'Vencidas': [], 'Para hoy': [], 'Próximas': [], 'Sin fecha': []};
            for (final task in list) {
              final due = task.dueDate;
              final group = task.overdue || (due != null && due.isBefore(today))
                  ? 'Vencidas'
                  : due == null
                  ? 'Sin fecha'
                  : due == today
                  ? 'Para hoy'
                  : 'Próximas';
              groups[group]!.add(task);
            }
            final scheme = Theme.of(context).colorScheme;
            final visible = groups.entries.where((g) => g.value.isNotEmpty).toList();
            return ContentWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                children: [
                  Appear(
                    child: Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: '${groups['Vencidas']!.length}',
                            label: 'Vencidas',
                            icon: Icons.warning_amber_rounded,
                            color: groups['Vencidas']!.isEmpty ? scheme.outline : scheme.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            value: '${groups['Para hoy']!.length}',
                            label: 'Para hoy',
                            icon: Icons.today_rounded,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            value: '${groups['Próximas']!.length + groups['Sin fecha']!.length}',
                            label: 'Más adelante',
                            icon: Icons.event_note_rounded,
                            color: scheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final (g, MapEntry(key: title, value: tasks)) in visible.indexed)
                    Appear(
                      index: g + 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader('$title · ${tasks.length}'),
                          Card(
                            child: Column(
                              children: [
                                for (final (i, task) in tasks.indexed) ...[
                                  if (i > 0) const Divider(indent: 64),
                                  _TaskTile(
                                    key: ValueKey(task.id),
                                    task: task,
                                    members: members,
                                    onComplete: () => _complete(context, ref, task),
                                  ),
                                ],
                              ],
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

  Future<void> _complete(BuildContext context, WidgetRef ref, HouseTask task) async {
    try {
      await ref.read(tasksRepositoryProvider).complete(householdId, task);
      if (context.mounted) {
        final oneOff = task.recurrence == Recurrence.none;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(oneOff ? '"${task.title}" hecha' : '"${task.title}" hecha; se repetirá'),
              // Solo las puntuales se pueden reabrir (en una periódica ya existe la siguiente repetición).
              action: oneOff ? SnackBarAction(label: 'Deshacer', onPressed: () => _reopen(context, ref, task)) : null,
            ),
          );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        showError(context, e);
      }
    } finally {
      // También tras un 409 (otra persona la completó antes): se recarga el estado real.
      ref.invalidate(pendingTasksProvider(householdId));
    }
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref, HouseTask task) async {
    try {
      await ref.read(tasksRepositoryProvider).reopen(householdId, task.id);
    } on ApiException catch (e) {
      if (context.mounted) {
        showError(context, e);
      }
    } finally {
      ref.invalidate(pendingTasksProvider(householdId));
    }
  }
}

/// Hoja para crear una tarea y alta en la API. La usan la pestaña y el botón flotante de la pantalla
/// del hogar.
Future<void> createTask(BuildContext context, WidgetRef ref, String householdId) async {
  final members = ref.read(membersProvider(householdId)).value ?? const <Member>[];
  final task = await showModalBottomSheet<NewTask>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TaskForm(members: members),
  );
  if (task == null) {
    return;
  }
  try {
    await ref.read(tasksRepositoryProvider).create(householdId, task);
    ref.invalidate(pendingTasksProvider(householdId));
  } catch (e) {
    if (context.mounted) {
      showError(context, e);
    }
  }
}

/// Tarea pendiente. Al marcarla se ve hecha (tic y tachado) un instante y luego se completa: el
/// retraso lo marca la propia animación, no un temporizador.
class _TaskTile extends StatefulWidget {
  const _TaskTile({super.key, required this.task, required this.members, required this.onComplete});

  final HouseTask task;
  final List<Member> members;
  final VoidCallback onComplete;

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> with SingleTickerProviderStateMixin {
  late final AnimationController _done = AnimationController(vsync: this, duration: Motion.long);

  @override
  void didUpdateWidget(_TaskTile old) {
    super.didUpdateWidget(old);
    // Una tarea periódica completada vuelve con el mismo id y la fecha siguiente: es otra repetición,
    // así que se muestra pendiente de nuevo.
    if (old.task.dueDate != widget.task.dueDate) {
      _done.value = 0;
    }
  }

  @override
  void dispose() {
    _done.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_done.isAnimating || _done.isCompleted) {
      return;
    }
    if (!Motion.reduced(context)) {
      await _done.forward();
    }
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final members = widget.members;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final assignee = task.assigneeId;
    final details = [
      if (task.dueDate != null) Dates.shortDay(task.dueDate!),
      if (task.recurrence != Recurrence.none) task.recurrence.label.toLowerCase(),
    ];
    return AnimatedBuilder(
      animation: _done,
      builder: (context, child) {
        final checked = _done.value > 0;
        // Primera mitad: tic y tachado; segunda mitad: se desvanece.
        final fade = 1 - Curves.easeIn.transform(((_done.value - 0.5) * 2).clamp(0, 1));
        return Opacity(
          opacity: fade,
          child: ListTile(
            leading: Checkbox(
              value: checked,
              shape: const CircleBorder(),
              side: BorderSide(color: task.overdue ? scheme.error : scheme.outline, width: 2),
              onChanged: (_) => _check(),
            ),
            title: Text(
              task.title,
              style: checked ? TextStyle(decoration: TextDecoration.lineThrough, color: scheme.onSurfaceVariant) : null,
            ),
            subtitle: child,
            trailing: assignee == null
                ? null
                : MemberAvatar(id: assignee, name: memberName(members, assignee), radius: 16),
            onTap: _check,
          ),
        );
      },
      child: _subtitle(task, details, scheme),
    );
  }

  Widget? _subtitle(HouseTask task, List<String> details, ColorScheme scheme) {
    if (details.isEmpty) {
      return null;
    }
    return Row(
      children: [
        if (task.recurrence != Recurrence.none) ...[
          Icon(Icons.repeat_rounded, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            details.join(' · '),
            style: TextStyle(color: task.overdue ? scheme.error : null),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TaskForm extends StatefulWidget {
  const _TaskForm({required this.members});

  final List<Member> members;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  Recurrence _recurrence = Recurrence.weekly;
  DateTime? _dueDate = Dates.today();
  String? _assignee;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(
        context,
        NewTask(title: _title.text, recurrence: _recurrence, dueDate: _dueDate, assigneeId: _assignee),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Con scroll: en pantallas bajas o con el teclado abierto el formulario no cabe.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nueva tarea', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('taskTitle'),
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Qué hay que hacer',
                hintText: 'Sacar la basura, limpiar el baño…',
                prefixIcon: Icon(Icons.task_alt),
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe la tarea' : null,
            ),
            FormBlock(
              label: 'Se repite',
              child: Wrap(
                key: const Key('taskRecurrence'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in Recurrence.values)
                    ChoiceChip(
                      label: Text(r.label),
                      selected: _recurrence == r,
                      onSelected: (_) => setState(() => _recurrence = r),
                    ),
                ],
              ),
            ),
            FormBlock(
              label: 'Quién',
              child: Wrap(
                key: const Key('taskAssignee'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.groups_outlined),
                    label: const Text('Cualquiera'),
                    selected: _assignee == null,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _assignee = null),
                  ),
                  for (final m in widget.members)
                    ChoiceChip(
                      avatar: MemberAvatar(id: m.userId, name: m.displayName, radius: 12),
                      label: Text(m.displayName),
                      selected: _assignee == m.userId,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _assignee = m.userId),
                    ),
                ],
              ),
            ),
            FormBlock(
              label: _recurrence == Recurrence.none ? 'Para cuándo' : 'Primera vez',
              child: DateCard(
                date: _dueDate,
                onChanged: (d) => setState(() => _dueDate = d),
                onClear: () => setState(() => _dueDate = null),
                firstDate: Dates.today().subtract(const Duration(days: 365)),
                lastDate: Dates.today().add(const Duration(days: 365 * 5)),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('taskSave'),
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Crear tarea'),
            ),
          ],
        ),
      ),
    );
  }
}
