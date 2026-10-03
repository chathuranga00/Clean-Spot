import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final name = user?.displayName.isNotEmpty == true ? user!.displayName : 'Citizen';
    final email = user?.email ?? 'citizen@example.com';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFF00897B),
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(context, 'Total Points', '0', const Color(0xFFFFB300)),
                _buildStatCard(context, 'Verified Reports', '0', const Color(0xFF00897B)),
                _buildStatCard(context, 'Status', user?.isEmailVerified == true ? 'Verified' : 'Unverified', const Color(0xFF43A047)),
              ],
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Badges Earned'),
              subtitle: const Text('Server-authorized civic awards'),
              trailing: const Icon(Icons.chevron_right),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notification Preferences'),
              trailing: const Icon(Icons.chevron_right),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
