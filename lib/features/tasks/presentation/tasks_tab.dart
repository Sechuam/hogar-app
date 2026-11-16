import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/dates.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-task',
        onPressed: () => _create(context, ref, members),
        icon: const Icon(Icons.add_task),
        label: const Text('Tarea'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pendingTasksProvider(householdId).future),
        child: AsyncView(
          value: tasks,
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
                      onPressed: () => _create(context, ref, members),
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
            return ContentWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                children: [
                  for (final MapEntry(key: title, value: tasks) in groups.entries)
                    if (tasks.isNotEmpty) ...[
                      SectionHeader('$title · ${tasks.length}'),
                      Card(
                        child: Column(
                          children: [
                            for (final (i, task) in tasks.indexed) ...[
                              if (i > 0) const Divider(indent: 64),
                              _TaskTile(task: task, members: members, onComplete: () => _complete(context, ref, task)),
                            ],
                          ],
                        ),
                      ),
                    ],
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
        showMessage(
          context,
          task.recurrence == Recurrence.none ? '"${task.title}" hecha' : '"${task.title}" hecha; se repetirá',
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

  Future<void> _create(BuildContext context, WidgetRef ref, List<Member> members) async {
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
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.members, required this.onComplete});

  final HouseTask task;
  final List<Member> members;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final assignee = task.assigneeId;
    final details = [
      if (task.dueDate != null) Dates.shortDay(task.dueDate!),
      if (task.recurrence != Recurrence.none) task.recurrence.label.toLowerCase(),
    ];
    return ListTile(
      leading: Checkbox(
        value: false,
        shape: const CircleBorder(),
        side: BorderSide(color: task.overdue ? scheme.error : scheme.outline, width: 2),
        onChanged: (_) => onComplete(),
      ),
      title: Text(task.title),
      subtitle: details.isEmpty
          ? null
          : Row(
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
            ),
      trailing: assignee == null ? null : MemberAvatar(id: assignee, name: memberName(members, assignee), radius: 16),
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

  @override
  Widget build(BuildContext context) {
    // Con scroll: en pantallas bajas o con el teclado abierto el formulario no cabe.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nueva tarea', style: Theme.of(context).textTheme.titleLarge),
            TextFormField(
              key: const Key('taskTitle'),
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Qué hay que hacer'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe la tarea' : null,
            ),
            DropdownButtonFormField<Recurrence>(
              initialValue: _recurrence,
              decoration: const InputDecoration(labelText: 'Se repite'),
              items: [for (final r in Recurrence.values) DropdownMenuItem(value: r, child: Text(r.label))],
              onChanged: (r) => setState(() => _recurrence = r!),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _assignee,
              decoration: const InputDecoration(labelText: 'Quién'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Cualquiera')),
                for (final m in widget.members) DropdownMenuItem(value: m.userId, child: Text(m.displayName)),
              ],
              onChanged: (v) => setState(() => _assignee = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha'),
              subtitle: Text(_dueDate == null ? 'Sin fecha' : Dates.format(_dueDate!)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? Dates.today(),
                  firstDate: Dates.today().subtract(const Duration(days: 365)),
                  lastDate: Dates.today().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) {
                  setState(() => _dueDate = picked);
                }
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(
                    context,
                    NewTask(title: _title.text, recurrence: _recurrence, dueDate: _dueDate, assigneeId: _assignee),
                  );
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}
