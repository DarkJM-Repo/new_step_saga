import 'package:flutter/material.dart';
import 'shop_screen.dart';
import 'character_screen.dart';
import 'pvp_screen.dart';
import 'leaderboard_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          // Pedometer UI mocked out for presentation
          _buildMenuButton(
            context,
            'Track Steps',
            Icons.directions_walk,
            const Scaffold(
              body: Center(child: Text('Pedometer disabled for presentation')),
            ),
          ),
          _buildMenuButton(
            context,
            'Marketplace',
            Icons.store,
            const ShopScreen(currentCurrency: 1500),
          ),
          _buildMenuButton(
            context,
            'Character & Equip',
            Icons.person,
            const CharacterScreen(),
          ),
          _buildMenuButton(
            context,
            'Fight PVP',
            Icons.sports_martial_arts,
            const PvpScreen(),
          ),
          _buildMenuButton(
            context,
            'Leaderboards',
            Icons.leaderboard,
            const LeaderboardScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    IconData icon,
    Widget destination,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
