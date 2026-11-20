import 'dart:math';
import 'package:flutter/material.dart';
import '../models/shop_model.dart';
import '../models/slots.dart';
import '../services/player_service.dart';
import '../services/rank_service.dart';

enum _BackpackTab { gears, gems }

enum _GemSubTab { actives, supports, stats }

enum _GearSort { tier, slot, unequipped, name }

enum _GemSort { usage, tier, available, name }

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  static const Color _gold = Color(0xFFFFCD5A);

  final PlayerService _player = PlayerService();
  final Map<String, _GearSocketState> _socketsByGearId = {};
  String? _editingGearId; // ID of gear currently open in enchant dialog

  _BackpackTab _backpackTab = _BackpackTab.gears;
  _GemSubTab _gemSubTab = _GemSubTab.actives;
  _GearSort _gearSort = _GearSort.tier;
  _GemSort _gemSort = _GemSort.usage;

  static const List<String> _ringSlots = [
    'ring1',
    'ring2',
    'ring3',
    'ring4',
    'ring5',
    'ring6',
    'ring7',
    'ring8',
  ];

  static const Map<String, String> _labels = {
    'helm': 'Helm',
    'body_armor': 'Body Armor',
    'pauldrons': 'Pauldrons',
    'gloves': 'Gloves',
    'belt': 'Belt',
    'leggings': 'Leggings',
    'boots': 'Boots',
    'necklace': 'Necklace',
    'ring1': 'Ring 1',
    'ring2': 'Ring 2',
    'ring3': 'Ring 3',
    'ring4': 'Ring 4',
    'ring5': 'Ring 5',
    'ring6': 'Ring 6',
    'ring7': 'Ring 7',
    'ring8': 'Ring 8',
  };

  static const Map<String, String> _classDescriptions = {
    'vanguard': 'Vanguard (Tank · Blunt) — +10% Armor, +8% HP, Bulwark',
    'blademaster': 'Blademaster (Bruiser · Slash) — +8% ATK, +5% ATK Speed',
    'ranger': 'Ranger (Evasion/Crit · Piercing) — +10% Evasion, Opening Shot',
    'arcanist': 'Arcanist (Caster · Elemental) — +15% MP, -10% Skill MP Cost',
    'wayfarer': 'Wayfarer (Speed/Steps) — +8% Move Speed, Daily Stride',
  };

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncSocketMap(List<InventoryItem> allInv) {
    for (final inv in allInv) {
      if (inv.item.isGem) continue;
      // Skip the gear currently open in the enchant dialog — its local edits
      // must not be overwritten by a Firestore snapshot arriving mid-edit.
      if (inv.id == _editingGearId) continue;
      // Always sync from Firestore data so that unsocketed gems are reflected
      // immediately (even when all socket lists are now empty).
      final st = _socketsByGearId.putIfAbsent(inv.id, () => _GearSocketState());
      st.statGemIds
        ..clear()
        ..addAll(inv.socketedStatGemIds);
      st.activeGemId = inv.socketedActiveGemId;
      st.supportGemIds
        ..clear()
        ..addAll(inv.socketedSupportGemIds);
    }
  }

  Map<String, String> _buildGemUsageIndex(List<InventoryItem> allInv) {
    final usedBy = <String, String>{};
    for (final inv in allInv) {
      if (inv.item.isGem && inv.socketedInItemId != null) {
        usedBy[inv.id] = inv.socketedInItemId!;
      }
    }
    _socketsByGearId.forEach((gearId, st) {
      for (final gid in st.statGemIds) {
        usedBy[gid] = gearId;
      }
      if (st.activeGemId != null) {
        usedBy[st.activeGemId!] = gearId;
      }
      for (final sid in st.supportGemIds) {
        usedBy[sid] = gearId;
      }
    });
    return usedBy;
  }

  Set<String> _activeAccessoryGemIds(
    Map<String, InventoryItem> eq,
    Map<String, InventoryItem> invById,
  ) {
    final bestByStat = <String, ({String gemId, double val})>{};
    for (final entry in eq.entries) {
      final gear = entry.value;
      if (!Slots.isAccessory(gear.item.type)) continue;
      final st = _socketsByGearId[gear.id];
      if (st == null) continue;
      for (final gemId in st.statGemIds) {
        final gemItem = invById[gemId]?.item;
        if (gemItem == null) continue;
        final statKey = (gemItem.statType ?? gemItem.name).toLowerCase();
        final current = bestByStat[statKey];
        if (current == null || gemItem.value > current.val) {
          bestByStat[statKey] = (gemId: gemId, val: gemItem.value);
        }
      }
    }
    return bestByStat.values.map((e) => e.gemId).toSet();
  }

  Future<void> _equip(InventoryItem inv, Map<String, InventoryItem> eq) async {
    if (inv.item.isGem) {
      _toast('Gems must be socketed via the Enchant menu on a gear piece.');
      return;
    }
    final base = Slots.fileName(Slots.key(inv.item.type));
    if (base != 'ring' && !_labels.containsKey(base)) {
      _toast("This item type can't be equipped yet.");
      return;
    }

    final String? slot = base == 'ring' ? _firstFreeRing(eq) : base;
    if (slot == null) {
      _toast('All 8 ring slots are full. Unequip one first.');
      return;
    }

    try {
      await _player.equip(slot, inv);
    } catch (_) {
      if (mounted) _toast('Could not equip. Try again.');
    }
  }

  String? _firstFreeRing(Map<String, InventoryItem> eq) {
    for (final r in _ringSlots) {
      if (!eq.containsKey(r)) return r;
    }
    return null;
  }

  Future<void> _unequip(String slotKey) async {
    try {
      await _player.unequip(slotKey);
    } catch (_) {
      if (mounted) _toast('Could not unequip. Try again.');
    }
  }

  void _onSlotTap(
    String slotKey,
    Map<String, InventoryItem> eq,
    List<InventoryItem> allInv,
    Map<String, InventoryItem> invById,
    Map<String, String> gemUsedByGear,
    Set<String> activeAccGemIds,
  ) {
    final equipped = eq[slotKey];
    if (equipped == null) {
      _toast('Pick an item from your backpack to equip it.');
    } else {
      _showItemDialog(
        equipped,
        eq,
        allInv,
        invById,
        gemUsedByGear,
        activeAccGemIds,
        slotKey: slotKey,
      );
    }
  }

  void _showClassDialog(String currentClassId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1230),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _gold),
        ),
        title: const Text(
          'SELECT CLASS',
          style: TextStyle(
            color: _gold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _classDescriptions.entries.map((entry) {
              final selected = entry.key == currentClassId;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: selected ? _gold.withValues(alpha: 0.14) : Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? _gold : Colors.white24),
                ),
                child: ListTile(
                  onTap: () async {
                    await _player.setCharacterClass(entry.key);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _toast('Switched class to ${entry.key.toUpperCase()}.');
                  },
                  title: Text(
                    entry.key.toUpperCase(),
                    style: TextStyle(
                      color: selected ? _gold : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    entry.value,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: _gold)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showGemInspectDialog(
    InventoryItem gemInv,
    Map<String, InventoryItem> invById,
    Map<String, String> gemUsedByGear,
  ) {
    final gem = gemInv.item;
    final color = RankService.colorOfTier(gem.tier);
    final usedGearId = gemUsedByGear[gemInv.id];
    final usedGearName = usedGearId == null
        ? null
        : invById[usedGearId]?.item.name;

    String categoryLabel = 'Stat Gem';
    if (gem.isActiveSkillGem) categoryLabel = 'Active Skill Gem';
    if (gem.isSupportSkillGem) {
      categoryLabel =
          'Support Gem · ${ShopItem.supportGroupLabel(gem.resolvedSupportGroup)}';
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1230),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color),
        ),
        title: Text(
          gem.name,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$categoryLabel (${gem.tier.toUpperCase()})',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              gem.effect ??
                  gem.statType ??
                  (gem.isPercentage
                      ? '+${gem.value.toStringAsFixed(1)}%'
                      : '+${gem.value.round()}'),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            if (gem.isActiveSkillGem) ...[
              const SizedBox(height: 6),
              Text(
                'Base Cost: ${gem.baseMpCost} MP · Cooldown: ${gem.cooldown} turns',
                style: const TextStyle(color: _gold, fontSize: 11),
              ),
            ],
            if (gem.isSupportSkillGem) ...[
              const SizedBox(height: 6),
              Text(
                'MP Multiplier: ×${gem.mpMultiplier.toStringAsFixed(2)}${gem.isTrigger ? " · Trigger Support" : ""}',
                style: const TextStyle(color: _gold, fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: usedGearId != null
                    ? Colors.orange.withValues(alpha: 0.15)
                    : Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: usedGearId != null ? Colors.orange : Colors.green,
                ),
              ),
              child: Text(
                usedGearId != null
                    ? 'Status: IN USE inside ${usedGearName ?? "an item"} (1 gem = 1 item; buy another copy to use in multiple items).'
                    : 'Status: AVAILABLE to socket into 1 item.',
                style: TextStyle(
                  color: usedGearId != null
                      ? Colors.orangeAccent
                      : Colors.lightGreenAccent,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showItemDialog(
    InventoryItem inv,
    Map<String, InventoryItem> eq,
    List<InventoryItem> allInv,
    Map<String, InventoryItem> invById,
    Map<String, String> gemUsedByGear,
    Set<String> activeAccGemIds, {
    String? slotKey,
  }) {
    final item = inv.item;
    String? found = slotKey;
    if (found == null) {
      for (final e in eq.entries) {
        if (e.value.id == inv.id) {
          found = e.key;
          break;
        }
      }
    }
    final String? equippedSlot = found;
    final color = RankService.colorOfTier(item.tier);
    final st = _socketsByGearId.putIfAbsent(inv.id, () => _GearSocketState());
    final activeGem = st.activeGemId == null
        ? null
        : invById[st.activeGemId!]?.item;
    final supportGems = st.supportGemIds
        .map((id) => invById[id]?.item)
        .whereType<ShopItem>()
        .toList();
    final isAcc = Slots.isAccessory(item.type);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1230),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color),
        ),
        title: Text(
          item.name,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${Slots.label(item.type)} · ${item.tier.toUpperCase()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Text(
                  'Stat Sockets (${st.statGemIds.length}/${item.maxSockets})',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 4),
                if (item.maxSockets <= 0)
                  const Text('None', style: TextStyle(color: Colors.white38))
                else ...[
                  CustomPaint(
                    size: Size(item.maxSockets.clamp(1, 6) * 24.0, 20),
                    painter: _SocketPainter(
                      _statSocketColorsFor(inv, invById, activeAccGemIds),
                    ),
                  ),
                  for (final gid in st.statGemIds)
                    Builder(
                      builder: (_) {
                        final g = invById[gid]?.item;
                        if (g == null) return const SizedBox.shrink();
                        final active =
                            !isAcc ||
                            equippedSlot == null ||
                            activeAccGemIds.contains(gid);
                        return Text(
                          active
                              ? '• ${g.name} (${g.statType ?? ""})'
                              : '• ${g.name} (Greyed out: lower duplicate)',
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white38,
                            fontSize: 11,
                            decoration: active
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        );
                      },
                    ),
                ],
                if (item.canHaveSkills) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Skill Links (${item.totalLinks}-Link: 1 Active + ${item.supportSkillSockets} Support)',
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  CustomPaint(
                    size: Size(item.totalLinks * 24.0, 20),
                    painter: _SkillLinkPainter(
                      activeColor: activeGem == null
                          ? Colors.white24
                          : Slots.skillCategoryColor('active_skill'),
                      supportColors: List.generate(
                        item.supportSkillSockets,
                        (i) => i < supportGems.length
                            ? Slots.supportGroupColor(
                                supportGems[i].resolvedSupportGroup,
                              )
                            : Colors.white24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (activeGem == null)
                    const Text(
                      'No Active Skill socketed (Supports inactive without an Active Skill)',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    )
                  else ...[
                    Text(
                      'Active: ${activeGem.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final s in supportGems)
                      Text(
                        '  ↳ ${s.name} [${ShopItem.supportGroupLabel(s.resolvedSupportGroup)}]',
                        style: TextStyle(
                          color: Slots.supportGroupColor(
                            s.resolvedSupportGroup,
                          ),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: const Text('Enchant / Gems'),
            onPressed: () {
              Navigator.pop(ctx);
              _showEnchantDialog(inv, allInv, invById, gemUsedByGear);
            },
          ),
          if (equippedSlot != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _unequip(equippedSlot);
              },
              child: const Text('Unequip'),
            )
          else
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _equip(inv, eq);
              },
              child: const Text('Equip'),
            ),
        ],
      ),
    );
  }

  void _showEnchantDialog(
    InventoryItem gearInv,
    List<InventoryItem> allInv,
    Map<String, InventoryItem> invById,
    Map<String, String> initialUsedBy,
  ) {
    final item = gearInv.item;

    // Build a LOCAL copy of socket state for the dialog so that edits are
    // completely isolated from the shared _socketsByGearId map (which is
    // overwritten by _syncSocketMap on every Firestore snapshot).
    final shared = _socketsByGearId.putIfAbsent(
      gearInv.id,
      () => _GearSocketState(),
    );
    final localSt = _GearSocketState()
      ..statGemIds.addAll(shared.statGemIds)
      ..activeGemId = shared.activeGemId
      ..supportGemIds.addAll(shared.supportGemIds);

    // Mark this gear as being edited so _syncSocketMap skips it.
    setState(() => _editingGearId = gearInv.id);

    final slotKey = Slots.key(item.type);

    // Strictly filter by resolved gem category so that active/support gems
    // never bleed into the stat-gem list (and vice-versa).
    final ownedStatGems = allInv
        .where((i) => i.item.isGem && i.item.isStatGem)
        .toList();
    final ownedActiveGems = allInv
        .where((i) => i.item.isGem && i.item.isActiveSkillGem)
        .toList();
    final ownedSupportGems = allInv
        .where((i) => i.item.isGem && i.item.isSupportSkillGem)
        .toList();

    final attachedNow = <String>[];
    final detachedNow = <String>[];
    // st alias for local dialog state
    final st = localSt;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Build usage index from Firestore data (gem.socketedInItemId) only,
          // then overlay the current dialog's local state for this gear so
          // the "In Use" badges are accurate even before saving.
          final usedBy = <String, String>{};
          for (final inv in allInv) {
            if (inv.item.isGem && inv.socketedInItemId != null) {
              usedBy[inv.id] = inv.socketedInItemId!;
            }
          }
          // Overlay all OTHER gears from shared map.
          _socketsByGearId.forEach((gearId, s) {
            if (gearId == gearInv.id) return; // skip current gear
            for (final gid in s.statGemIds) {
              usedBy[gid] = gearId;
            }
            if (s.activeGemId != null) usedBy[s.activeGemId!] = gearId;
            for (final sid in s.supportGemIds) {
              usedBy[sid] = gearId;
            }
          });
          // Overlay local state for THIS gear.
          for (final gid in st.statGemIds) {
            usedBy[gid] = gearInv.id;
          }
          if (st.activeGemId != null) usedBy[st.activeGemId!] = gearInv.id;
          for (final sid in st.supportGemIds) {
            usedBy[sid] = gearInv.id;
          }


          bool isSlotAllowed(ShopItem gem) {
            if (gem.allowedSlots.isEmpty) return true;
            return gem.allowedSlots.contains(slotKey);
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1B1230),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: _gold),
            ),
            title: Text(
              'ENCHANT · ${item.name}',
              style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            content: SizedBox(
              width: 500,
              height: 360,
              child: DefaultTabController(
                length: item.canHaveSkills ? 2 : 1,
                child: Column(
                  children: [
                    TabBar(
                      indicatorColor: _gold,
                      labelColor: _gold,
                      unselectedLabelColor: Colors.white60,
                      tabs: [
                        Tab(
                          text:
                              'Stat Gems (${st.statGemIds.length}/${item.maxSockets})',
                        ),
                        if (item.canHaveSkills)
                          Tab(
                            text:
                                'Skill Link (${(st.activeGemId == null ? 0 : 1) + st.supportGemIds.length}/${item.totalLinks})',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (st.statGemIds.isNotEmpty) ...[
                                  const Text(
                                    'Socketed (tap × to unsocket & free gem):',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: st.statGemIds.map((gid) {
                                      final g = invById[gid]?.item;
                                      return InputChip(
                                        label: Text(
                                          g?.name ?? gid,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        onDeleted: () {
                                          setDialogState(() {
                                            st.statGemIds.remove(gid);
                                            detachedNow.add(gid);
                                            attachedNow.remove(gid);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const Divider(color: Colors.white24),
                                ],
                                const Text(
                                  'Owned Stat Gems in Backpack:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (ownedStatGems.isEmpty)
                                  const Text(
                                    'No Stat Gems in backpack. Buy them in the Marketplace.',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: ownedStatGems.map((gInv) {
                                      final usedGearId = usedBy[gInv.id];
                                      final inUse = usedGearId != null;
                                      final allowed = isSlotAllowed(gInv.item);
                                      return ActionChip(
                                        backgroundColor: inUse || !allowed
                                            ? Colors.white10
                                            : Slots.statColor(
                                                gInv.item.statType ?? '',
                                              ).withValues(alpha: 0.25),
                                        label: Text(
                                          inUse
                                              ? '${gInv.item.name} [In Use]'
                                              : gInv.item.name,
                                          style: TextStyle(
                                            color: inUse || !allowed
                                                ? Colors.white38
                                                : Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                        onPressed: () {
                                          if (inUse) {
                                            _toast(
                                              'This gem is already socketed in another item. Buy another copy to use more than 1.',
                                            );
                                            return;
                                          }
                                          if (!gInv.item.isStatGem) {
                                            _toast(
                                              'Only Stat Gems can be placed in Stat Sockets.',
                                            );
                                            return;
                                          }
                                          if (!allowed) {
                                            _toast(
                                              '${gInv.item.name} cannot be socketed into ${Slots.label(item.type)}.',
                                            );
                                            return;
                                          }
                                          if (st.statGemIds.length >=
                                              item.maxSockets) {
                                            _toast(
                                              'No free stat sockets left.',
                                            );
                                            return;
                                          }
                                          setDialogState(() {
                                            st.statGemIds.add(gInv.id);
                                            attachedNow.add(gInv.id);
                                            detachedNow.remove(gInv.id);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                          if (item.canHaveSkills)
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (st.activeGemId != null)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black38,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _gold.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Active: ${invById[st.activeGemId!]?.item.name ?? st.activeGemId}',
                                                  style: const TextStyle(
                                                    color: _gold,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: Colors.white60,
                                                ),
                                                onPressed: () {
                                                  setDialogState(() {
                                                    if (st.activeGemId !=
                                                        null) {
                                                      detachedNow.add(
                                                        st.activeGemId!,
                                                      );
                                                    }
                                                    detachedNow.addAll(
                                                      st.supportGemIds,
                                                    );
                                                    st.activeGemId = null;
                                                    st.supportGemIds.clear();
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          if (st.supportGemIds.isNotEmpty)
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: st.supportGemIds.map((
                                                sid,
                                              ) {
                                                return InputChip(
                                                  label: Text(
                                                    invById[sid]?.item.name ??
                                                        sid,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  onDeleted: () {
                                                    setDialogState(() {
                                                      st.supportGemIds.remove(
                                                        sid,
                                                      );
                                                      detachedNow.add(sid);
                                                      attachedNow.remove(sid);
                                                    });
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                        ],
                                      ),
                                    ),
                                  const Text(
                                    '1. Active Skill Gem (Max 1 per item):',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (ownedActiveGems.isEmpty)
                                    const Text(
                                      'No Active Skill Gems in backpack.',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: ownedActiveGems.map((gInv) {
                                        final inUse = usedBy[gInv.id] != null;
                                        return ActionChip(
                                          backgroundColor: inUse
                                              ? Colors.white10
                                              : Slots.skillCategoryColor(
                                                  'active_skill',
                                                ).withValues(alpha: 0.24),
                                          label: Text(
                                            inUse
                                                ? '${gInv.item.name} [In Use]'
                                                : gInv.item.name,
                                            style: TextStyle(
                                              color: inUse
                                                  ? Colors.white38
                                                  : Colors.white,
                                              fontSize: 11,
                                            ),
                                          ),
                                          onPressed: () {
                                            if (inUse) {
                                              _toast(
                                                'This Active Gem is already equipped in another item.',
                                              );
                                              return;
                                            }
                                            setDialogState(() {
                                              if (st.activeGemId != null) {
                                                detachedNow.add(
                                                  st.activeGemId!,
                                                );
                                              }
                                              st.activeGemId = gInv.id;
                                              attachedNow.add(gInv.id);
                                              detachedNow.remove(gInv.id);
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '2. Universal Support Gems (${st.supportGemIds.length}/${item.supportSkillSockets}):',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (ownedSupportGems.isEmpty)
                                    const Text(
                                      'No Support Gems in backpack.',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: ownedSupportGems.map((gInv) {
                                        final inUse = usedBy[gInv.id] != null;
                                        final noActive = st.activeGemId == null;
                                        final full =
                                            st.supportGemIds.length >=
                                            item.supportSkillSockets;
                                        final disabled =
                                            inUse || noActive || full;
                                        return ActionChip(
                                          backgroundColor: disabled
                                              ? Colors.white10
                                              : Slots.supportGroupColor(
                                                  gInv
                                                      .item
                                                      .resolvedSupportGroup,
                                                ).withValues(alpha: 0.25),
                                          label: Text(
                                            inUse
                                                ? '${gInv.item.name} [In Use]'
                                                : gInv.item.name,
                                            style: TextStyle(
                                              color: disabled
                                                  ? Colors.white38
                                                  : Colors.white,
                                              fontSize: 11,
                                            ),
                                          ),
                                          onPressed: () {
                                            if (inUse) {
                                              _toast(
                                                'This Support Gem is already used in another item.',
                                              );
                                              return;
                                            }
                                            if (noActive) {
                                              _toast(
                                                'Socket an Active Skill Gem first before linking Supports.',
                                              );
                                              return;
                                            }
                                            if (full) {
                                              _toast(
                                                'All ${item.supportSkillSockets} support sockets on this piece are full.',
                                              );
                                              return;
                                            }
                                            final alreadyHasSameName = st
                                                .supportGemIds
                                                .any(
                                                  (id) =>
                                                      invById[id]?.item.name ==
                                                      gInv.item.name,
                                                );
                                            if (alreadyHasSameName) {
                                              _toast(
                                                'Cannot link two copies of ${gInv.item.name} on the same item.',
                                              );
                                              return;
                                            }
                                            setDialogState(() {
                                              st.supportGemIds.add(gInv.id);
                                              attachedNow.add(gInv.id);
                                              detachedNow.remove(gInv.id);
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _player.saveItemSockets(
                    gearInvId: gearInv.id,
                    statGemIds: List<String>.from(st.statGemIds),
                    activeGemId: st.activeGemId,
                    supportGemIds: List<String>.from(st.supportGemIds),
                    newlyAttachedGemIds: attachedNow,
                    detachedGemIds: detachedNow,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save & Close'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      // Dialog fully closed — allow _syncSocketMap to resume syncing this gear
      // from Firestore (which now has the saved values), and reflect any
      // in-dialog edits back to the shared map for immediate local display.
      if (mounted) {
        setState(() {
          final s = _socketsByGearId.putIfAbsent(
            gearInv.id,
            () => _GearSocketState(),
          );
          s.statGemIds
            ..clear()
            ..addAll(localSt.statGemIds);
          s.activeGemId = localSt.activeGemId;
          s.supportGemIds
            ..clear()
            ..addAll(localSt.supportGemIds);
          _editingGearId = null;
        });
      }
    });
  }

  List<Color> _statSocketColorsFor(
    InventoryItem inv,
    Map<String, InventoryItem> invById,
    Set<String> activeAccGemIds,
  ) {
    final item = inv.item;
    final st = _socketsByGearId[inv.id];
    final isAcc = Slots.isAccessory(item.type);

    return List.generate(item.maxSockets.clamp(0, 6), (i) {
      if (st != null && i < st.statGemIds.length) {
        final gemId = st.statGemIds[i];
        final gemItem = invById[gemId]?.item;
        if (isAcc && !activeAccGemIds.contains(gemId)) {
          return Colors.grey.shade700;
        }
        return Slots.statColor(gemItem?.statType ?? gemItem?.name ?? '');
      }
      if (item.allowedStats.isEmpty) return const Color(0xFFD9B35A);
      return Slots.statColor(
        item.allowedStats[i % item.allowedStats.length],
      ).withValues(alpha: 0.35);
    });
  }

  Widget _panel(String title, Widget child, {Widget? headerTrailing}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.6), width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE61B1230), Color(0xF00E081C)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black38,
                border: Border(
                  bottom: BorderSide(color: _gold.withValues(alpha: 0.4)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      fontSize: 13,
                    ),
                  ),
                  if (headerTrailing != null) ...[
                    const Spacer(),
                    headerTrailing,
                  ],
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _slot(
    String key,
    double w,
    double h,
    Map<String, InventoryItem> eq,
    List<InventoryItem> allInv,
    Map<String, InventoryItem> invById,
    Map<String, String> gemUsedByGear,
    Set<String> activeAccGemIds,
  ) {
    final equipped = eq[key];
    final st = equipped == null ? null : _socketsByGearId[equipped.id];

    return _SlotBox(
      slotKey: key,
      label: _labels[key] ?? key,
      width: w,
      height: h,
      equipped: equipped,
      statSocketColors: equipped == null
          ? const []
          : _statSocketColorsFor(equipped, invById, activeAccGemIds),
      activeSkillColor: st?.activeGemId == null
          ? Colors.white24
          : Slots.skillCategoryColor('active_skill'),
      supportSkillColors: equipped == null
          ? const []
          : List.generate(equipped.item.supportSkillSockets, (i) {
              if (st == null || i >= st.supportGemIds.length) {
                return Colors.white24;
              }
              final suppItem = invById[st.supportGemIds[i]]?.item;
              return Slots.supportGroupColor(
                suppItem?.resolvedSupportGroup ?? 'offense',
              );
            }),
      onTap: () =>
          _onSlotTap(key, eq, allInv, invById, gemUsedByGear, activeAccGemIds),
    );
  }

  Widget _ringBank(
    Map<String, InventoryItem> eq,
    List<InventoryItem> allInv,
    Map<String, InventoryItem> invById,
    Map<String, String> gemUsedByGear,
    Set<String> activeAccGemIds,
  ) {
    return Column(
      children: [
        const Text(
          'RINGS',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < 4; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r < 3 ? 6 : 0),
            child: Row(
              children: [
                _slot(
                  'ring${r * 2 + 1}',
                  44,
                  44,
                  eq,
                  allInv,
                  invById,
                  gemUsedByGear,
                  activeAccGemIds,
                ),
                const SizedBox(width: 6),
                _slot(
                  'ring${r * 2 + 2}',
                  44,
                  44,
                  eq,
                  allInv,
                  invById,
                  gemUsedByGear,
                  activeAccGemIds,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _paperDoll(
    Map<String, InventoryItem> eq,
    List<InventoryItem> allInv,
    Map<String, InventoryItem> invById,
    Map<String, String> gemUsedByGear,
    Set<String> activeAccGemIds,
  ) {
    const gap = SizedBox(height: 8);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _slot(
              'pauldrons',
              76,
              76,
              eq,
              allInv,
              invById,
              gemUsedByGear,
              activeAccGemIds,
            ),
            gap,
            _slot(
              'gloves',
              76,
              76,
              eq,
              allInv,
              invById,
              gemUsedByGear,
              activeAccGemIds,
            ),
            gap,
            _slot(
              'necklace',
              56,
              56,
              eq,
              allInv,
              invById,
              gemUsedByGear,
              activeAccGemIds,
            ),
          ],
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            _slot(
              'helm',
              84,
              84,
              eq,
              allInv,
              invById,
              gemUsedByGear,
              activeAccGemIds,
            ),
            gap,
            _slot(
              'body_armor',
              100,
              150,
              eq,
              allInv,
              invById,
              gemUsedByGear,
              activeAccGemIds,
            ),
            gap,
            _slot(
              'belt',
              100,
              62,
              eq,
              allInv,
              invById,
              gemUsedByGear,
              activeAccGemIds,
            ),
          ],
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            _slot(
              'leggings',
              88,
              104,
              eq,
              allInv,
              invById,
              gemUsedByGear,
              activeAccGemIds,
            ),
            gap,
            _slot(
              'boots',
              76,
              76,
              eq,
              allInv,
              invById,
              gemUsedByGear,
              activeAccGemIds,
            ),
          ],
        ),
        const SizedBox(width: 18),
        _ringBank(eq, allInv, invById, gemUsedByGear, activeAccGemIds),
      ],
    );
  }

  Widget _gearBagCell(
    InventoryItem inv,
    bool isEquipped,
    Map<String, InventoryItem> eq,
    List<InventoryItem> allInv,
    Map<String, InventoryItem> invById,
    Map<String, String> gemUsedByGear,
    Set<String> activeAccGemIds,
  ) {
    final item = inv.item;
    final color = RankService.colorOfTier(item.tier);
    return GestureDetector(
      onTap: () => _showItemDialog(
        inv,
        eq,
        allInv,
        invById,
        gemUsedByGear,
        activeAccGemIds,
      ),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1536), Color(0xFF0D0818)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1.6),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Opacity(
                  opacity: isEquipped ? 0.45 : 1,
                  child: Slots.gearImage(item.type, item.tier),
                ),
              ),
            ),
            if (isEquipped)
              const Positioned(
                top: 2,
                right: 4,
                child: Text(
                  'E',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _gemBagCell(
    InventoryItem gemInv,
    Map<String, InventoryItem> invById,
    Map<String, String> gemUsedByGear,
  ) {
    final gem = gemInv.item;
    final inUse = gemUsedByGear.containsKey(gemInv.id);
    final Color badgeColor = gem.isActiveSkillGem
        ? Slots.skillCategoryColor('active_skill')
        : gem.isSupportSkillGem
        ? Slots.supportGroupColor(gem.resolvedSupportGroup)
        : Slots.statColor(gem.statType ?? gem.name);
    final tierColor = RankService.colorOfTier(gem.tier);

    return GestureDetector(
      onTap: () => _showGemInspectDialog(gemInv, invById, gemUsedByGear),
      child: Container(
        width: 64,
        height: 68,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1536), Color(0xFF0D0818)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: inUse ? Colors.white24 : tierColor,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Opacity(
              opacity: inUse ? 0.42 : 1.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    gem.isActiveSkillGem
                        ? Icons.local_fire_department
                        : gem.isSupportSkillGem
                        ? Icons.extension
                        : Icons.diamond,
                    color: badgeColor,
                    size: 22,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    gem.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            if (inUse)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'IN USE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 6.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _backpack(
    List<InventoryItem> allInv,
    Map<String, InventoryItem> eq,
    Map<String, InventoryItem> invById,
    Map<String, String> gemUsedByGear,
    Set<String> activeAccGemIds,
  ) {
    final gears = allInv.where((i) => !i.item.isGem).toList();
    final gems = allInv.where((i) => i.item.isGem).toList();
    final equippedIds = eq.values.map((e) => e.id).toSet();

    gears.sort((a, b) {
      switch (_gearSort) {
        case _GearSort.tier:
          final t = RankService.tierIndex(
            b.item.tier,
          ).compareTo(RankService.tierIndex(a.item.tier));
          if (t != 0) return t;
          return Slots.rank(a.item.type).compareTo(Slots.rank(b.item.type));
        case _GearSort.slot:
          final s = Slots.rank(a.item.type).compareTo(Slots.rank(b.item.type));
          if (s != 0) return s;
          return RankService.tierIndex(
            b.item.tier,
          ).compareTo(RankService.tierIndex(a.item.tier));
        case _GearSort.unequipped:
          final ae = equippedIds.contains(a.id) ? 1 : 0;
          final be = equippedIds.contains(b.id) ? 1 : 0;
          if (ae != be) return ae.compareTo(be);
          return RankService.tierIndex(
            b.item.tier,
          ).compareTo(RankService.tierIndex(a.item.tier));
        case _GearSort.name:
          return a.item.name.compareTo(b.item.name);
      }
    });

    final filteredGems = gems.where((g) {
      switch (_gemSubTab) {
        case _GemSubTab.actives:
          return g.item.isActiveSkillGem;
        case _GemSubTab.supports:
          return g.item.isSupportSkillGem;
        case _GemSubTab.stats:
          return g.item.isStatGem;
      }
    }).toList();

    filteredGems.sort((a, b) {
      switch (_gemSort) {
        case _GemSort.usage:
          if (_gemSubTab == _GemSubTab.supports) {
            final gr = ShopItem.supportGroupRank(
              a.item.resolvedSupportGroup,
            ).compareTo(ShopItem.supportGroupRank(b.item.resolvedSupportGroup));
            if (gr != 0) return gr;
          } else if (_gemSubTab == _GemSubTab.stats) {
            final stCmp = (a.item.statType ?? '').compareTo(
              b.item.statType ?? '',
            );
            if (stCmp != 0) return stCmp;
          }
          return RankService.tierIndex(
            b.item.tier,
          ).compareTo(RankService.tierIndex(a.item.tier));
        case _GemSort.tier:
          return RankService.tierIndex(
            b.item.tier,
          ).compareTo(RankService.tierIndex(a.item.tier));
        case _GemSort.available:
          final au = gemUsedByGear.containsKey(a.id) ? 1 : 0;
          final bu = gemUsedByGear.containsKey(b.id) ? 1 : 0;
          if (au != bu) return au.compareTo(bu);
          return a.item.name.compareTo(b.item.name);
        case _GemSort.name:
          return a.item.name.compareTo(b.item.name);
      }
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: _tabButton(
                  label: 'GEARS (${gears.length})',
                  active: _backpackTab == _BackpackTab.gears,
                  onTap: () =>
                      setState(() => _backpackTab = _BackpackTab.gears),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _tabButton(
                  label: 'GEMS (${gems.length})',
                  active: _backpackTab == _BackpackTab.gems,
                  onTap: () => setState(() => _backpackTab = _BackpackTab.gems),
                ),
              ),
            ],
          ),
        ),
        if (_backpackTab == _BackpackTab.gems)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: _subTabChip(
                    label: 'Actives',
                    selected: _gemSubTab == _GemSubTab.actives,
                    onTap: () =>
                        setState(() => _gemSubTab = _GemSubTab.actives),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _subTabChip(
                    label: 'Supports',
                    selected: _gemSubTab == _GemSubTab.supports,
                    onTap: () =>
                        setState(() => _gemSubTab = _GemSubTab.supports),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _subTabChip(
                    label: 'Stat Gems',
                    selected: _gemSubTab == _GemSubTab.stats,
                    onTap: () => setState(() => _gemSubTab = _GemSubTab.stats),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            children: [
              const Icon(Icons.sort, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              const Text(
                'Sort:',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 6),
              if (_backpackTab == _BackpackTab.gears)
                DropdownButton<_GearSort>(
                  value: _gearSort,
                  dropdownColor: const Color(0xFF1B1230),
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: const TextStyle(color: _gold, fontSize: 11),
                  items: const [
                    DropdownMenuItem(
                      value: _GearSort.tier,
                      child: Text('Tier (Best First)'),
                    ),
                    DropdownMenuItem(
                      value: _GearSort.slot,
                      child: Text('Equipment Slot'),
                    ),
                    DropdownMenuItem(
                      value: _GearSort.unequipped,
                      child: Text('Unequipped First'),
                    ),
                    DropdownMenuItem(
                      value: _GearSort.name,
                      child: Text('Name (A–Z)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _gearSort = v);
                  },
                )
              else
                DropdownButton<_GemSort>(
                  value: _gemSort,
                  dropdownColor: const Color(0xFF1B1230),
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: const TextStyle(color: _gold, fontSize: 11),
                  items: const [
                    DropdownMenuItem(
                      value: _GemSort.usage,
                      child: Text('Gem Usage / Group'),
                    ),
                    DropdownMenuItem(
                      value: _GemSort.available,
                      child: Text('Available First'),
                    ),
                    DropdownMenuItem(
                      value: _GemSort.tier,
                      child: Text('Tier (Best First)'),
                    ),
                    DropdownMenuItem(
                      value: _GemSort.name,
                      child: Text('Name (A–Z)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _gemSort = v);
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 8, color: Colors.white12),
        Expanded(
          child: _backpackTab == _BackpackTab.gears
              ? (gears.isEmpty
                    ? const Center(
                        child: Text(
                          'No equipment in backpack.\nBuy gear in the Marketplace.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final it in gears)
                              _gearBagCell(
                                it,
                                equippedIds.contains(it.id),
                                eq,
                                allInv,
                                invById,
                                gemUsedByGear,
                                activeAccGemIds,
                              ),
                          ],
                        ),
                      ))
              : (filteredGems.isEmpty
                    ? Center(
                        child: Text(
                          'No ${_gemSubTab.name} gems owned yet.\nBuy gems in the Marketplace.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : _gemSubTab == _GemSubTab.supports &&
                          _gemSort == _GemSort.usage
                    ? _groupedSupportsList(filteredGems, invById, gemUsedByGear)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final g in filteredGems)
                              _gemBagCell(g, invById, gemUsedByGear),
                          ],
                        ),
                      )),
        ),
      ],
    );
  }

  Widget _groupedSupportsList(
    List<InventoryItem> supports,
    Map<String, InventoryItem> invById,
    Map<String, String> gemUsedByGear,
  ) {
    final grouped = <String, List<InventoryItem>>{};
    for (final s in supports) {
      grouped.putIfAbsent(s.item.resolvedSupportGroup, () => []).add(s);
    }
    final keys = grouped.keys.toList()
      ..sort(
        (a, b) => ShopItem.supportGroupRank(
          a,
        ).compareTo(ShopItem.supportGroupRank(b)),
      );

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        for (final groupKey in keys) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 4),
            child: Text(
              ShopItem.supportGroupLabel(groupKey).toUpperCase(),
              style: TextStyle(
                color: Slots.supportGroupColor(groupKey),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in grouped[groupKey]!)
                _gemBagCell(g, invById, gemUsedByGear),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _tabButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? _gold.withValues(alpha: 0.2) : Colors.black26,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? _gold : Colors.white24,
            width: active ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? _gold : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _subTabChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? _gold.withValues(alpha: 0.8) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 10,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/bg_dashboard.png', fit: BoxFit.cover),
        Container(color: Colors.black.withValues(alpha: 0.35)),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            toolbarHeight: 48,
            title: const Text(
              'CHARACTER',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
            actions: [
              StreamBuilder<String>(
                stream: _player.classStream(),
                initialData: 'vanguard',
                builder: (context, snap) {
                  final classId = snap.data ?? 'vanguard';
                  return GestureDetector(
                    onTap: () => _showClassDialog(classId),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _gold),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shield_moon,
                              size: 13,
                              color: _gold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              classId.toUpperCase(),
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              StreamBuilder<int>(
                stream: _player.lifetimeStepsStream(),
                initialData: 0,
                builder: (context, snap) {
                  final rank = RankService.rankFor(snap.data ?? 0);
                  final color = RankService.colorOf(rank);
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color),
                      ),
                      child: Text(
                        RankService.nameOf(rank).toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: StreamBuilder(
            stream: _player.equippedStream(),
            builder: (context, eqSnap) {
              final eq = eqSnap.data ?? const <String, InventoryItem>{};
              return StreamBuilder<List<InventoryItem>>(
                stream: _player.inventoryStream(),
                builder: (context, invSnap) {
                  final allInv = invSnap.data ?? const <InventoryItem>[];
                  _syncSocketMap(allInv);
                  final invById = {for (final i in allInv) i.id: i};
                  final gemUsedByGear = _buildGemUsageIndex(allInv);
                  final activeAccGemIds = _activeAccessoryGemIds(eq, invById);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _panel(
                            'EQUIPMENT',
                            Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: _paperDoll(
                                    eq,
                                    allInv,
                                    invById,
                                    gemUsedByGear,
                                    activeAccGemIds,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 9,
                          child: _panel(
                            'BACKPACK',
                            _backpack(
                              allInv,
                              eq,
                              invById,
                              gemUsedByGear,
                              activeAccGemIds,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GearSocketState {
  final List<String> statGemIds = [];
  String? activeGemId;
  final List<String> supportGemIds = [];
}

class _SlotBox extends StatelessWidget {
  final String slotKey;
  final String label;
  final double width;
  final double height;
  final InventoryItem? equipped;
  final List<Color> statSocketColors;
  final Color activeSkillColor;
  final List<Color> supportSkillColors;
  final VoidCallback onTap;

  const _SlotBox({
    required this.slotKey,
    required this.label,
    required this.width,
    required this.height,
    required this.equipped,
    required this.statSocketColors,
    required this.activeSkillColor,
    required this.supportSkillColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = equipped?.item;
    final color = item == null
        ? const Color(0xFF8A7440)
        : RankService.colorOfTier(item.tier);
    final iconKey = slotKey.startsWith('ring')
        ? 'ring'
        : slotKey.replaceAll('_', ' ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1536), Color(0xFF0D0818)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: item == null ? color.withValues(alpha: 0.55) : color,
            width: item == null ? 1.2 : 2,
          ),
          boxShadow: item == null
              ? null
              : [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)],
        ),
        child: item == null ? _empty(iconKey) : _filled(item),
      ),
    );
  }

  Widget _empty(String iconKey) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Slots.icon(iconKey),
            size: min(width, height) * 0.38,
            color: Colors.white24,
          ),
          if (height >= 56)
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white30, fontSize: 9),
            ),
        ],
      ),
    );
  }

  Widget _filled(ShopItem item) {
    final showStatSockets = item.maxSockets > 0;
    final showSkillLinks = item.canHaveSkills;
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              4,
              showSkillLinks ? 16 : 4,
              4,
              showStatSockets ? (height >= 56 ? 18 : 13) : 4,
            ),
            child: Slots.gearImage(item.type, item.tier),
          ),
        ),
        if (showSkillLinks)
          Positioned(
            left: 4,
            right: 4,
            top: 3,
            height: 12,
            child: CustomPaint(
              painter: _SkillLinkPainter(
                activeColor: activeSkillColor,
                supportColors: supportSkillColors,
              ),
            ),
          ),
        if (showStatSockets)
          Positioned(
            left: 4,
            right: 4,
            bottom: 3,
            height: height >= 56 ? 14 : 9,
            child: CustomPaint(painter: _SocketPainter(statSocketColors)),
          ),
      ],
    );
  }
}

class _SkillLinkPainter extends CustomPainter {
  final Color activeColor;
  final List<Color> supportColors;

  const _SkillLinkPainter({
    required this.activeColor,
    required this.supportColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = 1 + supportColors.length;
    final r = min(size.height / 2 - 0.8, size.width / (total * 2.9));
    final step = r * 2.65;
    final startX = size.width / 2 - step * (total - 1) / 2;
    final cy = size.height / 2;

    final link = Paint()
      ..color = const Color(0xFFFFCD5A)
      ..strokeWidth = max(1.4, r * 0.35);
    for (var i = 0; i < total - 1; i++) {
      canvas.drawLine(
        Offset(startX + i * step, cy),
        Offset(startX + (i + 1) * step, cy),
        link,
      );
    }

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF2A1B10)
      ..strokeWidth = 1.2;

    final ac = Offset(startX, cy);
    final diamond = Path()
      ..moveTo(ac.dx, ac.dy - r * 1.15)
      ..lineTo(ac.dx + r * 1.15, ac.dy)
      ..lineTo(ac.dx, ac.dy + r * 1.15)
      ..lineTo(ac.dx - r * 1.15, ac.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = activeColor);
    canvas.drawPath(diamond, rim);

    for (var i = 0; i < supportColors.length; i++) {
      final sc = Offset(startX + (i + 1) * step, cy);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: sc, width: r * 1.85, height: r * 1.85),
        Radius.circular(r * 0.35),
      );
      canvas.drawRRect(rect, Paint()..color = supportColors[i]);
      canvas.drawRRect(rect, rim);
    }
  }

  @override
  bool shouldRepaint(covariant _SkillLinkPainter oldDelegate) =>
      oldDelegate.activeColor != activeColor ||
      oldDelegate.supportColors != supportColors;
}

class _SocketPainter extends CustomPainter {
  final List<Color> colors;
  const _SocketPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final n = colors.length;
    if (n == 0) return;

    final r = min(size.height / 2 - 1, size.width / (n * 3.0));
    final step = r * 2.8;
    final startX = size.width / 2 - step * (n - 1) / 2;
    final cy = size.height / 2;

    final link = Paint()
      ..color = const Color(0xFFD9B35A)
      ..strokeWidth = max(1.4, r * 0.35);
    for (var i = 0; i < n - 1; i++) {
      canvas.drawLine(
        Offset(startX + i * step, cy),
        Offset(startX + (i + 1) * step, cy),
        link,
      );
    }

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF2A1B10)
      ..strokeWidth = 1.3;
    for (var i = 0; i < n; i++) {
      final c = Offset(startX + i * step, cy);
      canvas.drawCircle(c, r, Paint()..color = colors[i]);
      canvas.drawCircle(c, r, rim);
      canvas.drawCircle(
        c.translate(-r * 0.3, -r * 0.3),
        r * 0.25,
        Paint()..color = Colors.white70,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SocketPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
