import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFB300),
                child: Icon(Icons.hourglass_empty, color: Colors.white),
              ),
              title: const Text('Standing Water in Open Barrel'),
              subtitle: const Text('Status: Pending Inspection • 2h ago'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/report/rep-101'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF43A047),
                child: Icon(Icons.check, color: Colors.white),
              ),
              title: const Text('Blocked Concrete Drain'),
              subtitle: const Text('Status: Verified • +50 points'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/report/rep-102'),
            ),
          ),
        ],
      ),
    );
  }
}
