import 'package:flutter/material.dart';

class EducationalScreen extends StatelessWidget {
  const EducationalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dengue Awareness & Tips'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eliminate Stagnant Water',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aedes mosquitoes breed in clean, stagnant water. Empty and scrub flower vase plates, buckets, and discarded coconut shells at least once a week.',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Dengue Symptoms',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'High fever, severe headache, pain behind the eyes, joint and muscle pain, fatigue, nausea, vomiting, and skin rash. Seek medical attention immediately if fever persists beyond 2 days.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
