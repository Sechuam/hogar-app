import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/expenses/presentation/expense_form_screen.dart';
import '../features/households/presentation/household_screen.dart';
import '../features/households/presentation/households_screen.dart';
import '../features/incomes/presentation/incomes_screen.dart';

/// Rutas de la app. La sesión decide adónde se puede ir: sin sesión, solo `/login`; mientras se
/// recupera la sesión guardada (o si falla por red), `/splash`.
final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<AsyncValue<User?>>(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, next) => session.value = next);
  ref.onDispose(session.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) => redirectFor(session.value, state.uri),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (context, state) => const HouseholdsScreen(),
        routes: [
          GoRoute(
            path: 'households/:id',
            builder: (context, state) => HouseholdScreen(householdId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'incomes',
                builder: (context, state) => IncomesScreen(householdId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'expenses/new',
                builder: (context, state) => ExpenseFormScreen(householdId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Redirección según la sesión (función pura para poder probarla). Al mandar a `/splash` o `/login`
/// guarda la ruta pedida en `?from=` para volver a ella cuando haya sesión (p. ej. al recargar un
/// enlace a un hogar en web).
String? redirectFor(AsyncValue<User?> session, Uri uri) {
  const splash = '/splash';
  const login = '/login';
  final location = uri.path;
  final atGate = location == splash || location == login;
  // Desde una puerta se conserva el `from` que ya traía; desde otra ruta, la ruta misma.
  final from = atGate ? _safeFrom(uri.queryParameters['from']) : (location == '/' ? null : uri.toString());

  String gate(String path) => Uri(path: path, queryParameters: from == null ? null : {'from': from}).toString();

  if (!session.hasValue) {
    return location == splash ? null : gate(splash);
  }
  if (session.requireValue == null) {
    return location == login ? null : gate(login);
  }
  return atGate ? (from ?? '/') : null;
}

/// Solo rutas internas de la app: evita que un `from` manipulado lleve fuera.
String? _safeFrom(String? from) =>
    from != null &&
        from.startsWith('/') &&
        !from.startsWith('//') &&
        !from.startsWith('/splash') &&
        !from.startsWith('/login')
    ? from
    : null;
