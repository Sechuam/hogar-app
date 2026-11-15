import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'router.dart';

class HogarApp extends ConsumerWidget {
  const HogarApp({super.key});

  static const _seed = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Hogar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seed)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
