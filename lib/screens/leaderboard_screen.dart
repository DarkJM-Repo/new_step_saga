import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/player_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const Color _gold = Color(0xFFFFCD5A);

  final PlayerService _player = PlayerService();
  String _metric = 'mileage'; // 'mileage' | 'pvpKills' | 'pvpWins'
  String _timeframe =
      'all_time'; // 'all_time' | 'yearly' | 'monthly' | 'weekly'

  static const Map<String, String> _metricLabels = {
    'mileage': 'Mileage',
    'pvpKills': 'PvP Kills',
    'pvpWins': 'PvP Wins',
  };

  static const Map<String, String> _timeframeLabels = {
    'all_time': 'All-Time',
    'yearly': 'Yearly',
    'monthly': 'Monthly',
    'weekly': 'Weekly',
  };

  String _formatScore(double score) {
    if (_metric == 'mileage') {
      return '${score.toStringAsFixed(2)} km';
    }
    return '${score.round()}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/bg_dashboard.png', fit: BoxFit.cover),
        Container(color: Colors.black.withValues(alpha: 0.45)),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'LEADERBOARDS',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                // Metric Selector (Mileage | PvP Kills | PvP Wins)
                Row(
                  children: _metricLabels.entries.map((entry) {
                    final active = _metric == entry.key;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _metric = entry.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: active
                                  ? _gold.withValues(alpha: 0.22)
                                  : const Color(0xE61B1230),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: active ? _gold : Colors.white24,
                                width: active ? 1.6 : 1,
                              ),
                            ),
                            child: Text(
                              entry.value.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: active ? _gold : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // Timeframe Selector (All-Time | Yearly | Monthly | Weekly)
                Row(
                  children: _timeframeLabels.entries.map((entry) {
                    final active = _timeframe == entry.key;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _timeframe = entry.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: active ? Colors.white12 : Colors.black38,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: active
                                    ? _gold.withValues(alpha: 0.8)
                                    : Colors.white12,
                              ),
                            ),
                            child: Text(
                              entry.value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: active ? Colors.white : Colors.white54,
                                fontSize: 11,
                                fontWeight: active
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                // Live Ranked List
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xEB140D26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _gold.withValues(alpha: 0.5)),
                    ),
                    child: StreamBuilder<List<LeaderboardEntry>>(
                      stream: _player.leaderboardStream(
                        metric: _metric,
                        timeframe: _timeframe,
                      ),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: _gold),
                          );
                        }
                        final entries = snap.data ?? const <LeaderboardEntry>[];
                        if (entries.isEmpty) {
                          return Center(
                            child: Text(
                              'No ${_timeframeLabels[_timeframe]} ${_metricLabels[_metric]} records yet.\nWalk & convert steps to claim #1!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }

                        final myIndex = entries.indexWhere(
                          (e) => e.uid == currentUid,
                        );

                        return Column(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(10),
                                itemCount: entries.length,
                                separatorBuilder: (_, _) => const Divider(
                                  color: Colors.white12,
                                  height: 8,
                                ),
                                itemBuilder: (context, index) {
                                  final item = entries[index];
                                  final rank = index + 1;
                                  final isMe = item.uid == currentUid;
                                  final rankColor = rank == 1
                                      ? const Color(0xFFFFD700)
                                      : rank == 2
                                      ? const Color(0xFFC0C0C0)
                                      : rank == 3
                                      ? const Color(0xFFCD7F32)
                                      : Colors.white70;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? _gold.withValues(alpha: 0.14)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 36,
                                          child: Text(
                                            '#$rank',
                                            style: TextStyle(
                                              color: rankColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isMe
                                                    ? '${item.displayName} (YOU)'
                                                    : item.displayName,
                                                style: TextStyle(
                                                  color: isMe
                                                      ? _gold
                                                      : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                item.characterClass
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _formatScore(item.score),
                                          style: const TextStyle(
                                            color: _gold,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                border: Border(
                                  top: BorderSide(
                                    color: _gold.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    myIndex >= 0
                                        ? 'Your Rank: #${myIndex + 1}'
                                        : 'Your Rank: Unranked',
                                    style: const TextStyle(
                                      color: _gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    myIndex >= 0
                                        ? _formatScore(entries[myIndex].score)
                                        : '0',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
