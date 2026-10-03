import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 80,
              color: Color(0xFF00897B),
            ),
            const SizedBox(height: 16),
            Text(
              'CleanSpot',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00897B),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dengue Breeding Site Reporter',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Enter App'),
            ),
          ],
        ),
      ),
    );
  }
}
