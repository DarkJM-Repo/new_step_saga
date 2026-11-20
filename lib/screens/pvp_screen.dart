import 'package:flutter/material.dart';

/// PvP Arena reserved as a future content update.
class PvpScreen extends StatelessWidget {
  const PvpScreen({super.key});

  static const Color _gold = Color(0xFFFFCD5A);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/bg_dashboard.png', fit: BoxFit.cover),
        Container(color: Colors.black.withValues(alpha: 0.55)),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'PVP ARENA',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xEB1B1230),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _gold, width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sports_martial_arts, size: 54, color: _gold),
                      const SizedBox(height: 12),
                      const Text(
                        'FUTURE UPDATE',
                        style: TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Turn-Based PvP Battles are scheduled for a future Step Saga update.\n\nKeep walking to climb the Mileage Leaderboards, collect high-tier gear, and link your Active & Support gems in the Character tab!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: const Color(0xFF1B1230),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'BACK TO DASHBOARD',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
