import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/shop_model.dart';

class ApiController {
  static const String getUrl =
      'https://raw.githubusercontent.com/Jomarc-Orogo/shop/main/shop.json';

  static const String restBaseUrl =
      'https://step-saga-default-rtdb.firebaseio.com/marketplace';

  Future<ShopData> fetchShopItems() async {
    try {
      Uri uri = Uri.parse(getUrl);
      var response = await http.get(uri);

      if (response.statusCode == 200) {
        return shopDataFromJson(response.body);
      } else {
        print('GET Error: ${response.statusCode}');
        return ShopData(items: []);
      }
    } catch (e) {
      print('Failed to GET API data: $e');
      return ShopData(items: []);
    }
  }

  Future<bool> createShopItem(ShopItem item) async {
    try {
      Uri uri = Uri.parse('$restBaseUrl.json');
      var response = await http.post(uri, body: json.encode(item.toJson()));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Failed to POST data: $e');
      return false;
    }
  }

  Future<bool> updateShopItem(String itemId, ShopItem updatedItem) async {
    try {
      Uri uri = Uri.parse('$restBaseUrl/$itemId.json');
      var response = await http.put(
        uri,
        body: json.encode(updatedItem.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Failed to PUT data: $e');
      return false;
    }
  }

  Future<bool> deleteShopItem(String itemId) async {
    try {
      Uri uri = Uri.parse('$restBaseUrl/$itemId.json');
      var response = await http.delete(uri);

      return response.statusCode == 200;
    } catch (e) {
      print('Failed to DELETE data: $e');
      return false;
    }
  }
}
