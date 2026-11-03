import 'dart:convert';

// Convert JSON string into ShopData
ShopData shopDataFromJson(String str) => ShopData.fromJson(json.decode(str));

class ShopData {
  List<ShopItem> items;

  ShopData({required this.items});

  // Convert JSON into ShopData
  factory ShopData.fromJson(dynamic json) {
    // Handle raw JSON array
    if (json is List) {
      return ShopData(
        items: json
            .whereType<Map>()
            .map((x) => ShopItem.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
      );
    }

    // Handle JSON object containing "items"
    if (json is Map<String, dynamic>) {
      final rawItems = json["items"];

      return ShopData(
        items: rawItems is List
            ? rawItems
                  .whereType<Map>()
                  .map((x) => ShopItem.fromJson(Map<String, dynamic>.from(x)))
                  .toList()
            : [],
      );
    }

    // Return empty list if JSON format is unexpected
    return ShopData(items: []);
  }
}

class ShopItem {
  String name;
  String type;
  String tier;
  int maxSockets;
  List<String> allowedStats;

  ShopItem({
    required this.name,
    required this.type,
    required this.tier,
    required this.maxSockets,
    required this.allowedStats,
  });

  // Convert JSON into ShopItem
  factory ShopItem.fromJson(Map<String, dynamic> json) {
    final rawStats = json["allowedStats"];
    final rawMaxSockets = json["maxSockets"];

    return ShopItem(
      name: json["name"]?.toString() ?? "Unknown Item",
      type: json["type"]?.toString() ?? "unknown",
      tier: json["tier"]?.toString() ?? "newbie",
      maxSockets: rawMaxSockets is num
          ? rawMaxSockets.toInt()
          : int.tryParse(rawMaxSockets?.toString() ?? "") ?? 0,
      allowedStats: rawStats is List
          ? rawStats.map((x) => x.toString()).toList()
          : [],
    );
  }

  // Convert ShopItem into JSON
  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "type": type,
      "tier": tier,
      "maxSockets": maxSockets,
      "allowedStats": allowedStats,
    };
  }
}
