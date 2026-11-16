import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/ui/async_view.dart';
import '../session_controller.dart';
import 'brand.dart';

/// Inicio de sesión y registro con email. Los errores de campo de la API se muestran en su campo.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    final session = ref.read(sessionProvider.notifier);
    try {
      if (_register) {
        await session.register(_email.text, _password.text, _name.text);
      } else {
        await session.login(_email.text, _password.text);
      }
    } on ApiException catch (e) {
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primaryContainer.withValues(alpha: 0.6), scheme.surface],
            stops: const [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: BrandMark()),
                        const SizedBox(height: 20),
                        Text('Hogar', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Gastos, tareas y cuentas claras en casa',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    _register ? 'Crea tu cuenta' : 'Inicia sesión',
                                    key: ValueKey(_register),
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 200),
                                  alignment: Alignment.topCenter,
                                  child: _register
                                      ? Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: TextFormField(
                                            key: const Key('name'),
                                            controller: _name,
                                            decoration: InputDecoration(
                                              labelText: 'Nombre',
                                              prefixIcon: const Icon(Icons.person_outline),
                                              errorText: _fieldErrors['displayName'],
                                            ),
                                            textInputAction: TextInputAction.next,
                                            textCapitalization: TextCapitalization.words,
                                            autofillHints: const [AutofillHints.name],
                                            validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe tu nombre' : null,
                                          ),
                                        )
                                      : const SizedBox(width: double.infinity),
                                ),
                                TextFormField(
                                  key: const Key('email'),
                                  controller: _email,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: const Icon(Icons.mail_outline),
                                    errorText: _fieldErrors['email'],
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  validator: (v) => (v ?? '').contains('@') ? null : 'Escribe un email válido',
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const Key('password'),
                                  controller: _password,
                                  decoration: InputDecoration(
                                    labelText: 'Contraseña',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    errorText: _fieldErrors['password'],
                                    helperText: _register ? 'Mínimo 8 caracteres' : null,
                                    suffixIcon: IconButton(
                                      tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                                      onPressed: () => setState(() => _showPassword = !_showPassword),
                                      icon: Icon(
                                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  obscureText: !_showPassword,
                                  autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: (v) {
                                    if ((v ?? '').isEmpty) {
                                      return 'Escribe tu contraseña';
                                    }
                                    return _register && v!.length < 8 ? 'Mínimo 8 caracteres' : null;
                                  },
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: scheme.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            key: const Key('error'),
                                            style: TextStyle(color: scheme.onErrorContainer),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  key: const Key('submit'),
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text(_register ? 'Crear cuenta' : 'Entrar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                  _fieldErrors = const {};
                                }),
                          child: Text(_register ? 'Ya tengo cuenta' : 'Crear una cuenta nueva'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
