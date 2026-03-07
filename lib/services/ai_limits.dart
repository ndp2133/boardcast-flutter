/// Client-side AI rate limiting using Hive.
/// Tracks daily usage counts for AI features and enforces abuse-prevention
/// limits. Limits are intentionally high (feels unlimited for normal use).
import 'package:hive_flutter/hive_flutter.dart';

const _boxName = 'ai_usage';

// Daily limits — high enough to feel unlimited, low enough to prevent abuse
const _tipLimit = 25;
const _queryLimit = 25;
const _summaryLimit = 50;

// Hive keys
const _keyDate = 'date';
const _keyTips = 'tips';
const _keyQueries = 'queries';
const _keySummaries = 'summaries';

class AiLimitsService {
  late Box<dynamic> _box;

  /// Initialize — call once at app startup (after Hive.initFlutter).
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _resetIfNewDay();
  }

  // -- Tips ------------------------------------------------------------------

  bool canUseTip() {
    _resetIfNewDay();
    return (_box.get(_keyTips, defaultValue: 0) as int) < _tipLimit;
  }

  int get remainingTips {
    _resetIfNewDay();
    final used = _box.get(_keyTips, defaultValue: 0) as int;
    return (_tipLimit - used).clamp(0, _tipLimit);
  }

  void recordTipUsage() {
    _resetIfNewDay();
    final current = _box.get(_keyTips, defaultValue: 0) as int;
    _box.put(_keyTips, current + 1);
  }

  // -- Queries ---------------------------------------------------------------

  bool canUseQuery() {
    _resetIfNewDay();
    return (_box.get(_keyQueries, defaultValue: 0) as int) < _queryLimit;
  }

  int get remainingQueries {
    _resetIfNewDay();
    final used = _box.get(_keyQueries, defaultValue: 0) as int;
    return (_queryLimit - used).clamp(0, _queryLimit);
  }

  void recordQueryUsage() {
    _resetIfNewDay();
    final current = _box.get(_keyQueries, defaultValue: 0) as int;
    _box.put(_keyQueries, current + 1);
  }

  // -- Summaries -------------------------------------------------------------

  bool canUseSummary() {
    _resetIfNewDay();
    return (_box.get(_keySummaries, defaultValue: 0) as int) < _summaryLimit;
  }

  void recordSummaryUsage() {
    _resetIfNewDay();
    final current = _box.get(_keySummaries, defaultValue: 0) as int;
    _box.put(_keySummaries, current + 1);
  }

  // -- Internal --------------------------------------------------------------

  /// Reset all counters if the stored date differs from today.
  void _resetIfNewDay() {
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final stored = _box.get(_keyDate) as String?;
    if (stored != today) {
      _box.put(_keyDate, today);
      _box.put(_keyTips, 0);
      _box.put(_keyQueries, 0);
      _box.put(_keySummaries, 0);
    }
  }
}
