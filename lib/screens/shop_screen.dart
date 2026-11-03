import 'package:flutter/material.dart';
import '../models/shop_model.dart';
import '../services/api_controller.dart';

class ShopScreen extends StatefulWidget {
  final int currentCurrency;
  const ShopScreen({Key? key, this.currentCurrency = 0}) : super(key: key);

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late ShopData shopData;
  bool isDataLoaded = false;
  final ApiController _apiController = ApiController();

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    ShopData data = await _apiController.fetchShopItems();
    setState(() {
      shopData = data;
      isDataLoaded = true;
    });
  }

  Color getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'newbie':
        return Colors.grey;
      case 'advance':
        return Colors.green;
      case 'masterful':
        return Colors.blue;
      case 'elite':
        return Colors.purple;
      case 'legendary':
        return Colors.orange;
      case 'mythical':
        return Colors.redAccent;
      default:
        return Colors.white;
    }
  }

  IconData getEquipmentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'boots':
        return Icons.snowshoeing;
      case 'helm':
        return Icons.sports_motorsports;
      case 'body armor':
        return Icons.shield;
      case 'gloves':
        return Icons.back_hand;
      case 'necklace':
        return Icons.diamond;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${widget.currentCurrency}',
                  style: const TextStyle(fontSize: 18, color: Colors.amber),
                ),
              ],
            ),
          ),
        ],
      ),
      body: isDataLoaded
          ? ListView.builder(
              itemCount: shopData.items.length,
              itemBuilder: (context, index) {
                var item = shopData.items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: getTierColor(item.tier).withOpacity(0.2),
                      child: Icon(
                        getEquipmentIcon(item.type),
                        color: getTierColor(item.tier),
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: getTierColor(item.tier),
                      ),
                    ),
                    subtitle: Text(
                      'Type: ${item.type.toUpperCase()} | Sockets: ${item.maxSockets}\nAllowed Gems: ${item.allowedStats.join(", ")}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
