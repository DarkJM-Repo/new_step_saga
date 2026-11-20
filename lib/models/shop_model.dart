import 'dart:convert';
import 'slots.dart';

ShopData shopDataFromJson(String str) => ShopData.fromJson(json.decode(str));
GemShopData gemShopDataFromJson(String str) =>
    GemShopData.fromJson(json.decode(str));

class ShopData {
  final List<ShopItem> items;
  final List<ShopItem> gems;

  ShopData({required this.items, this.gems = const []});

  factory ShopData.fromJson(dynamic json) {
    if (json is List) {
      return ShopData(
        items: json
            .whereType()
            .map((x) => ShopItem.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
      );
    }
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final rawItems = map['items'] is List ? map['items'] as List : const [];
      final rawGems = map['gems'] is List ? map['gems'] as List : const [];
      return ShopData(
        items: rawItems
            .whereType()
            .map((x) => ShopItem.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        gems: rawGems
            .whereType()
            .map(
              (x) => ShopItem.fromJson(
                Map<String, dynamic>.from(x),
                forceGem: true,
              ),
            )
            .toList(),
      );
    }
    return ShopData(items: []);
  }
}

/// Model used by `ApiController.fetchGems()` and `ShopScreen`.
class GemShopData {
  final List<ShopItem> gems;

  GemShopData({required this.gems});

  factory GemShopData.fromJson(dynamic json) {
    final parsed = <ShopItem>[];

    void addList(dynamic raw, {String? forcedCategory}) {
      if (raw is! List) return;
      for (final entry in raw) {
        if (entry is Map) {
          final m = Map<String, dynamic>.from(entry);
          if (forcedCategory != null && m['gemCategory'] == null) {
            m['gemCategory'] = forcedCategory;
          }
          parsed.add(ShopItem.fromJson(m, forceGem: true));
        }
      }
    }

    if (json is List) {
      addList(json);
    } else if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      addList(map['gems']);
      addList(map['statGems'], forcedCategory: 'stat');
      addList(map['stat_gems'], forcedCategory: 'stat');
      addList(map['activeSkillGems'], forcedCategory: 'active_skill');
      addList(map['active_skill_gems'], forcedCategory: 'active_skill');
      addList(map['supportSkillGems'], forcedCategory: 'support_skill');
      addList(map['support_skill_gems'], forcedCategory: 'support_skill');
    }

    return GemShopData(gems: parsed);
  }
}

/// Represents both equippable gear and purchasable gems in shop/inventory.
class ShopItem {
  final String? id;
  final String name;
  final String type;
  final String tier;
  final int price;
  final int maxSockets;
  final int activeSkillSockets;
  final int supportSkillSockets;
  final List<String> allowedStats;

  // Gem-specific metadata
  final String? gemCategory; // 'stat' | 'active_skill' | 'support_skill'
  final String? statType;
  final double value;
  final bool isPercentage;
  final String?
  supportGroup; // 'offense' | 'disruption' | 'utility' | 'sustain' | 'reactive'
  final bool isTrigger;
  final String? classRestriction;
  final String? damageType;
  final int baseMpCost;
  final int cooldown;
  final double mpMultiplier;
  final List<String> compatibleTags;
  final List<String> allowedSlots;
  final String? effect;

  ShopItem({
    this.id,
    required this.name,
    required this.type,
    required this.tier,
    this.price = 0,
    required this.maxSockets,
    int? activeSkillSockets,
    int? supportSkillSockets,
    required this.allowedStats,
    this.gemCategory,
    this.statType,
    this.value = 0,
    this.isPercentage = false,
    this.supportGroup,
    this.isTrigger = false,
    this.classRestriction,
    this.damageType,
    this.baseMpCost = 0,
    this.cooldown = 0,
    this.mpMultiplier = 1.0,
    this.compatibleTags = const [],
    this.allowedSlots = const [],
    this.effect,
  }) : activeSkillSockets = activeSkillSockets ?? Slots.activeSocketsFor(type),
       supportSkillSockets =
           supportSkillSockets ?? Slots.supportSocketsFor(type);

  List<String> get effectiveAllowedStats =>
      allowedStats.isNotEmpty ? allowedStats : defaultAllowedStats(type);

  /// Effective purchase price (extend here for discount logic).
  int get effectivePrice => price;


  bool get isGem {
    final t = type.toLowerCase().trim();
    return gemCategory != null ||
        t == 'gem' ||
        t == 'stat_gem' ||
        t == 'active_skill' ||
        t == 'support_skill';
  }

  String get normalizedGemCategory {
    // Name-based detection is most reliable — check it first so that
    // old Firestore documents with a wrongly-stored 'stat' category are fixed.
    final n = name.toLowerCase();
    if (n.contains('(active)') || n.contains('active skill')) {
      return 'active_skill';
    }
    if (n.contains('(support)') || n.endsWith(' support') ||
        n.contains(' support ')) {
      return 'support_skill';
    }

    if (gemCategory != null && gemCategory!.isNotEmpty) {
      final c = gemCategory!.toLowerCase().trim();
      if (c == 'active' || c == 'active_skill') return 'active_skill';
      if (c == 'support' || c == 'support_skill') return 'support_skill';
      if (c == 'stat') return 'stat';
    }
    // Fallback: infer from raw type (before it was normalised to 'gem').
    final t = type.toLowerCase().trim();
    if (t == 'active_skill' || t == 'active') return 'active_skill';
    if (t == 'support_skill' || t == 'support') return 'support_skill';
    // 'gem' is the normalised storage type — default to stat only as last resort.
    return 'stat';
  }

  bool get isActiveSkillGem => isGem && normalizedGemCategory == 'active_skill';
  bool get isSupportSkillGem =>
      isGem && normalizedGemCategory == 'support_skill';
  bool get isStatGem => isGem && normalizedGemCategory == 'stat';

  bool get canHaveSkills =>
      !isGem && activeSkillSockets > 0 && supportSkillSockets > 0;

  int get totalLinks => activeSkillSockets + supportSkillSockets;

  String get resolvedSupportGroup {
    if (supportGroup != null && supportGroup!.trim().isNotEmpty) {
      return supportGroup!.toLowerCase().trim();
    }
    final n = name.toLowerCase();
    if (n.contains('stand') ||
        n.contains('riposte') ||
        n.contains('vengeance') ||
        n.contains('surge') ||
        n.contains('undying') ||
        n.contains('retribution') ||
        n.contains('bloodlust')) {
      return 'reactive';
    }
    if (n.contains('vamp') ||
        n.contains('leech') ||
        n.contains('soul') ||
        n.contains('aegis') ||
        n.contains('vital')) {
      return 'sustain';
    }
    if (n.contains('efficiency') ||
        n.contains('mana') ||
        n.contains('quicken') ||
        n.contains('linger') ||
        n.contains('opener') ||
        n.contains('momentum')) {
      return 'utility';
    }
    if (n.contains('concuss') ||
        n.contains('serrated') ||
        n.contains('venom') ||
        n.contains('chill') ||
        n.contains('bleed') ||
        n.contains('stun')) {
      return 'disruption';
    }
    return 'offense';
  }

  static String supportGroupLabel(String group) {
    switch (group.toLowerCase().trim()) {
      case 'offense':
        return 'Offense & Damage';
      case 'disruption':
        return 'Disruption & Status';
      case 'utility':
        return 'Utility & Cooldown';
      case 'sustain':
        return 'Sustain & Defense';
      case 'reactive':
        return 'Reactive Triggers';
      default:
        return 'General Support';
    }
  }

  static int supportGroupRank(String group) {
    switch (group.toLowerCase().trim()) {
      case 'offense':
        return 0;
      case 'disruption':
        return 1;
      case 'utility':
        return 2;
      case 'sustain':
        return 3;
      case 'reactive':
        return 4;
      default:
        return 5;
    }
  }

  static List<String> defaultAllowedStats(String rawType) {
    switch (Slots.key(rawType)) {
      case 'helm':
        return ['Evasion +%', 'Precision +%'];
      case 'body armor':
        return [
          'HP flat+',
          'HP regen flat+',
          'HP regen %+',
          'Armor flat+',
          'MP flat+',
          'MP regen flat+',
          'MP regen %+',
        ];
      case 'pauldrons':
        return [
          'Resistance: Blunt',
          'Resistance: Piercing',
          'Resistance: Slash',
          'Resistance: Elemental',
        ];
      case 'gloves':
        return ['ATK flat+', 'ATK %+', 'ATK Speed flat+', 'ATK Speed %+'];
      case 'belt':
        return [
          'HP flat+',
          'HP regen flat+',
          'HP regen %+',
          'MP flat+',
          'MP regen flat+',
          'MP regen %+',
        ];
      case 'leggings':
        return [
          'HP flat+',
          'HP regen flat+',
          'HP regen %+',
          'Armor flat+',
          'MP flat+',
          'MP regen flat+',
          'MP regen %+',
        ];
      case 'boots':
        return ['Movement Speed flat+', 'Evasion +%'];
      case 'necklace':
      case 'ring':
        return [
          'crit_chance_%',
          'crit_damage_%',
          'armor_pen_%',
          'resist_shred_%',
          'stun_chance_%',
          'bleed_chance_%',
          'poison_chance_%',
          'slow_chance_%',
          'status_resist_%',
          'lifesteal_%',
          'mp_leech_%',
          'thorns_%',
          'counter_chance_%',
          'step_gold_%',
          'goal_reduction_%',
        ];
      default:
        return [];
    }
  }

  static int defaultMaxSockets(String rawType, String rawTier) {
    final slot = Slots.key(rawType);
    final tier = rawTier.toLowerCase().trim();
    switch (slot) {
      case 'helm':
      case 'gloves':
      case 'boots':
      case 'necklace':
        return 2;
      case 'pauldrons':
      case 'ring':
        return 1;
      case 'body armor':
      case 'leggings':
        if (tier == 'newbie') return 2;
        if (tier == 'advance' || tier == 'masterful') return 3;
        if (tier == 'elite' || tier == 'legendary') return 4;
        if (tier == 'mythical') return 5;
        return 2;
      case 'belt':
        if (tier == 'newbie') return 1;
        if (tier == 'advance' || tier == 'masterful') return 2;
        if (tier == 'elite' || tier == 'legendary') return 3;
        if (tier == 'mythical') return 4;
        return 1;
      default:
        return 0;
    }
  }

  factory ShopItem.fromJson(
    Map<String, dynamic> json, {
    bool forceGem = false,
  }) {
    final rawType = (json['type'] ?? (forceGem ? 'gem' : 'unknown')).toString();
    final tier = (json['tier'] ?? 'newbie').toString();
    final rawCategory = (json['gemCategory'] ?? json['category'])?.toString();

    final isGemItem =
        forceGem ||
        rawCategory != null ||
        rawType.toLowerCase().contains('gem') ||
        rawType.toLowerCase() == 'active_skill' ||
        rawType.toLowerCase() == 'support_skill';

    String? resolvedGemCategory = rawCategory;
    if (isGemItem &&
        (resolvedGemCategory == null || resolvedGemCategory.isEmpty)) {
      final t = rawType.toLowerCase().trim();
      if (t == 'active_skill' || t == 'active') {
        resolvedGemCategory = 'active_skill';
      } else if (t == 'support_skill' || t == 'support') {
        resolvedGemCategory = 'support_skill';
      } else {
        // Name-based detection first — most reliable for old docs.
        final rawName = (json['name'] ?? '').toString().toLowerCase();
        if (rawName.contains('(active)') || rawName.contains('active skill')) {
          resolvedGemCategory = 'active_skill';
        } else if (rawName.contains('(support)') ||
            rawName.endsWith(' support') ||
            rawName.contains(' support ')) {
          resolvedGemCategory = 'support_skill';
        } else {
          // Heuristic fallback for old Firestore documents where gemCategory was
          // not persisted: Active Skill gems have baseMpCost > 0;
          // Support gems have mpMultiplier != 1.0, or supportGroup/isTrigger set.
          final hasMpCost = (json['baseMpCost'] as num?)?.toInt() ?? 0;
          final hasMpMultiplier =
              (json['mpMultiplier'] as num?)?.toDouble() ?? 1.0;
          final hasSupportGroup =
              json['supportGroup']?.toString().isNotEmpty ?? false;
          final hasTrigger = json['isTrigger'] == true ||
              (json['name']?.toString().toLowerCase().contains('trigger') ??
                  false);
          if (hasMpCost > 0 && hasMpMultiplier == 1.0 && !hasSupportGroup) {
            resolvedGemCategory = 'active_skill';
          } else if (hasMpMultiplier != 1.0 || hasSupportGroup || hasTrigger) {
            resolvedGemCategory = 'support_skill';
          } else {
            resolvedGemCategory = 'stat';
          }
        }
      }
    }

    final rawStats =
        json['allowedStats'] ?? json['allowedGemTypes'] ?? json['allowedGems'];
    final parsedStats = rawStats is List
        ? rawStats.map((x) => x.toString()).toList()
        : <String>[];

    final parsedMaxSockets = (json['maxSockets'] as num?)?.toInt() ?? 0;

    return ShopItem(
      id: json['id']?.toString(),
      name: (json['name'] ?? 'Unknown Item').toString(),
      type: isGemItem ? 'gem' : rawType,
      tier: tier,
      price: (json['price'] as num?)?.toInt() ?? 0,
      maxSockets: isGemItem
          ? 0
          : (parsedMaxSockets > 0
                ? parsedMaxSockets
                : defaultMaxSockets(rawType, tier)),
      activeSkillSockets: isGemItem ? 0 : Slots.activeSocketsFor(rawType),
      supportSkillSockets: isGemItem ? 0 : Slots.supportSocketsFor(rawType),
      allowedStats: isGemItem
          ? const []
          : (parsedStats.isNotEmpty
                ? parsedStats
                : defaultAllowedStats(rawType)),
      gemCategory: resolvedGemCategory,
      statType: (json['statType'] ?? json['stat'])?.toString(),
      value: (json['value'] as num?)?.toDouble() ?? 0,
      isPercentage: json['isPercentage'] == true,
      supportGroup: (json['supportGroup'] ?? json['group'])?.toString(),
      isTrigger:
          json['isTrigger'] == true ||
          (json['name']?.toString().toLowerCase().contains('trigger') ?? false),
      classRestriction: json['classRestriction']?.toString(),
      damageType: json['damageType']?.toString(),
      baseMpCost: (json['baseMpCost'] as num?)?.toInt() ?? 25,
      cooldown: (json['cooldown'] as num?)?.toInt() ?? 2,
      mpMultiplier: (json['mpMultiplier'] as num?)?.toDouble() ?? 1.2,
      compatibleTags: json['compatibleTags'] is List
          ? (json['compatibleTags'] as List).map((e) => e.toString()).toList()
          : const ['any'],
      allowedSlots: json['allowedSlots'] is List
          ? (json['allowedSlots'] as List)
                .map((e) => Slots.key(e.toString()))
                .toList()
          : const [],
      effect: (json['effect'] ?? json['description'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'type': type,
    'tier': tier,
    'price': price,
    'maxSockets': maxSockets,
    'activeSkillSockets': activeSkillSockets,
    'supportSkillSockets': supportSkillSockets,
    'allowedStats': allowedStats,
    // Always persist gemCategory for gems so it survives a Firestore round-trip.
    // Non-gem items have gemCategory == null so we still skip it there.
    'gemCategory': gemCategory,
    if (statType != null) 'statType': statType,
    if (value != 0) 'value': value,
    if (isPercentage) 'isPercentage': isPercentage,
    if (supportGroup != null) 'supportGroup': supportGroup,
    if (isTrigger) 'isTrigger': isTrigger,
    if (classRestriction != null) 'classRestriction': classRestriction,
    if (damageType != null) 'damageType': damageType,
    if (baseMpCost != 0) 'baseMpCost': baseMpCost,
    if (cooldown != 0) 'cooldown': cooldown,
    if (mpMultiplier != 1.0) 'mpMultiplier': mpMultiplier,
    if (compatibleTags.isNotEmpty) 'compatibleTags': compatibleTags,
    if (allowedSlots.isNotEmpty) 'allowedSlots': allowedSlots,
    if (effect != null) 'effect': effect,
  };
}
