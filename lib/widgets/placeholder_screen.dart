import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Temporary stand-in for a module still under construction. Replaced screen by
/// screen as each module lands.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_outlined, size: 48, color: context.p.textSecondary),
              SizedBox(height: 12),
              Text('Coming together — this screen is being built.',
                  textAlign: TextAlign.center, style: TextStyle(color: context.p.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.p.surface1,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
