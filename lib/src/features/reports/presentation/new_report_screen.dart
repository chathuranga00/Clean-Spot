import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NewReportScreen extends StatelessWidget {
  const NewReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Breeding Site'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 48, color: Color(0xFF00897B)),
                  SizedBox(height: 8),
                  Text('Capture Hazard Photo (Placeholder)'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Hazard Category',
                hintText: 'e.g. Standing water, discarded tires, open tanks',
                border: OutlineInputBorder(),
              ),
              enabled: false,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Location / Notes',
                hintText: 'Near community hall, back drain',
                border: OutlineInputBorder(),
              ),
              enabled: false,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submission scaffold ready')),
                );
                context.pop();
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }
}
