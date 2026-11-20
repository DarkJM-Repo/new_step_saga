import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/shop_model.dart';

class ApiController {
  static const String shopUrl =
      'https://raw.githubusercontent.com/Jomarc-Orogo/shop/main/shop.json';
  static const String gemsUrl =
      'https://raw.githubusercontent.com/Jomarc-Orogo/shop/main/gems.json';

  static const String restBaseUrl =
      'https://step-saga-default-rtdb.firebaseio.com/marketplace';

  Future<ShopData> fetchShopItems() async {
    try {
      final response = await http.get(Uri.parse(shopUrl));
      if (response.statusCode == 200) {
        return shopDataFromJson(response.body);
      }
      return ShopData(items: []);
    } catch (_) {
      return ShopData(items: []);
    }
  }

  Future<GemShopData> fetchGems() async {
    try {
      final response = await http.get(Uri.parse(gemsUrl));
      if (response.statusCode == 200) {
        return gemShopDataFromJson(response.body);
      }
      return GemShopData(gems: []);
    } catch (_) {
      return GemShopData(gems: []);
    }
  }

  Future<bool> createShopItem(ShopItem item) async {
    try {
      final response = await http.post(
        Uri.parse('$restBaseUrl.json'),
        body: json.encode(item.toJson()),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateShopItem(String itemId, ShopItem updatedItem) async {
    try {
      final response = await http.put(
        Uri.parse('$restBaseUrl/$itemId.json'),
        body: json.encode(updatedItem.toJson()),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteShopItem(String itemId) async {
    try {
      final response = await http.delete(
        Uri.parse('$restBaseUrl/$itemId.json'),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
