import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dengue Hotspot Map'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on,
              size: 64,
              color: Color(0xFFE53935),
            ),
            const SizedBox(height: 16),
            Text(
              'Interactive Hotspot Map',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Placeholder for flutter_map with OpenStreetMap tiles\nand risk-clustered breeding site pins.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
