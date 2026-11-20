import 'package:flutter/material.dart';
import 'shop_screen.dart';
import 'character_screen.dart';
import 'pvp_screen.dart';
import 'leaderboard_screen.dart';
import 'steps_screen.dart';
import '../services/auth_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const Color _gold = Color(0xFFFFCD5A);

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    // AuthGate in main.dart returns to the login screen automatically
    if (confirmed == true) {
      await AuthService().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen landscape background art
        Image.asset('assets/images/bg_dashboard.png', fit: BoxFit.cover),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            toolbarHeight: 48,
            title: const Text(
              'STEP SAGA',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Log out',
                icon: const Icon(Icons.logout, color: _gold),
                onPressed: () => _confirmLogout(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              // Landscape: all five menu tiles sit side by side in one row
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMenuButton(
                    context,
                    'Track Steps',
                    'assets/images/icon_steps.png',
                    const StepsScreen(),
                  ),
                  _buildMenuButton(
                    context,
                    'Marketplace',
                    'assets/images/icon_shop.png',
                    const ShopScreen(currentCurrency: 1500),
                  ),
                  _buildMenuButton(
                    context,
                    'Character & Equip',
                    'assets/images/icon_character.png',
                    const CharacterScreen(),
                  ),
                  _buildMenuButton(
                    context,
                    'Fight PVP',
                    'assets/images/icon_arena.png',
                    const PvpScreen(),
                  ),
                  _buildMenuButton(
                    context,
                    'Leaderboards',
                    'assets/images/icon_leaderboard.png',
                    const LeaderboardScreen(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    String imagePath,
    Widget destination,
  ) {
    final radius = BorderRadius.circular(16);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF2A1B4D).withValues(alpha: 0.80),
                  const Color(0xFF120B26).withValues(alpha: 0.90),
                ],
              ),
              border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: radius,
              splashColor: _gold.withValues(alpha: 0.25),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => destination),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Image.asset(imagePath, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
