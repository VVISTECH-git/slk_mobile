import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: SlkApp()));
}

class SlkApp extends ConsumerWidget {
  const SlkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Sree Lakshmi Kalamkari',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // On wide screens (tablets/foldables) keep the UI in a comfortable
      // phone-width column rather than stretching edge to edge.
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        if (width <= 720 || child == null) return child ?? const SizedBox.shrink();
        return ColoredBox(
          color: const Color(0xFFE7DDD0),
          child: Center(
            child: SizedBox(width: 600, child: child),
          ),
        );
      },
    );
  }
}
