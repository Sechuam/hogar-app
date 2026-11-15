import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/ui/async_view.dart';
import '../session_controller.dart';

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
    return Scaffold(
      body: SafeArea(
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
                      Icon(Icons.home_work_outlined, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text('Hogar', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                      Text(
                        'Gastos, tareas y cuentas claras en casa',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      if (_register) ...[
                        TextFormField(
                          key: const Key('name'),
                          controller: _name,
                          decoration: InputDecoration(labelText: 'Nombre', errorText: _fieldErrors['displayName']),
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe tu nombre' : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        key: const Key('email'),
                        controller: _email,
                        decoration: InputDecoration(labelText: 'Email', errorText: _fieldErrors['email']),
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
                          errorText: _fieldErrors['password'],
                          helperText: _register ? 'Mínimo 8 caracteres' : null,
                        ),
                        obscureText: true,
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
                        Text(
                          _error!,
                          key: const Key('error'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('submit'),
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_register ? 'Crear cuenta' : 'Entrar'),
                      ),
                      const SizedBox(height: 8),
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
    );
  }
}
