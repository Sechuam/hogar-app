import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/ui/async_view.dart';
import '../../../core/ui/widgets.dart';
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
            tooltip: 'Cuenta',
            icon: user == null ? null : MemberAvatar(id: user.id, name: user.displayName, radius: 16),
            onSelected: (_) => ref.read(sessionProvider.notifier).logout(),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(user?.displayName ?? ''),
                  subtitle: Text(user?.email ?? ''),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Cerrar sesión'),
                ),
              ),
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
          data: (list) => ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
              children: [
                if (user != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      'Hola, ${user.displayName.split(' ').first}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                if (list.isEmpty)
                  EmptyState(
                    icon: Icons.house_outlined,
                    title: 'Aún no tienes ningún hogar',
                    message: 'Crea uno para tu piso o tu pareja, o únete con el código que te pasen.',
                    action: OutlinedButton.icon(
                      onPressed: () => _join(context, ref),
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: const Text('Tengo un código'),
                    ),
                  )
                else ...[
                  SectionHeader(list.length == 1 ? 'Tu hogar' : 'Tus ${list.length} hogares'),
                  for (final household in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HouseholdCard(household: household),
                    ),
                ],
              ],
            ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = MemberAvatar.colorsFor(household.id, theme.brightness);
    final members = household.memberCount == 1 ? '1 miembro' : '${household.memberCount} miembros';
    final premium = household.plan == 'PREMIUM';
    return Card(
      child: InkWell(
        onTap: () => context.go('/households/${household.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.home_rounded, color: foreground, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            household.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PlanBadge(premium: premium, label: household.plan),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _Info(icon: Icons.group_outlined, text: members),
                        _Info(
                          icon: household.isOwner ? Icons.star_outline_rounded : Icons.person_outline,
                          text: household.isOwner ? 'Propietario' : 'Miembro',
                        ),
                        _Info(
                          icon: household.splitPolicy == 'PROPORTIONAL'
                              ? Icons.pie_chart_outline
                              : Icons.drag_handle_rounded,
                          text: household.splitPolicy == 'PROPORTIONAL' ? 'Según ingresos' : 'A partes iguales',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.premium, required this.label});

  final bool premium;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = premium ? scheme.tertiaryContainer : scheme.surfaceContainerHighest;
    final foreground = premium ? scheme.onTertiaryContainer : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      ],
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
