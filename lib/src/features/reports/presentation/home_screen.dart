import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CleanSpot Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            color: const Color(0xFF00897B),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dengue Hazard Alert',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'High risk detected in your area due to recent rain. Check standing water containers!',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF00897B),
                    ),
                    onPressed: () => context.push('/report/new'),
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Report New Spot'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: Color(0xFF00897B)),
            title: const Text('Community Dengue Map'),
            subtitle: const Text('View verified breeding sites and hotspots'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/map'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.list_alt, color: Color(0xFF00897B)),
            title: const Text('My Reports'),
            subtitle: const Text('Track verification and cleanup status'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/my-reports'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.leaderboard_outlined, color: Color(0xFFFFB300)),
            title: const Text('Community Leaderboard'),
            subtitle: const Text('Top contributors and earned badges'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/leaderboard'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.school_outlined, color: Color(0xFF00897B)),
            title: const Text('Dengue Education & Tips'),
            subtitle: const Text('Symptoms, prevention, and emergency contacts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/education'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFE53935)),
            title: const Text('Health Inspector Review Portal'),
            subtitle: const Text('PHI / Admin verification queue'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/review'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00897B),
        onPressed: () => context.push('/report/new'),
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text('Report Spot', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
