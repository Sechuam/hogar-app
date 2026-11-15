import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/auth_repository.dart';

/// Usuario con sesión iniciada (`null` = sin sesión). Al arrancar intenta recuperar la sesión guardada.
class SessionController extends AsyncNotifier<User?> {
  @override
  FutureOr<User?> build() {
    ref.watch(apiClientProvider).onSessionExpired = () => state = const AsyncData(null);
    return ref.watch(authRepositoryProvider).restore();
  }

  Future<void> login(String email, String password) async {
    final user = await ref.read(authRepositoryProvider).login(email, password);
    state = AsyncData(user);
  }

  Future<void> register(String email, String password, String displayName) async {
    final user = await ref.read(authRepositoryProvider).register(email, password, displayName);
    state = AsyncData(user);
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const AsyncData(null);
    }
  }

  /// Tras un fallo de red al arrancar.
  void retry() => ref.invalidateSelf();
}

final sessionProvider = AsyncNotifierProvider<SessionController, User?>(SessionController.new);
