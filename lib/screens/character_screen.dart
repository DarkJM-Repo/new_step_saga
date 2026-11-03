import 'package:flutter/material.dart';

class CharacterScreen extends StatelessWidget {
  const CharacterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final slots = [
      'Helm',
      'Body Armor',
      'Pauldrons',
      'Gloves',
      'Belt',
      'Leggings',
      'Boots',
      'Necklace',
      'Ring 1',
      'Ring 2',
      'Ring 3',
      'Ring 4',
      'Ring 5',
      'Ring 6',
      'Ring 7',
      'Ring 8',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Character & Enchanting')),
      body: ListView.builder(
        itemCount: slots.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.shield),
            title: Text(slots[index]),
            subtitle: const Text('Empty Slot - Tap to Equip/Enchant'),
            trailing: const Icon(Icons.auto_fix_high),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening enchanting UI for ${slots[index]}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
