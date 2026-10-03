import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Leaderboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFFFFB300),
              child: Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text('Saman Kumara'),
            subtitle: Text('Colombo District • 12 Verified Reports'),
            trailing: Text('600 pts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Divider(),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey,
              child: Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text('Nimal Silva'),
            subtitle: Text('Gampaha District • 9 Verified Reports'),
            trailing: Text('450 pts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Divider(),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.brown,
              child: Text('3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text('Anura Bandara'),
            subtitle: Text('Kandy District • 7 Verified Reports'),
            trailing: Text('350 pts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
