# Gem catalog + rank restriction

gems.json -> 594 gems (396 stat, 108 active, 90 support), 99 per tier. Upload over gems.json in your GitHub shop repo.
Extra optional fields (old parser ignores them): classRestriction, skillCategory, damageType, mpCost, cooldown, supportGroup.

## 1. shop_screen.dart - rank-gate the Gems tab
Replace `_buildGemTab()` start and its call in TabBarView:

    // TabBarView, second child:
    StreamBuilder<int>(
      stream: _player.lifetimeStepsStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return _buildGemTab(RankService.rankFor(snap.data!));
      },
    ),

    Widget _buildGemTab(int rank) {
      final allowed = gemData.gems.where((g) => RankService.canAccess(rank, g.tier)).toList();
      final visibleGems = _gemFilter == 'all'
          ? allowed
          : allowed.where((g) => g.gemCategory == _gemFilter).toList();
      visibleGems.sort((a, b) {
        final t = RankService.tierIndex(a.tier).compareTo(RankService.tierIndex(b.tier));
        return t != 0 ? t : a.name.compareTo(b.name);
      });
      // ...rest unchanged, but use allowed.length in the 'All Gems (...)' chip
    }

PlayerService.buyItem already checks RankService.canAccess(rank, item.tier), and gems carry their tier, so the purchase is blocked server-side-in-transaction too.

## 2. shop_model.dart - extra stat ids in GemShopItem.normalizeStatId map
    'armor penetration': 'armor_pen_%', 'resist shred +%': 'resist_shred_%',
    'stun chance +%': 'stun_chance_%', 'bleed chance +%': 'bleed_chance_%',
    'poison chance +%': 'poison_chance_%', 'slow chance +%': 'slow_chance_%',
    'status resist +%': 'status_resist_%', 'mp leech +%': 'mp_leech_%',
    'thorns +%': 'thorns_%', 'counter chance +%': 'counter_chance_%',
    'step gold +%': 'step_gold_%', 'goal reduction +%': 'goal_reduction_%',
    'atk speed flat+': 'atk_speed_flat', 'atk speed %+': 'atk_speed_%',
    'hp regen flat+' / 'hp regen %+' / 'mp regen flat+' / 'mp regen %+' already exist.
Note: the json uses "ATK speed flat+" (lowercase compare handles it).

## 3. Link counts (4/3/2/0) - slots.dart
    defaultActiveSkillSockets: helm, body armor, gloves, belt, leggings, boots -> 1, else 0 (unchanged)
    defaultSupportSkillSockets: body armor, leggings -> 3; helm, gloves, boots -> 2; belt -> 1; else 0
Then delete `supportsSkillLinksForType` overrides (the "? 1 :" branches) in ShopItem ctor/fromJson and in Equipment ctor (game_models.dart) so they use these defaults.
