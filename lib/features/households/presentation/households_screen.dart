import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/ui/async_view.dart';
import '../../auth/session_controller.dart';
import '../data/households_repository.dart';

/// Mis hogares: crear uno o unirse con un código de invitación.
class HouseholdsScreen extends ConsumerWidget {
  const HouseholdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final households = ref.watch(myHouseholdsProvider);
    final user = ref.watch(sessionProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis hogares'),
        actions: [
          IconButton(
            tooltip: 'Unirme con un código',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => _join(context, ref),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => ref.read(sessionProvider.notifier).logout(),
            itemBuilder: (context) => [
              PopupMenuItem(enabled: false, child: Text(user?.email ?? '')),
              const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_home_outlined),
        label: const Text('Crear hogar'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myHouseholdsProvider.future),
        child: AsyncView(
          value: households,
          onRetry: () => ref.invalidate(myHouseholdsProvider),
          data: (list) => list.isEmpty
              ? ListView(
                  children: [
                    EmptyState(
                      icon: Icons.house_outlined,
                      message: 'Aún no tienes ningún hogar.\nCrea uno o únete con el código que te pasen.',
                      action: OutlinedButton.icon(
                        onPressed: () => _join(context, ref),
                        icon: const Icon(Icons.vpn_key_outlined),
                        label: const Text('Tengo un código'),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _HouseholdCard(household: list[i]),
                ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _askText(context, title: 'Nuevo hogar', label: 'Nombre', action: 'Crear');
    if (name == null || !context.mounted) {
      return;
    }
    try {
      final household = await ref.read(householdsRepositoryProvider).create(name);
      ref.invalidate(myHouseholdsProvider);
      if (context.mounted) {
        context.go('/households/${household.id}');
      }
    } catch (e) {
      if (context.mounted) {
        showError(context, e);
      }
    }
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final code = await _askText(
      context,
      title: 'Unirme a un hogar',
      label: 'Código de invitación',
      action: 'Unirme',
      upperCase: true,
    );
    if (code == null || !context.mounted) {
      return;
    }
    try {
      final household = await ref.read(householdsRepositoryProvider).join(code);
      ref.invalidate(myHouseholdsProvider);
      if (context.mounted) {
        showMessage(context, 'Te has unido a ${household.name}');
        context.go('/households/${household.id}');
      }
    } catch (e) {
      if (context.mounted) {
        showError(context, e);
      }
    }
  }
}

class _HouseholdCard extends StatelessWidget {
  const _HouseholdCard({required this.household});

  final Household household;

  @override
  Widget build(BuildContext context) {
    final members = household.memberCount == 1 ? '1 miembro' : '${household.memberCount} miembros';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(child: Icon(Icons.home_outlined)),
        title: Text(household.name),
        subtitle: Text('$members · ${household.isOwner ? 'Propietario' : 'Miembro'}'),
        trailing: Chip(label: Text(household.plan)),
        onTap: () => context.go('/households/${household.id}'),
      ),
    );
  }
}

/// Diálogo con un campo de texto; devuelve el texto (sin espacios a los lados) o `null`.
Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  bool upperCase = false,
}) => showDialog<String>(
  context: context,
  builder: (context) => _TextPrompt(title: title, label: label, action: action, upperCase: upperCase),
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({required this.title, required this.label, required this.action, required this.upperCase});

  final String title;
  final String label;
  final String action;
  final bool upperCase;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      Navigator.pop(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('prompt'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        textCapitalization: widget.upperCase ? TextCapitalization.characters : TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}
