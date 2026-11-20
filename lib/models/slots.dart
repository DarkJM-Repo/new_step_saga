import 'package:flutter/material.dart';
import 'shop_model.dart';
import '../services/rank_service.dart';

/// Shared helpers for equipment slots, skill links, and gem color coding.
class Slots {
  static const List<String> order = [
    'helm',
    'body armor',
    'pauldrons',
    'gloves',
    'belt',
    'leggings',
    'boots',
    'necklace',
    'ring',
  ];

  static const Map<String, String> _aliases = {
    'helmet': 'helm',
    'head': 'helm',
    'chestplate': 'body armor',
    'chest': 'body armor',
    'armor': 'body armor',
    'body': 'body armor',
    'body_armor': 'body armor',
    'bodyarmor': 'body armor',
    'pauldron': 'pauldrons',
    'shoulders': 'pauldrons',
    'glove': 'gloves',
    'legs': 'leggings',
    'pants': 'leggings',
    'boot': 'boots',
    'rings': 'ring',
  };

  static String key(String type) {
    final k = type.toLowerCase().trim();
    return _aliases[k] ?? k;
  }

  static String label(String key) {
    final normalized = Slots.key(key);
    if (normalized == 'body armor') return 'Body Armor';
    if (normalized == 'ring') return 'Rings';
    return normalized
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static int rank(String key) {
    final i = order.indexOf(Slots.key(key));
    return i == -1 ? order.length : i;
  }

  static String fileName(String key) => Slots.key(key).replaceAll(' ', '_');

  static bool isAccessory(String type) {
    final k = key(type);
    return k == 'necklace' || k == 'ring';
  }

  /// Active Skill socket count per slot:
  /// 1 Active for Body Armor, Leggings, Helm, Gloves, Boots, Belt; 0 for rest.
  static int activeSocketsFor(String type) {
    switch (key(type)) {
      case 'body armor':
      case 'leggings':
      case 'helm':
      case 'gloves':
      case 'boots':
      case 'belt':
        return 1;
      default:
        return 0;
    }
  }

  /// Universal Support socket count per slot:
  /// - Body Armor & Leggings: 3 supports (4-Link total)
  /// - Helm, Gloves & Boots: 2 supports (3-Link total)
  /// - Belt: 1 support (2-Link total)
  /// - Pauldrons, Necklace, Rings: 0 links
  static int supportSocketsFor(String type) {
    switch (key(type)) {
      case 'body armor':
      case 'leggings':
        return 3;
      case 'helm':
      case 'gloves':
      case 'boots':
        return 2;
      case 'belt':
        return 1;
      default:
        return 0;
    }
  }

  /// Compatibility aliases used by `game_models.dart`.
  static int defaultActiveSkillSockets(String type) => activeSocketsFor(type);
  static int defaultSupportSkillSockets(String type) => supportSocketsFor(type);

  static int totalLinksFor(String type) =>
      activeSocketsFor(type) + supportSocketsFor(type);

  static String gearAsset(String type, String tier) {
    final t = RankService.tierIndex(tier);
    final tierName = RankService.tiers[t < 0 ? 0 : t];
    return 'assets/images/gear/${fileName(key(type))}_$tierName.png';
  }

  static Widget gearImage(
    String type,
    String tier, {
    double? size,
    BoxFit fit = BoxFit.contain,
  }) {
    return Image.asset(
      gearAsset(type, tier),
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Icon(
        icon(key(type)),
        size: size == null ? null : size * 0.6,
        color: RankService.colorOfTier(tier),
      ),
    );
  }

  static IconData icon(String key) {
    switch (Slots.key(key)) {
      case 'helm':
        return Icons.sports_motorsports;
      case 'body armor':
        return Icons.shield;
      case 'pauldrons':
        return Icons.security;
      case 'gloves':
        return Icons.back_hand;
      case 'belt':
        return Icons.horizontal_rule;
      case 'leggings':
        return Icons.accessibility_new;
      case 'boots':
        return Icons.snowshoeing;
      case 'necklace':
        return Icons.diamond;
      case 'ring':
        return Icons.circle_outlined;
      default:
        return Icons.category;
    }
  }

  static Color statColor(String stat) {
    final s = stat.toLowerCase();
    if (s.contains('resistance') || s.contains('resist')) {
      return const Color(0xFFE53935);
    }
    if (s.contains('atk') || s.contains('crit') || s.contains('pen')) {
      return const Color(0xFFFF8F00);
    }
    if (s.contains('evasion')) return const Color(0xFF43A047);
    if (s.contains('precision')) return const Color(0xFF1E88E5);
    if (s.contains('movement') || s.contains('slow')) {
      return const Color(0xFF00ACC1);
    }
    if (s.startsWith('hp') || s.contains('lifesteal')) {
      return const Color(0xFFEC407A);
    }
    if (s.startsWith('mp') || s.contains('leech')) {
      return const Color(0xFF5C6BC0);
    }
    if (s.startsWith('armor') || s.contains('thorns')) {
      return const Color(0xFF90A4AE);
    }
    return const Color(0xFFD9B35A);
  }

  static Color skillCategoryColor(String category) {
    switch (category.toLowerCase().trim()) {
      case 'attack':
      case 'damage':
      case 'active_skill':
        return const Color(0xFFFF7043);
      case 'defense':
      case 'defensive':
      case 'guard':
        return const Color(0xFF42A5F5);
      case 'heal':
      case 'sustain':
        return const Color(0xFF66BB6A);
      case 'buff':
      case 'utility':
        return const Color(0xFFAB47BC);
      default:
        return const Color(0xFFFFCA28);
    }
  }

  static Color supportGroupColor(String group) {
    switch (group.toLowerCase().trim()) {
      case 'offense':
        return const Color(0xFFEF5350);
      case 'disruption':
        return const Color(0xFFAB47BC);
      case 'utility':
        return const Color(0xFF29B6F6);
      case 'sustain':
        return const Color(0xFF66BB6A);
      case 'reactive':
        return const Color(0xFFFFA726);
      default:
        return const Color(0xFF26A69A);
    }
  }

  static List<Color> socketColors(ShopItem item) {
    return List.generate(item.maxSockets.clamp(0, 6), (i) {
      if (item.allowedStats.isEmpty) return const Color(0xFFD9B35A);
      return statColor(item.allowedStats[i % item.allowedStats.length]);
    });
  }
}
