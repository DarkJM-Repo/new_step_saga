import 'slots.dart';

class PlayerProfile {
  String uid;
  String displayName;
  String characterClassId;
  int currency;
  double totalMileageKm;
  int pvpKills;
  int pvpWins;

  /// Holds equipped items by slot key (e.g. 'helm', 'body_armor', 'necklace',
  /// 'ring1' .. 'ring8').
  Map<String, Equipment?> equippedGear;

  /// Optional list view of the up to 8 equipped rings if stored separately.
  List<Equipment> equippedRings;

  PlayerProfile({
    required this.uid,
    this.displayName = 'Hero',
    this.characterClassId = 'vanguard',
    this.currency = 0,
    this.totalMileageKm = 0.0,
    this.pvpKills = 0,
    this.pvpWins = 0,
    required this.equippedGear,
    this.equippedRings = const [],
  });

  List<Equipment> get allEquippedAccessories {
    final accessories = <Equipment>[];
    final seenIds = <String>{};

    void addIfAccessory(Equipment? item) {
      if (item == null) return;
      if (!Slots.isAccessory(item.type)) return;
      if (item.id.isNotEmpty && !seenIds.add(item.id)) return;
      accessories.add(item);
    }

    equippedGear.forEach((slotKey, item) {
      if (Slots.isAccessory(slotKey) ||
          (item != null && Slots.isAccessory(item.type))) {
        addIfAccessory(item);
      }
    });

    for (final ring in equippedRings) {
      addIfAccessory(ring);
    }

    return accessories;
  }

  List<EvaluatedAccessoryGem> evaluateAccessoryGems() {
    final allGems = <EvaluatedAccessoryGem>[];

    for (final accessory in allEquippedAccessories) {
      for (int i = 0; i < accessory.socketedGems.length; i++) {
        allGems.add(
          EvaluatedAccessoryGem(
            equipmentId: accessory.id,
            equipmentName: accessory.name,
            slotType: Slots.key(accessory.type),
            socketIndex: i,
            gem: accessory.socketedGems[i],
            isActive: false,
          ),
        );
      }
    }

    final bestIndexByStat = <String, int>{};
    for (int i = 0; i < allGems.length; i++) {
      final stat = allGems[i].gem.statType.toLowerCase();
      final existingIndex = bestIndexByStat[stat];
      if (existingIndex == null ||
          allGems[i].gem.value > allGems[existingIndex].gem.value) {
        bestIndexByStat[stat] = i;
      }
    }

    for (final winnerIndex in bestIndexByStat.values) {
      allGems[winnerIndex] = allGems[winnerIndex].copyWith(isActive: true);
    }

    return allGems;
  }

  Map<String, double> get activeAccessoryStats {
    final totals = <String, double>{};
    for (final entry in evaluateAccessoryGems()) {
      if (entry.isActive) {
        totals[entry.gem.statType] = entry.gem.value;
      }
    }
    return totals;
  }
}

class EvaluatedAccessoryGem {
  final String equipmentId;
  final String equipmentName;
  final String slotType;
  final int socketIndex;
  final Gem gem;
  final bool isActive;

  const EvaluatedAccessoryGem({
    required this.equipmentId,
    required this.equipmentName,
    required this.slotType,
    required this.socketIndex,
    required this.gem,
    required this.isActive,
  });

  EvaluatedAccessoryGem copyWith({bool? isActive}) {
    return EvaluatedAccessoryGem(
      equipmentId: equipmentId,
      equipmentName: equipmentName,
      slotType: slotType,
      socketIndex: socketIndex,
      gem: gem,
      isActive: isActive ?? this.isActive,
    );
  }
}

class Equipment {
  String id;
  String name;
  String type;
  String tier;
  int maxSockets;
  int activeSkillSockets;
  int supportSkillSockets;
  List<Gem> socketedGems;
  ActiveSkillGem? socketedActiveSkill;
  List<SupportSkillGem> socketedSupportSkills;

  static bool _supportsSkillLinks(String rawType) {
    final slot = Slots.key(rawType);
    return slot == 'helm' || slot == 'body armor' || slot == 'body_armor';
  }

  Equipment({
    required this.id,
    required this.name,
    required this.type,
    required this.tier,
    required this.maxSockets,
    int? activeSkillSockets,
    int? supportSkillSockets,
    this.socketedGems = const [],
    this.socketedActiveSkill,
    this.socketedSupportSkills = const [],
  }) : activeSkillSockets =
           (activeSkillSockets != null && activeSkillSockets > 0)
           ? activeSkillSockets
           : (_supportsSkillLinks(type)
                 ? 1
                 : Slots.defaultActiveSkillSockets(type)),
       supportSkillSockets =
           (supportSkillSockets != null && supportSkillSockets > 0)
           ? supportSkillSockets
           : (_supportsSkillLinks(type)
                 ? 1
                 : Slots.defaultSupportSkillSockets(type));

  static const List<String> accessoryStatIds = [
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

  static const List<String> _bodyAndLegStats = [
    'hp_flat',
    'hp_regen_flat',
    'hp_regen_%',
    'armor_flat',
    'mp_flat',
    'mp_regen_flat',
    'mp_regen_%',
  ];

  static const List<String> _beltStats = [
    'hp_flat',
    'hp_regen_flat',
    'hp_regen_%',
    'mp_flat',
    'mp_regen_flat',
    'mp_regen_%',
  ];

  bool get hasActiveSkill => socketedActiveSkill != null;

  bool canSocketGem(Gem gem) {
    if (socketedGems.length >= maxSockets) return false;

    final stat = gem.statType.toLowerCase().trim();
    final slot = Slots.key(type);

    switch (slot) {
      case 'helm':
        if (socketedGems.any((g) => g.statType.toLowerCase() == stat)) {
          return false;
        }
        return stat == 'evasion_%' || stat == 'precision_%';

      case 'pauldrons':
        if (socketedGems.isNotEmpty) return false;
        return const [
          'resistance_blunt',
          'resistance_piercing',
          'resistance_slash',
          'resistance_elemental',
        ].contains(stat);

      case 'gloves':
        if (socketedGems.length >= 2) return false;
        final isAtk = stat == 'atk_flat' || stat == 'atk_%';
        final isAtkSpeed = stat == 'atk_speed_flat' || stat == 'atk_speed_%';
        if (!isAtk && !isAtkSpeed) return false;

        final hasAtk = socketedGems.any(
          (g) =>
              g.statType.toLowerCase().startsWith('atk_') &&
              !g.statType.toLowerCase().startsWith('atk_speed'),
        );
        final hasAtkSpeed = socketedGems.any(
          (g) => g.statType.toLowerCase().startsWith('atk_speed'),
        );
        if (isAtk && hasAtk) return false;
        if (isAtkSpeed && hasAtkSpeed) return false;
        return true;

      case 'body armor':
      case 'body_armor':
      case 'leggings':
        if (socketedGems.any((g) => g.statType.toLowerCase() == stat)) {
          return false;
        }
        return _bodyAndLegStats.contains(stat);

      case 'belt':
        if (socketedGems.any((g) => g.statType.toLowerCase() == stat)) {
          return false;
        }
        return _beltStats.contains(stat);

      case 'boots':
        if (socketedGems.any((g) => g.statType.toLowerCase() == stat)) {
          return false;
        }
        return stat == 'movement_speed_flat' || stat == 'evasion_%';

      case 'necklace':
      case 'ring':
        return accessoryStatIds.contains(stat);

      default:
        return true;
    }
  }

  bool canSocketActiveSkill(ActiveSkillGem skill, {String? playerClassId}) {
    if (activeSkillSockets <= 0) return false;
    final restriction = skill.classRestriction.toLowerCase().trim();
    if (restriction == 'universal' || playerClassId == null) return true;
    return restriction == playerClassId.toLowerCase().trim();
  }

  String? validateSupportSkill(SupportSkillGem support) {
    if (supportSkillSockets <= 0) {
      return '${Slots.label(Slots.key(type))} cannot hold support gems.';
    }
    if (socketedActiveSkill == null) {
      return 'Socket an Active Skill first before adding support gems.';
    }
    if (socketedSupportSkills.length >= supportSkillSockets) {
      return 'All support sockets on this item are full.';
    }
    if (socketedSupportSkills.any((s) => s.id == support.id)) {
      return '${support.name} is already linked to this skill.';
    }
    if (support.isTrigger && socketedSupportSkills.any((s) => s.isTrigger)) {
      return 'Only 1 Trigger support gem can be linked per item.';
    }
    if (!support.isCompatibleWith(socketedActiveSkill!)) {
      return '${support.name} is not compatible with ${socketedActiveSkill!.name}.';
    }
    return null;
  }

  bool canSocketSupportSkill(SupportSkillGem support) =>
      validateSupportSkill(support) == null;

  int calculateLinkedMpCost({String playerClassId = 'vanguard'}) {
    final skill = socketedActiveSkill;
    if (skill == null || skill.baseMpCost <= 0) return 0;

    final tierMult = 1.0 + (skill.tierIndex * 0.10);
    double cost = skill.baseMpCost * tierMult;

    for (final support in socketedSupportSkills) {
      if (support.isCompatibleWith(skill)) {
        cost *= support.mpMultiplier;
      }
    }

    if (playerClassId.toLowerCase().trim() == 'arcanist') {
      cost *= 0.90;
    }

    return cost.round();
  }

  int calculateLinkedCooldown() {
    final skill = socketedActiveSkill;
    if (skill == null) return 0;

    int cd = skill.cooldown;
    for (final support in socketedSupportSkills) {
      if (support.id == 'supp_quicken' && support.isCompatibleWith(skill)) {
        final reduction = support.tierIndex >= 4 ? 2 : 1;
        cd = (cd - reduction).clamp(1, 99);
      }
    }
    return cd;
  }
}

class Gem {
  String statType;
  double value;
  bool isPercentage;
  String tier;

  Gem({
    required this.statType,
    required this.value,
    required this.isPercentage,
    this.tier = 'newbie',
  });
}

class ActiveSkillGem {
  final String id;
  final String name;
  final String classRestriction;
  final String category;
  final String? damageType;
  final int baseMpCost;
  final int cooldown;
  final List<String> tags;
  final String tier;
  final String effect;

  const ActiveSkillGem({
    required this.id,
    required this.name,
    required this.classRestriction,
    required this.category,
    this.damageType,
    required this.baseMpCost,
    required this.cooldown,
    required this.tags,
    this.tier = 'newbie',
    this.effect = '',
  });

  int get tierIndex {
    const tiers = [
      'newbie',
      'advance',
      'masterful',
      'elite',
      'legendary',
      'mythical',
    ];
    final i = tiers.indexOf(tier.toLowerCase().trim());
    return i < 0 ? 0 : i;
  }
}

class SupportSkillGem {
  final String id;
  final String name;
  final String group;
  final bool isTrigger;
  final List<String> compatibleTags;
  final double mpMultiplier;
  final double value;
  final String tier;
  final String effect;

  const SupportSkillGem({
    required this.id,
    required this.name,
    required this.group,
    this.isTrigger = false,
    required this.compatibleTags,
    required this.mpMultiplier,
    required this.value,
    this.tier = 'newbie',
    this.effect = '',
  });

  int get tierIndex {
    const tiers = [
      'newbie',
      'advance',
      'masterful',
      'elite',
      'legendary',
      'mythical',
    ];
    final i = tiers.indexOf(tier.toLowerCase().trim());
    return i < 0 ? 0 : i;
  }

  bool isCompatibleWith(ActiveSkillGem skill) {
    if (compatibleTags.contains('any')) return true;
    if (compatibleTags.contains('cooldown_2_plus')) {
      return skill.cooldown >= 2;
    }
    return compatibleTags.any((tag) => skill.tags.contains(tag));
  }
}
