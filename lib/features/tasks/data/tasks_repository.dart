import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/ui/dates.dart';

enum Recurrence {
  none('NONE', 'Una vez'),
  daily('DAILY', 'Cada día'),
  weekly('WEEKLY', 'Cada semana'),
  monthly('MONTHLY', 'Cada mes');

  const Recurrence(this.api, this.label);

  final String api;
  final String label;

  static Recurrence fromApi(String value) => values.firstWhere((r) => r.api == value, orElse: () => none);
}

class HouseTask {
  const HouseTask({
    required this.id,
    required this.title,
    required this.assigneeId,
    required this.recurrence,
    required this.dueDate,
    required this.done,
    required this.overdue,
  });

  factory HouseTask.fromJson(Json json) => HouseTask(
    id: json['id'] as String,
    title: json['title'] as String,
    assigneeId: json['assigneeId'] as String?,
    recurrence: Recurrence.fromApi(json['recurrence'] as String),
    dueDate: Dates.fromApiOrNull(json['dueDate']),
    done: json['status'] == 'DONE',
    overdue: json['overdue'] as bool? ?? false,
  );

  final String id;
  final String title;
  final String? assigneeId;
  final Recurrence recurrence;
  final DateTime? dueDate;
  final bool done;
  final bool overdue;
}

class NewTask {
  const NewTask({required this.title, required this.recurrence, this.dueDate, this.assigneeId});

  final String title;
  final Recurrence recurrence;
  final DateTime? dueDate;
  final String? assigneeId;

  Json toJson() => {
    'title': title.trim(),
    'recurrence': recurrence.api,
    if (dueDate != null) 'dueDate': Dates.toApi(dueDate!),
    if (assigneeId != null) 'assigneeId': assigneeId,
  };
}

class TasksRepository {
  TasksRepository(this._api);

  final ApiClient _api;

  /// Tareas pendientes (las más urgentes primero, según la API).
  Future<List<HouseTask>> pending(String householdId) async {
    final json =
        await _api.get('/api/households/$householdId/tasks', query: {'status': 'PENDING', 'size': 100}) as Json;
    return (json['content'] as List).map((t) => HouseTask.fromJson(t as Json)).toList();
  }

  Future<HouseTask> create(String householdId, NewTask task) async =>
      HouseTask.fromJson(await _api.post('/api/households/$householdId/tasks', body: task.toJson()) as Json);

  /// Envía la fecha que el usuario vio: si otro la completó antes, la API responde 409 en vez de
  /// completar la siguiente repetición sin querer.
  Future<void> complete(String householdId, HouseTask task) => _api.post(
    '/api/households/$householdId/tasks/${task.id}/complete',
    body: {if (task.dueDate != null) 'dueDate': Dates.toApi(task.dueDate!)},
  );

  /// Deshace "hecha" en una tarea puntual (la API solo reabre las de tipo `NONE`).
  Future<void> reopen(String householdId, String taskId) =>
      _api.post('/api/households/$householdId/tasks/$taskId/reopen');
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) => TasksRepository(ref.watch(apiClientProvider)));

final pendingTasksProvider = FutureProvider.family<List<HouseTask>, String>(
  (ref, householdId) => ref.watch(tasksRepositoryProvider).pending(householdId),
);
