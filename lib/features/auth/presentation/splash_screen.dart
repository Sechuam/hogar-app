import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/ui/async_view.dart';
import '../session_controller.dart';

/// Mientras se recupera la sesión guardada; si falla por red, permite reintentar.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: session.hasError
          ? ErrorRetry(error: session.error!, onRetry: () => ref.read(sessionProvider.notifier).retry())
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
