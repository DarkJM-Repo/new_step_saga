import 'package:flutter/material.dart';

/// Account rank, based on total steps walked over the account's lifetime.
/// Rank index 0..5 lines up with the item tiers in the shop.
class RankService {
  static const List<String> tiers = [
    'newbie',
    'advance',
    'masterful',
    'elite',
    'legendary',
    'mythical',
  ];

  static const List<String> names = [
    'Newbie',
    'Advance',
    'Masterful',
    'Elite',
    'Legendary',
    'Mythical',
  ];

  /// Lifetime steps needed to reach each rank. Tweak these to rebalance.
  /// (At ~10,000 steps a day: Advance in 5 days, Masterful in ~3 weeks,
  /// Elite in ~2 months, Legendary in ~5 months, Mythical in ~13 months.)
  static const List<int> thresholds = [
    0,
    50000,
    200000,
    600000,
    1500000,
    4000000,
  ];

  /// One hue per rank. The armor pictures are drawn in the same colors.
  static const List<Color> colors = [
    Color(0xFF9E9E9E), // newbie: grey
    Color(0xFF4CAF50), // advance: green
    Color(0xFF42A5F5), // masterful: blue
    Color(0xFFAB47BC), // elite: purple
    Color(0xFFFFA726), // legendary: orange
    Color(0xFFEF5350), // mythical: red
  ];

  static int rankFor(int lifetimeSteps) {
    var rank = 0;
    for (var i = 0; i < thresholds.length; i++) {
      if (lifetimeSteps >= thresholds[i]) rank = i;
    }
    return rank;
  }

  static String nameOf(int rank) => names[rank.clamp(0, names.length - 1)];

  static Color colorOf(int rank) => colors[rank.clamp(0, colors.length - 1)];

  /// -1 when the tier text isn't one of the six known tiers.
  static int tierIndex(String tier) => tiers.indexOf(tier.toLowerCase().trim());

  static Color colorOfTier(String tier) {
    final i = tierIndex(tier);
    return i < 0 ? Colors.white : colors[i];
  }

  /// Shop validation: a player only sees items from 1 tier below their rank
  /// up to 1 tier above it.
  static bool canAccess(int rank, String itemTier) {
    final t = tierIndex(itemTier);
    return t != -1 && (t - rank).abs() <= 1;
  }

  /// Steps needed for the next rank, or null at max rank.
  static int? nextThreshold(int rank) =>
      rank >= thresholds.length - 1 ? null : thresholds[rank + 1];

  /// 0.0 - 1.0 progress from the current rank toward the next one.
  static double progress(int lifetimeSteps) {
    final rank = rankFor(lifetimeSteps);
    final next = nextThreshold(rank);
    if (next == null) return 1.0;
    final start = thresholds[rank];
    return ((lifetimeSteps - start) / (next - start)).clamp(0.0, 1.0);
  }
}
