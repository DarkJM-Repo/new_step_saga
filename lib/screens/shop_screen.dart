import 'dart:math';

import 'package:flutter/material.dart';
import '../models/shop_model.dart';
import '../models/slots.dart';
import '../services/api_controller.dart';
import '../services/player_service.dart';
import '../services/rank_service.dart';

class ShopScreen extends StatefulWidget {
  final int currentCurrency;
  const ShopScreen({super.key, this.currentCurrency = 0});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const int _perSlotStock = 4;

  late ShopData shopData;
  GemShopData gemData = GemShopData(gems: []);
  bool isDataLoaded = false;

  final ApiController _apiController = ApiController();
  final PlayerService _player = PlayerService();

  String _selectedSlot = 'all';
  String _gemFilter = 'all'; // 'all', 'stat', 'active_skill', 'support_skill'
  String? _buying;

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    final results = await Future.wait([
      _apiController.fetchShopItems(),
      _apiController.fetchGems(),
    ]);
    if (!mounted) return;
    setState(() {
      shopData = results[0] as ShopData;
      gemData = results[1] as GemShopData;
      isDataLoaded = true;
    });
  }

  int _stableHash(String s) =>
      s.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff);

  List<ShopItem> _stockFor(int rank) {
    final bySlot = <String, List<ShopItem>>{};
    for (final item in shopData.items) {
      if (!RankService.canAccess(rank, item.tier)) continue;
      bySlot.putIfAbsent(Slots.key(item.type), () => []).add(item);
    }

    final now = DateTime.now();
    final day = now.year * 10000 + now.month * 100 + now.day;

    final stock = <ShopItem>[];
    for (final entry in bySlot.entries) {
      final list = [...entry.value];
      list.sort((a, b) {
        final t = RankService.tierIndex(
          a.tier,
        ).compareTo(RankService.tierIndex(b.tier));
        return t != 0 ? t : a.name.compareTo(b.name);
      });
      list.shuffle(Random(day * 31 + rank * 997 + _stableHash(entry.key)));
      stock.addAll(list.take(_perSlotStock));
    }

    stock.sort((a, b) {
      final s = Slots.rank(
        Slots.key(a.type),
      ).compareTo(Slots.rank(Slots.key(b.type)));
      if (s != 0) return s;
      final sk = Slots.key(a.type).compareTo(Slots.key(b.type));
      if (sk != 0) return sk;
      final t = RankService.tierIndex(
        a.tier,
      ).compareTo(RankService.tierIndex(b.tier));
      return t != 0 ? t : a.name.compareTo(b.name);
    });
    return stock;
  }

  Future<void> _buy(ShopItem item) async {
    setState(() => _buying = item.name);
    try {
      await _player.buyItem(item);
      if (!mounted) return;
      _toast('Bought ${item.name}! Find it in your backpack.');
    } on PurchaseException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('Purchase failed. Try again.');
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------------------------- ui

  Widget _buildRankBanner(int rank) {
    final color = RankService.colorOf(rank);
    final low = RankService.nameOf(max(0, rank - 1));
    final high = RankService.nameOf(
      min(RankService.names.length - 1, rank + 1),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(Icons.military_tech, color: color),
          const SizedBox(width: 8),
          Text(
            'RANK ${RankService.nameOf(rank).toUpperCase()}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Showing $low - $high gear. Stock refreshes daily.',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<ShopItem> stock) {
    final slots = stock.map((i) => Slots.key(i.type)).toSet().toList()
      ..sort((a, b) => Slots.rank(a).compareTo(Slots.rank(b)));
    final all = ['all', ...slots];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final slot = all[index];
          final selected = slot == _selectedSlot;
          final count = slot == 'all'
              ? stock.length
              : stock.where((i) => Slots.key(i.type) == slot).length;
          return ChoiceChip(
            avatar: slot == 'all'
                ? null
                : Icon(
                    Slots.icon(slot),
                    size: 18,
                    color: selected ? Colors.black : Colors.amber,
                  ),
            label: Text(
              '${slot == 'all' ? 'All' : Slots.label(slot)} ($count)',
            ),
            selected: selected,
            selectedColor: Colors.amber,
            labelStyle: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (_) => setState(() => _selectedSlot = slot),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String slotKey) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(Slots.icon(slotKey), color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Text(
            Slots.label(slotKey).toUpperCase(),
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: Colors.amber, thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildItemCard(ShopItem item) {
    final color = RankService.colorOfTier(item.tier);
    final tierIdx = RankService.tierIndex(item.tier);
    final tierName = tierIdx < 0 ? item.tier : RankService.names[tierIdx];
    final busy = _buying == item.name;
    final isAcc = Slots.isAccessory(item.type);

    final socketSummary = item.canHaveSkills
        ? '${item.maxSockets} stat · ${item.activeSkillSockets}A+${item.supportSkillSockets}S'
        : '${item.maxSockets} stat sockets';

    final gemSummary = isAcc
        ? 'Gems: Shared Accessory Pool (15 stats)'
        : 'Gems: ${item.effectiveAllowedStats.join(", ")}';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1230),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Slots.gearImage(item.type, item.tier),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  '${Slots.label(Slots.key(item.type))} - $tierName - $socketSummary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  gemSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.effectivePrice}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: busy ? null : () => _buy(item),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Buy'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<ShopItem> stock) {
    final visible = stock
        .where(
          (i) => _selectedSlot == 'all' || Slots.key(i.type) == _selectedSlot,
        )
        .toList();
    if (visible.isEmpty) {
      return const Center(child: Text('No items for your rank right now.'));
    }

    final slivers = <Widget>[];
    var i = 0;
    while (i < visible.length) {
      final slot = Slots.key(visible[i].type);
      final group = <ShopItem>[];
      while (i < visible.length && Slots.key(visible[i].type) == slot) {
        group.add(visible[i]);
        i++;
      }
      if (_selectedSlot == 'all') {
        slivers.add(SliverToBoxAdapter(child: _buildSectionHeader(slot)));
      }
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 460,
              mainAxisExtent: 96,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildItemCard(group[index]),
              childCount: group.length,
            ),
          ),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    return CustomScrollView(slivers: slivers);
  }

  // ---------------------------------------------------------------- gem tab

  Widget _gemFilterChip(String label, String value) {
    final selected = _gemFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: Colors.amber,
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _gemFilter = value),
    );
  }

  Widget _buildGemCard(ShopItem gem) {
    final color = RankService.colorOfTier(gem.tier);
    final busy = _buying == gem.name;
    final isSkill = gem.gemCategory != 'stat';

    final statSummary = isSkill
        ? (gem.statType ?? gem.name)
        : '${gem.statType ?? gem.name}: +${gem.value}${gem.isPercentage ? '%' : ''}';

    final slotsSummary =
        'Fits: ${gem.allowedSlots.map((s) => Slots.label(Slots.key(s))).join(", ")}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1230),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              gem.gemCategory == 'active_skill'
                  ? Icons.flash_on
                  : gem.gemCategory == 'support_skill'
                  ? Icons.auto_awesome
                  : Icons.diamond,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gem.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  statSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  slotsSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${gem.price}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: busy ? null : () => _buy(gem),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Buy'),
          ),
        ],
      ),
    );
  }

  Widget _buildGemTab() {
    final visibleGems = _gemFilter == 'all'
        ? gemData.gems
        : gemData.gems.where((g) => g.gemCategory == _gemFilter).toList();

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _gemFilterChip('All Gems (${gemData.gems.length})', 'all'),
              const SizedBox(width: 8),
              _gemFilterChip('Stat Gems', 'stat'),
              const SizedBox(width: 8),
              _gemFilterChip('Active Skills', 'active_skill'),
              const SizedBox(width: 8),
              _gemFilterChip('Support Skills', 'support_skill'),
            ],
          ),
        ),
        Expanded(
          child: visibleGems.isEmpty
              ? const Center(child: Text('No gems available right now.'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 460,
                    mainAxisExtent: 98,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: visibleGems.length,
                  itemBuilder: (context, index) =>
                      _buildGemCard(visibleGems[index]),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marketplace'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamBuilder<int>(
                stream: _player.currencyStream(),
                initialData: widget.currentCurrency,
                builder: (context, snapshot) => Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${snapshot.data ?? widget.currentCurrency}',
                      style: const TextStyle(fontSize: 18, color: Colors.amber),
                    ),
                  ],
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.shield), text: 'Gear'),
              Tab(icon: Icon(Icons.diamond), text: 'Gems'),
            ],
          ),
        ),
        body: !isDataLoaded
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  StreamBuilder<int>(
                    stream: _player.lifetimeStepsStream(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final rank = RankService.rankFor(snap.data!);
                      final stock = _stockFor(rank);
                      return Column(
                        children: [
                          _buildRankBanner(rank),
                          _buildFilterBar(stock),
                          Expanded(child: _buildList(stock)),
                        ],
                      );
                    },
                  ),
                  _buildGemTab(),
                ],
              ),
      ),
    );
  }
}
