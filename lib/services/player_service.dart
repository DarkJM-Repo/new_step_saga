import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shop_model.dart';
import '../models/slots.dart';
import 'rank_service.dart';

/// An item the player owns (players/[uid]/inventory/[id]).
class InventoryItem {
  final String id;
  final ShopItem item;
  final List<String> socketedStatGemIds;
  final String? socketedActiveGemId;
  final List<String> socketedSupportGemIds;
  final String? socketedInItemId;

  const InventoryItem({
    required this.id,
    required this.item,
    this.socketedStatGemIds = const [],
    this.socketedActiveGemId,
    this.socketedSupportGemIds = const [],
    this.socketedInItemId,
  });
}

/// A single row in a partitioned leaderboard document.
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final double score;
  final String characterClass;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.score,
    this.characterClass = '',
  });

  factory LeaderboardEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return LeaderboardEntry(
      uid: (data['uid'] ?? doc.id).toString(),
      displayName: (data['displayName'] ?? 'Hero').toString(),
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      characterClass: (data['characterClassId'] ?? '').toString(),
    );
  }
}

/// Thrown when a purchase is refused (not enough gold, wrong rank...).
class PurchaseException implements Exception {
  final String message;
  const PurchaseException(this.message);
  @override
  String toString() => message;
}

/// Reads and updates the signed-in player's data in Cloud Firestore.
class PlayerService {
  static const int stepsPerGold = 10;
  static const double kmPerStep = 0.000762;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _playerDoc {
    final uid = _uid;
    return uid == null ? null : _db.collection('players').doc(uid);
  }

  static String normalizeSlot(String raw) => Slots.fileName(raw);

  static int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstJan = DateTime.utc(thursday.year, 1, 1);
    return ((thursday.difference(firstJan).inDays) ~/ 7) + 1;
  }

  static String _boardDocId(String metric, String timeframe, DateTime now) {
    switch (timeframe) {
      case 'yearly':
        return '${metric}_yearly_${now.year}';
      case 'monthly':
        return '${metric}_monthly_${now.year}_${now.month.toString().padLeft(2, '0')}';
      case 'weekly':
        final week = _isoWeekNumber(now).toString().padLeft(2, '0');
        return '${metric}_weekly_${now.year}_w$week';
      default:
        return '${metric}_allTime';
    }
  }

  // ---------------------------------------------------------------- streams

  Stream<int> currencyStream() {
    final doc = _playerDoc;
    if (doc == null) return Stream<int>.value(0);
    return doc.snapshots().map(
          (snap) => (snap.data()?['currency'] as num?)?.toInt() ?? 0,
        );
  }

  Stream<int> lifetimeStepsStream() {
    final doc = _playerDoc;
    if (doc == null) return Stream<int>.value(0);
    return doc.snapshots().map(
          (snap) => (snap.data()?['lifetimeSteps'] as num?)?.toInt() ?? 0,
        );
  }

  /// Stream of the all-time total steps (same as lifetimeSteps, exposed
  /// under a clearer name for the Total Steps UI panel).
  Stream<int> totalStepsStream() => lifetimeStepsStream();

  Stream<String> classStream() {
    final doc = _playerDoc;
    if (doc == null) return Stream<String>.value('vanguard');
    return doc.snapshots().map(
          (snap) =>
              (snap.data()?['characterClassId'] ?? 'vanguard').toString(),
        );
  }

  Stream<List<InventoryItem>> inventoryStream() {
    final doc = _playerDoc;
    if (doc == null) return Stream<List<InventoryItem>>.value(const []);
    return doc.collection('inventory').snapshots().map(
          (snap) => snap.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data());
            if (data['type'] != null) {
              data['type'] = normalizeSlot(data['type'].toString());
            }
            return InventoryItem(
              id: d.id,
              item: ShopItem.fromJson(data),
              socketedStatGemIds: data['socketedStatGemIds'] is List
                  ? List<String>.from(
                      (data['socketedStatGemIds'] as List)
                          .map((e) => e.toString()),
                    )
                  : const [],
              socketedActiveGemId: data['socketedActiveGemId']?.toString(),
              socketedSupportGemIds: data['socketedSupportGemIds'] is List
                  ? List<String>.from(
                      (data['socketedSupportGemIds'] as List)
                          .map((e) => e.toString()),
                    )
                  : const [],
              socketedInItemId: data['socketedInItemId']?.toString(),
            );
          }).toList(),
        );
  }

  Stream<Map<String, InventoryItem>> equippedStream() {
    final doc = _playerDoc;
    if (doc == null) {
      return Stream<Map<String, InventoryItem>>.value(const {});
    }
    return doc.snapshots().map((snap) {
      final raw = snap.data()?['equipped'];
      final out = <String, InventoryItem>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is Map) {
            final key = normalizeSlot(k.toString());
            final m = Map<String, dynamic>.from(v);
            m['type'] = key;
            out[key] = InventoryItem(
              id: m['invId']?.toString() ?? '',
              item: ShopItem.fromJson(m),
              socketedStatGemIds: m['socketedStatGemIds'] is List
                  ? List<String>.from(
                      (m['socketedStatGemIds'] as List)
                          .map((e) => e.toString()),
                    )
                  : const [],
              socketedActiveGemId: m['socketedActiveGemId']?.toString(),
              socketedSupportGemIds: m['socketedSupportGemIds'] is List
                  ? List<String>.from(
                      (m['socketedSupportGemIds'] as List)
                          .map((e) => e.toString()),
                    )
                  : const [],
            );
          }
        });
      }
      return out;
    });
  }

  Stream<List<LeaderboardEntry>> leaderboardStream({
    required String metric,
    required String timeframe,
  }) {
    final now = DateTime.now().toUtc();
    final boardDocId = _boardDocId(metric, timeframe, now);
    return _db
        .collection('leaderboards')
        .doc(boardDocId)
        .collection('entries')
        .orderBy('score', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => LeaderboardEntry.fromDoc(doc)).toList(),
        );
  }

  // ------------------------------------------------------------------ class

  Future<void> setCharacterClass(String classId) async {
    final doc = _playerDoc;
    if (doc == null) throw StateError('Not signed in');
    await doc.set({'characterClassId': classId}, SetOptions(merge: true));
  }

  // ------------------------------------------------------------------ steps

  /// Returns how many steps have already been converted to gold (persisted).
  /// Used to restore [_convertedSteps] after navigating away and back.
  Future<int> getConvertedSteps() async {
    final doc = _playerDoc;
    if (doc == null) return 0;
    final snap = await doc.get();
    return (snap.data()?['convertedSteps'] as num?)?.toInt() ?? 0;
  }

  /// Returns steps that have been walked but not yet converted to gold.
  /// Persisted so they survive navigation away and back.
  Future<int> getPendingSteps() async {
    final doc = _playerDoc;
    if (doc == null) return 0;
    final snap = await doc.get();
    return (snap.data()?['pendingSteps'] as num?)?.toInt() ?? 0;
  }

  /// Saves the current unconverted step count so it can be restored later.
  Future<void> savePendingSteps(int steps) async {
    final doc = _playerDoc;
    if (doc == null) return;
    await doc.set({'pendingSteps': steps}, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------- daily steps

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns the steps walked today (resets each calendar day).
  /// Also resets the counter in Firestore if a new day has begun.
  Future<int> getDailySteps() async {
    final doc = _playerDoc;
    if (doc == null) return 0;
    final snap = await doc.get();
    final data = snap.data() ?? {};
    final savedDay = (data['dailyStepsDate'] as String?) ?? '';
    final today = _todayKey();
    if (savedDay != today) {
      // New day — reset
      await doc.set({
        'dailySteps': 0,
        'dailyStepsDate': today,
      }, SetOptions(merge: true));
      return 0;
    }
    return (data['dailySteps'] as num?)?.toInt() ?? 0;
  }

  /// Persists the today's step count.
  Future<void> saveDailySteps(int steps) async {
    final doc = _playerDoc;
    if (doc == null) return;
    await doc.set({
      'dailySteps': steps,
      'dailyStepsDate': _todayKey(),
    }, SetOptions(merge: true));
  }

  Future<int> convertStepsToGold(int steps, {required int remainingPending}) async {
    final doc = _playerDoc;
    if (doc == null) throw StateError('Not signed in');

    final gold = steps ~/ stepsPerGold;
    if (gold <= 0) return 0;

    // Persist the currency gain, the running converted-steps total, and the
    // updated pending steps (leftover after conversion).
    await doc.set({
      'currency': FieldValue.increment(gold),
      'convertedSteps': FieldValue.increment(steps),
      'pendingSteps': remainingPending,
    }, SetOptions(merge: true));
    return gold;
  }

  Future<void> addLifetimeSteps(int steps) async {
    final uid = _uid;
    final doc = _playerDoc;
    if (uid == null || doc == null || steps <= 0) return;

    final addedKm = steps * kmPerStep;
    final now = DateTime.now().toUtc();
    final user = FirebaseAuth.instance.currentUser;
    final fallbackName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'Hero');

    // --- Critical write: player lifetime total (must succeed) ---
    await doc.set(
      {
        'displayName': fallbackName,
        'lifetimeSteps': FieldValue.increment(steps),
        'totalMileageKm': FieldValue.increment(addedKm),
      },
      SetOptions(merge: true),
    );

    // --- Best-effort write: leaderboard entries (failure is non-fatal) ---
    try {
      final batch = _db.batch();
      for (final tf in const ['allTime', 'yearly', 'monthly', 'weekly']) {
        final boardId = _boardDocId('mileage', tf, now);
        final entryRef = _db
            .collection('leaderboards')
            .doc(boardId)
            .collection('entries')
            .doc(uid);
        batch.set(
          entryRef,
          {
            'uid': uid,
            'displayName': fallbackName,
            'score': FieldValue.increment(addedKm),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (_) {
      // Leaderboard write failure is non-fatal; lifetime steps are already saved.
    }
  }

  Future<void> recordPvpResult({required bool won, int kills = 0}) async {
    final uid = _uid;
    final doc = _playerDoc;
    if (uid == null || doc == null) return;

    final now = DateTime.now().toUtc();
    final user = FirebaseAuth.instance.currentUser;
    final fallbackName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'Hero');

    final batch = _db.batch();
    batch.set(
      doc,
      {
        if (won) 'pvpWins': FieldValue.increment(1),
        if (kills > 0) 'pvpKills': FieldValue.increment(kills),
      },
      SetOptions(merge: true),
    );

    for (final tf in const ['allTime', 'yearly', 'monthly', 'weekly']) {
      if (won) {
        final winBoard = _boardDocId('pvpWins', tf, now);
        batch.set(
          _db
              .collection('leaderboards')
              .doc(winBoard)
              .collection('entries')
              .doc(uid),
          {
            'uid': uid,
            'displayName': fallbackName,
            'score': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      if (kills > 0) {
        final killBoard = _boardDocId('pvpKills', tf, now);
        batch.set(
          _db
              .collection('leaderboards')
              .doc(killBoard)
              .collection('entries')
              .doc(uid),
          {
            'uid': uid,
            'displayName': fallbackName,
            'score': FieldValue.increment(kills),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
  }

  // ------------------------------------------------------------------- shop

  Future<void> buyItem(ShopItem item) async {
    final doc = _playerDoc;
    if (doc == null) throw const PurchaseException('Please sign in again.');
    final cost = item.effectivePrice;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final data = snap.data() ?? <String, dynamic>{};
      final gold = (data['currency'] as num?)?.toInt() ?? 0;
      final steps = (data['lifetimeSteps'] as num?)?.toInt() ?? 0;
      final rank = RankService.rankFor(steps);

      if (!RankService.canAccess(rank, item.tier)) {
        throw const PurchaseException('This item is outside your rank range.');
      }
      if (gold < cost) {
        throw PurchaseException('Not enough gold (need $cost, have $gold).');
      }

      final normalizedType =
          item.isGem ? item.type : normalizeSlot(item.type);

      tx.set(doc, {'currency': gold - cost}, SetOptions(merge: true));
      tx.set(doc.collection('inventory').doc(), {
        ...item.toJson(),
        'type': normalizedType,
        'price': cost,
        'acquiredAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // -------------------------------------------------------------- equipment

  Future<void> equip(String slotKey, InventoryItem inv) async {
    final doc = _playerDoc;
    if (doc == null) throw StateError('Not signed in');
    final key = normalizeSlot(slotKey);
    await doc.set({
      'equipped': {
        key: {
          ...inv.item.toJson(),
          'type': key,
          'invId': inv.id,
          'socketedStatGemIds': inv.socketedStatGemIds,
          'socketedActiveGemId': inv.socketedActiveGemId,
          'socketedSupportGemIds': inv.socketedSupportGemIds,
        },
      },
    }, SetOptions(merge: true));
  }

  Future<void> unequip(String slotKey) async {
    final doc = _playerDoc;
    if (doc == null) throw StateError('Not signed in');
    final key = normalizeSlot(slotKey);
    await doc.update({'equipped.$key': FieldValue.delete()});
  }

  Future<void> saveItemSockets({
    required String gearInvId,
    required List<String> statGemIds,
    required String? activeGemId,
    required List<String> supportGemIds,
    required List<String> newlyAttachedGemIds,
    required List<String> detachedGemIds,
  }) async {
    final doc = _playerDoc;
    if (doc == null) throw StateError('Not signed in');

    final batch = _db.batch();
    final gearRef = doc.collection('inventory').doc(gearInvId);
    batch.set(
      gearRef,
      {
        'socketedStatGemIds': statGemIds,
        'socketedActiveGemId': activeGemId,
        'socketedSupportGemIds': supportGemIds,
      },
      SetOptions(merge: true),
    );

    for (final gid in newlyAttachedGemIds) {
      batch.set(
        doc.collection('inventory').doc(gid),
        {'socketedInItemId': gearInvId},
        SetOptions(merge: true),
      );
    }

    for (final gid in detachedGemIds) {
      batch.set(
        doc.collection('inventory').doc(gid),
        {'socketedInItemId': FieldValue.delete()},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}