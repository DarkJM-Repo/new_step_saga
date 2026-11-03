class PlayerProfile {
  String uid;
  String displayName;
  int currency;
  double totalMileageKm;
  int pvpKills;
  int pvpWins;
  Map<String, Equipment?> equippedGear;

  PlayerProfile({
    required this.uid,
    this.displayName = 'Hero',
    this.currency = 1500, // Starting test currency
    this.totalMileageKm = 0.0,
    this.pvpKills = 0,
    this.pvpWins = 0,
    required this.equippedGear,
  });
}

class Equipment {
  String id;
  String name;
  String type;
  String tier;
  int maxSockets;
  List<Gem> socketedGems;

  Equipment({
    required this.id,
    required this.name,
    required this.type,
    required this.tier,
    required this.maxSockets,
    this.socketedGems = const [],
  });

  bool canSocketGem(Gem gem) {
    if (socketedGems.length >= maxSockets) return false;

    switch (type.toLowerCase()) {
      case 'helm':
        return gem.statType == 'evasion_%' || gem.statType == 'precision_%';
      case 'pauldrons':
        bool hasRes = socketedGems.any(
          (g) => g.statType.contains('resistance'),
        );
        if (hasRes) return false;
        return [
          'resistance_blunt',
          'resistance_piercing',
          'resistance_slash',
          'resistance_elemental',
        ].contains(gem.statType);
      case 'gloves':
        if (socketedGems.length >= 2) return false;
        return gem.statType.contains('ATK');
      case 'boots':
        return gem.statType == 'movement_speed_flat' ||
            gem.statType == 'evasion_%';
      default:
        return true;
    }
  }
}

class Gem {
  String statType;
  double value;
  bool isPercentage;

  Gem({
    required this.statType,
    required this.value,
    required this.isPercentage,
  });
}
