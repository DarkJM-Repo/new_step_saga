import 'package:flutter/material.dart';

class PvpScreen extends StatelessWidget {
  const PvpScreen({Key? key}) : super(key: key);

  void _calculateTurnOrder(BuildContext context) {
    int mySpeed = 120;
    int opponentSpeed = 105;

    String firstToAttack = mySpeed > opponentSpeed
        ? 'You attack first!'
        : 'Opponent attacks first!';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Speed Check: $firstToAttack')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PvP Arena')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _calculateTurnOrder(context),
          child: const Text('Find Match & Roll Initiative'),
        ),
      ),
    );
  }
}
