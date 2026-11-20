import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/player_service.dart';
import '../services/rank_service.dart';

/// Step counter. Steps count toward your account rank (lifetime steps) and can
/// be converted into gold (marketplace currency).
///
/// The ring shows today's daily progress toward 10,000 steps (resets midnight).
/// A separate "Total Steps" panel shows the all-time accumulated count.
class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  static const int _dailyGoal = 10000;
  static const Color _gold = Color(0xFFFFCD5A);

  final PlayerService _player = PlayerService();

  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  Timer? _syncTimer;
  Timer? _midnightTimer;

  int? _baseline;        // sensor total at moment we started listening
  int _realSteps = 0;    // sensor steps this session
  int _simulatedSteps = 0; // debug-only
  int _pendingSteps = 0;   // unconverted steps from previous sessions
  int _convertedSteps = 0; // steps already spent on gold
  int _syncedSteps = 0;    // delta steps flushed to lifetime total this session
  String _status = 'unknown';
  String? _error;
  bool _starting = true;
  bool _converting = false;

  /// Steps walked today (loaded from Firestore, resets midnight).
  int _dailyPersistedSteps = 0;

  /// Total daily steps = persisted daily base + new steps this session.
  int get _todaySteps => _dailyPersistedSteps + _steps;

  int get _steps => _realSteps + _simulatedSteps;
  double get _km => _steps * PlayerService.kmPerStep;

  /// Total unconverted steps: session steps + persisted pending from previous sessions.
  int get _unconvertedSteps =>
      _steps + _pendingSteps - (_convertedSteps - _convertedStepsAtSessionStart);

  /// Steps walked this session that haven't been flushed to lifetimeSteps yet.
  int get _unsyncedSteps => _steps - _syncedSteps;
  int get _goldReady => _unconvertedSteps ~/ PlayerService.stepsPerGold;

  /// How many steps were already converted at the moment we opened the screen.
  int _convertedStepsAtSessionStart = 0;

  @override
  void initState() {
    super.initState();
    _loadPersistedState();

    // Sync to Firestore every 30 seconds
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _flushAll(),
    );

    // Schedule timer to reset the daily counter at midnight
    _scheduleMidnightReset();
  }

  /// Schedules a one-shot timer that fires at the next midnight to reset today's
  /// step counter on-screen (Firestore reset happens on next getDailySteps call).
  void _scheduleMidnightReset() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final till = midnight.difference(now);
    _midnightTimer?.cancel();
    _midnightTimer = Timer(till, () {
      if (!mounted) return;
      setState(() => _dailyPersistedSteps = 0);
      // Chain next timer for the following midnight
      _scheduleMidnightReset();
    });
  }

  /// Loads all persisted state from Firestore.
  Future<void> _loadPersistedState() async {
    final converted = await _player.getConvertedSteps();
    final pending = await _player.getPendingSteps();
    final daily = await _player.getDailySteps();
    if (!mounted) return;
    setState(() {
      _convertedSteps = converted;
      _convertedStepsAtSessionStart = converted;
      _pendingSteps = pending;
      _dailyPersistedSteps = daily;
    });
    _start();
  }

  /// Flushes both lifetime steps and daily steps to Firestore.
  Future<void> _flushAll() async {
    await _flushLifetime();
    await _player.saveDailySteps(_todaySteps);
  }

  /// Adds not-yet-saved steps to the account's lifetime total (rank progress).
  Future<void> _flushLifetime() async {
    final unsynced = _unsyncedSteps;
    if (unsynced <= 0) return;
    _syncedSteps += unsynced;
    try {
      await _player.addLifetimeSteps(unsynced);
    } catch (_) {
      _syncedSteps -= unsynced; // try again on the next flush
    }
  }

  Future<void> _start() async {
    // Android 10+ needs ACTIVITY_RECOGNITION; iOS needs Motion access
    final permission = Platform.isIOS
        ? Permission.sensors
        : Permission.activityRecognition;
    final result = await permission.request();

    if (!result.isGranted) {
      setState(() {
        _error = result.isPermanentlyDenied
            ? 'Step tracking permission was denied. Enable it in system settings.'
            : 'Step tracking permission is required.';
        _starting = false;
      });
      return;
    }

    _stepSub = Pedometer.stepCountStream.listen(
      (StepCount event) {
        // The sensor reports a running total; show steps since we began
        _baseline ??= event.steps;
        setState(() => _realSteps = event.steps - _baseline!);
      },
      onError: (_) => setState(() {
        _error = 'No step sensor available on this device.';
      }),
    );

    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (PedestrianStatus event) => setState(() => _status = event.status),
      onError: (_) {},
    );

    if (mounted) setState(() => _starting = false);
  }

  Future<void> _convert() async {
    final stepsToSpend = _goldReady * PlayerService.stepsPerGold;
    if (stepsToSpend <= 0 || _converting) return;

    setState(() => _converting = true);
    try {
      final leftoverPending = _unconvertedSteps - stepsToSpend;
      final earned = await _player.convertStepsToGold(
        stepsToSpend,
        remainingPending: leftoverPending < 0 ? 0 : leftoverPending,
      );
      setState(() => _convertedSteps += stepsToSpend);
      await _flushAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+$earned gold earned from $stepsToSpend steps!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not convert steps. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _midnightTimer?.cancel();
    _stepSub?.cancel();
    _statusSub?.cancel();
    // Flush any unsaved steps before the widget is torn down.
    final flush = _flushAll();
    flush.ignore();
    final savePending = _player.savePendingSteps(_unconvertedSteps);
    savePending.ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ring clamps at 1.0 (fully filled) even if today > 10000
    final dailyProgress = (_todaySteps / _dailyGoal).clamp(0.0, 1.0);
    // If daily goal is exceeded, ring stays full; we show the overflow in text
    final goalExceeded = _todaySteps > _dailyGoal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Steps'),
        actions: [
          // Live gold balance
          StreamBuilder<int>(
            stream: _player.currencyStream(),
            initialData: 0,
            builder: (context, snapshot) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${snapshot.data ?? 0}',
                    style: const TextStyle(fontSize: 18, color: Colors.amber),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Main row: ring + stats ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress ring + rank card
                      SizedBox(
                        width: 210,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 170,
                              height: 170,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: dailyProgress,
                                      strokeWidth: 12,
                                      // Turn ring gold-bright when goal surpassed
                                      color: goalExceeded
                                          ? const Color(0xFFFFE082)
                                          : _gold,
                                      backgroundColor: Colors.white12,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$_todaySteps',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: goalExceeded
                                              ? const Color(0xFFFFE082)
                                              : _gold,
                                        ),
                                      ),
                                      Text(
                                        'of $_dailyGoal steps',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      if (goalExceeded)
                                        Text(
                                          '+${_todaySteps - _dailyGoal} extra!',
                                          style: const TextStyle(
                                            color: Color(0xFFFFE082),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Daily goal label
                            Text(
                              goalExceeded
                                  ? '🎉 Daily goal reached!'
                                  : 'Daily goal: $_dailyGoal steps',
                              style: TextStyle(
                                color: goalExceeded
                                    ? const Color(0xFFFFE082)
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildRankCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 28),
                      // Stats + conversion
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _stat(
                              Icons.straighten,
                              'Distance',
                              '${_km.toStringAsFixed(2)} km',
                            ),
                            const SizedBox(height: 10),
                            _stat(Icons.directions_walk, 'Status', _status),
                            const SizedBox(height: 10),
                            _stat(
                              Icons.swap_horiz,
                              'Rate',
                              '${PlayerService.stepsPerGold} steps = 1 gold',
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (_goldReady > 0 && !_converting)
                                    ? _convert
                                    : null,
                                icon: _converting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.monetization_on),
                                label: Text(
                                  _goldReady > 0
                                      ? 'Convert to $_goldReady gold'
                                      : 'Walk more to earn gold',
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Converting never lowers your rank: rank counts every step you walk.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style:
                                    const TextStyle(color: Colors.redAccent),
                              ),
                              if (_error!.contains('settings'))
                                TextButton(
                                  onPressed: openAppSettings,
                                  child: const Text('Open settings'),
                                ),
                            ],
                            if (kDebugMode) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _simulatedSteps += 100);
                                  _flushAll();
                                  _player
                                      .savePendingSteps(_unconvertedSteps)
                                      .ignore();
                                },
                                icon: const Icon(Icons.bug_report),
                                label: const Text('+100 steps (debug only)'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Total Steps Panel ───────────────────────────────────
                  _buildTotalStepsCard(),
                ],
              ),
            ),
    );
  }

  /// Card showing all-time lifetime steps accumulated across all days.
  Widget _buildTotalStepsCard() {
    return StreamBuilder<int>(
      stream: _player.totalStepsStream(),
      initialData: 0,
      builder: (context, snapshot) {
        final savedTotal = snapshot.data ?? 0;
        // Include unsynced session steps in the display
        final total = savedTotal + _unsyncedSteps;
        final totalKm = total * PlayerService.kmPerStep;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFCD5A).withValues(alpha: 0.15),
                const Color(0xFFFFCD5A).withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFFCD5A).withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timeline, color: _gold, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'ALL-TIME TOTAL STEPS',
                    style: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.3,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Never resets',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatNumber(total),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: _gold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'steps',
                      style: TextStyle(color: Colors.white60, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${totalKm.toStringAsFixed(2)} km walked in total  ·  '
                '${(total / _dailyGoal).toStringAsFixed(1)}× the daily goal',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Rank name + progress bar toward the next rank.
  Widget _buildRankCard() {
    return StreamBuilder<int>(
      stream: _player.lifetimeStepsStream(),
      initialData: 0,
      builder: (context, snapshot) {
        final savedLifetime = snapshot.data ?? 0;
        final lifetime = savedLifetime + _unsyncedSteps;
        final rank = RankService.rankFor(lifetime);
        final color = RankService.colorOf(rank);
        final next = RankService.nextThreshold(rank);

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.military_tech, color: color, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    RankService.nameOf(rank).toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: RankService.progress(lifetime),
                minHeight: 8,
                color: color,
                backgroundColor: Colors.white12,
              ),
              const SizedBox(height: 6),
              Text(
                next == null
                    ? '$lifetime lifetime steps (max rank)'
                    : '$lifetime / $next steps to ${RankService.nameOf(rank + 1)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: _gold),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60)),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  /// Formats large numbers with commas for readability (e.g. 12,345).
  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
