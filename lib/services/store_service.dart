/// Write-through persistence — Hive first, then Supabase async
/// Direct port of js/store.js
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import '../models/models.dart';

const _boxName = 'boardcast_store';

/// localStorage key equivalents
const _keyPrefs = 'prefs';
const _keySessions = 'sessions';
const _keyOnboarded = 'onboarded';
const _keyLocation = 'location';
const _keyTheme = 'theme';
const _keyBoards = 'boards';

const defaultLocationId = 'rockaway';

/// Skill-based preference defaults
const skillDefaults = <String, UserPrefs>{
  'beginner': UserPrefs(
    minWaveHeight: 0.3,
    maxWaveHeight: 1.0,
    maxWindSpeed: 20,
    preferredWindDir: 'offshore',
    preferredTide: 'mid',
    skillLevel: 'beginner',
  ),
  'intermediate': UserPrefs(
    minWaveHeight: 0.6,
    maxWaveHeight: 2.0,
    maxWindSpeed: 35,
    preferredWindDir: 'any',
    preferredTide: 'any',
    skillLevel: 'intermediate',
  ),
  'advanced': UserPrefs(
    minWaveHeight: 1.0,
    maxWaveHeight: 5.0,
    maxWindSpeed: 60,
    preferredWindDir: 'any',
    preferredTide: 'any',
    skillLevel: 'advanced',
  ),
};

class StoreService {
  late Box<String> _box;
  SupabaseClient? _supabase;
  String? Function()? _getUserId;
  bool Function()? _isGuest;

  // Sync mutexes
  bool _syncingSessions = false;
  bool _syncingUserData = false;

  /// Initialize Hive box. Call once at startup.
  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  /// Wire up auth + supabase for write-through sync.
  void configure({
    required SupabaseClient supabase,
    required String? Function() getUserId,
    required bool Function() isGuest,
  }) {
    _supabase = supabase;
    _getUserId = getUserId;
    _isGuest = isGuest;
  }

  bool get _guest => _isGuest?.call() ?? true;
  String? get _userId => _getUserId?.call();

  // ---------------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------------

  UserPrefs getPrefs() {
    final raw = _box.get(_keyPrefs);
    if (raw == null) return skillDefaults['intermediate']!;
    try {
      return UserPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return skillDefaults['intermediate']!;
    }
  }

  Future<void> savePrefs(UserPrefs prefs) async {
    await _box.put(_keyPrefs, jsonEncode(prefs.toJson()));
    _pushUserData('prefs', prefs.toJson());
  }

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------

  bool get isOnboarded => _box.get(_keyOnboarded) == 'true';

  Future<void> setOnboarded() async {
    await _box.put(_keyOnboarded, 'true');
    _pushUserData('settings', _getSettingsObject());
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  List<Session> getSessions() {
    final raw = _box.get(_keySessions);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Session.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveSessions(List<Session> sessions) async {
    await _box.put(
        _keySessions, jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }

  Future<List<Session>> addSession(Session session) async {
    final sessions = getSessions()..add(session);
    await _saveSessions(sessions);

    if (!_guest) {
      final row = _sessionToRow(session);
      _supabase?.from('sessions').insert(row).then((_) {}, onError: (_) {});
    }
    return sessions;
  }

  Future<List<Session>> updateSession(String id, Session updated) async {
    final sessions = getSessions();
    final idx = sessions.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      sessions[idx] = updated;
      await _saveSessions(sessions);

      if (!_guest) {
        final row = _sessionToRow(updated);
        _supabase?.from('sessions').upsert(row).then((_) {}, onError: (_) {});
      }
    }
    return sessions;
  }

  Future<List<Session>> deleteSession(String id) async {
    final sessions = getSessions().where((s) => s.id != id).toList();
    await _saveSessions(sessions);

    if (!_guest) {
      _supabase
          ?.from('sessions')
          .delete()
          .eq('id', id)
          .then((_) {}, onError: (_) {});
    }
    return sessions;
  }

  Map<String, dynamic> _sessionToRow(Session session) {
    final conditions = <String, dynamic>{};
    if (session.conditions != null) {
      conditions.addAll(session.conditions!.toJson());
    }
    if (session.calibration != null) {
      conditions['calibration'] = session.calibration;
    }

    return {
      'id': session.id,
      'planned_date': session.date,
      'planned_hours': session.selectedHours ?? [],
      'conditions': conditions.isNotEmpty ? conditions : null,
      'status': session.status,
      'rating': session.rating,
      'notes': session.notes ?? '',
      'completed_at': session.status == 'completed'
          ? session.updatedAt.toIso8601String()
          : null,
      'created_at': session.createdAt.toIso8601String(),
      'location_id': session.locationId,
      'user_id': _userId,
    };
  }

  /// Sync sessions from Supabase (merge, Supabase wins on conflict).
  Future<void> syncSessions() async {
    if (_guest || _syncingSessions) return;
    final userId = _userId;
    if (userId == null) return;

    _syncingSessions = true;
    try {
      final res = await _supabase!
          .from('sessions')
          .select()
          .eq('user_id', userId);
      final data = res as List;

      final local = getSessions();
      final merged = <String, Session>{};

      // Local first
      for (final s in local) {
        merged[s.id] = s;
      }

      // Supabase wins on conflict
      for (final row in data) {
        final r = row as Map<String, dynamic>;
        final cond = r['conditions'] as Map<String, dynamic>?;
        merged[r['id'] as String] = Session(
          id: r['id'] as String,
          userId: r['user_id'] as String?,
          locationId: r['location_id'] as String? ?? defaultLocationId,
          date: r['planned_date'] as String,
          status: r['status'] as String? ?? 'planned',
          selectedHours: (r['planned_hours'] as List?)?.cast<int>(),
          rating: r['rating'] as int?,
          calibration: cond?['calibration'] as int?,
          notes: r['notes'] as String?,
          conditions: cond != null
              ? SessionConditions.fromJson(cond)
              : null,
          createdAt: DateTime.parse(
              r['created_at'] as String? ?? DateTime.now().toIso8601String()),
          updatedAt: DateTime.parse(
              r['completed_at'] as String? ??
                  r['created_at'] as String? ??
                  DateTime.now().toIso8601String()),
        );
      }

      final mergedList = merged.values.toList();
      await _saveSessions(mergedList);

      // Push local-only sessions to Supabase
      final remoteIds = data.map((r) => (r as Map)['id'] as String).toSet();
      final localOnly = local.where((s) => !remoteIds.contains(s.id)).toList();
      if (localOnly.isNotEmpty) {
        final rows = localOnly.map(_sessionToRow).toList();
        await _supabase!.from('sessions').upsert(rows);
      }
    } catch (_) {
      // Silent fail — data is safe in Hive
    } finally {
      _syncingSessions = false;
    }
  }

  /// Migrate all local sessions to Supabase on first sign-in.
  Future<void> migrateGuestSessions() async {
    if (_guest) return;
    final sessions = getSessions();
    if (sessions.isEmpty) return;

    final rows = sessions.map(_sessionToRow).toList();
    try {
      await _supabase!.from('sessions').upsert(rows);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  String getSelectedLocationId() {
    return _box.get(_keyLocation) ?? defaultLocationId;
  }

  Future<void> setSelectedLocationId(String id) async {
    await _box.put(_keyLocation, id);
    _pushUserData('settings', _getSettingsObject());
  }

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------

  String? getThemePref() => _box.get(_keyTheme);

  Future<void> setThemePref(String? theme) async {
    if (theme == null) {
      await _box.delete(_keyTheme);
    } else {
      await _box.put(_keyTheme, theme);
    }
    _pushUserData('settings', _getSettingsObject());
  }

  // ---------------------------------------------------------------------------
  // Boards (Quiver)
  // ---------------------------------------------------------------------------

  List<Board> getBoards() {
    final raw = _box.get(_keyBoards);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Board.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveBoards(List<Board> boards) async {
    await _box.put(
        _keyBoards, jsonEncode(boards.map((b) => b.toJson()).toList()));
    _pushUserData('boards', boards.map((b) => b.toJson()).toList());
  }

  Future<List<Board>> addBoard(Board board) async {
    final boards = getBoards()..add(board);
    await _saveBoards(boards);
    return boards;
  }

  Future<List<Board>> updateBoard(String id, Board updated) async {
    final boards = getBoards();
    final idx = boards.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      boards[idx] = updated;
      await _saveBoards(boards);
    }
    return boards;
  }

  Future<List<Board>> deleteBoard(String id) async {
    final boards = getBoards().where((b) => b.id != id).toList();
    await _saveBoards(boards);
    return boards;
  }

  // ---------------------------------------------------------------------------
  // User Data Sync (boards, prefs, settings)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _getSettingsObject() => {
        'theme': _box.get(_keyTheme),
        'locationId': _box.get(_keyLocation) ?? defaultLocationId,
        'onboarded': _box.get(_keyOnboarded) == 'true',
      };

  /// Non-blocking push of a single column to user_data table.
  void _pushUserData(String column, dynamic value) {
    if (_guest) return;
    final userId = _userId;
    if (userId == null) return;

    _supabase
        ?.from('user_data')
        .upsert(
          {
            'user_id': userId,
            column: value,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id',
        )
        .then((_) {}, onError: (_) {});
  }

  /// Sync boards, prefs, settings from Supabase (Supabase wins on conflict).
  /// Returns true if local data changed.
  Future<bool> syncUserData() async {
    if (_guest || _syncingUserData) return false;
    final userId = _userId;
    if (userId == null) return false;

    _syncingUserData = true;
    var changed = false;

    try {
      final res = await _supabase!
          .from('user_data')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (res == null) {
        // No remote data — push local up
        _pushUserData('boards', getBoards().map((b) => b.toJson()).toList());
        _pushUserData('prefs', getPrefs().toJson());
        _pushUserData('settings', _getSettingsObject());
        return false;
      }

      final data = res as Map<String, dynamic>;

      // Snapshot local state
      final prevPrefs = _box.get(_keyPrefs);
      final prevBoards = _box.get(_keyBoards);
      final prevTheme = _box.get(_keyTheme);
      final prevLocation = _box.get(_keyLocation);

      // Merge boards by ID (Supabase wins)
      final remoteBoards = data['boards'] as List?;
      if (remoteBoards != null && remoteBoards.isNotEmpty) {
        final localBoards = getBoards();
        final merged = <String, Board>{};
        for (final b in localBoards) {
          merged[b.id] = b;
        }
        for (final raw in remoteBoards) {
          final b = Board.fromJson(raw as Map<String, dynamic>);
          merged[b.id] = b; // Supabase wins
        }
        final mergedList = merged.values.toList();
        await _box.put(
            _keyBoards, jsonEncode(mergedList.map((b) => b.toJson()).toList()));

        // Push local-only boards up
        final remoteIds =
            remoteBoards.map((r) => (r as Map)['id'] as String).toSet();
        if (localBoards.any((b) => !remoteIds.contains(b.id))) {
          _pushUserData(
              'boards', mergedList.map((b) => b.toJson()).toList());
        }
      }

      // Prefs: Supabase wins entirely
      final remotePrefs = data['prefs'] as Map<String, dynamic>?;
      if (remotePrefs != null && remotePrefs.isNotEmpty) {
        await _box.put(_keyPrefs, jsonEncode(remotePrefs));
      } else {
        _pushUserData('prefs', getPrefs().toJson());
      }

      // Settings: Supabase wins
      final remoteSettings = data['settings'] as Map<String, dynamic>?;
      if (remoteSettings != null && remoteSettings.isNotEmpty) {
        if (remoteSettings['theme'] != null) {
          await _box.put(_keyTheme, remoteSettings['theme'] as String);
        }
        if (remoteSettings['locationId'] != null) {
          await _box.put(
              _keyLocation, remoteSettings['locationId'] as String);
        }
        if (remoteSettings['onboarded'] == true) {
          await _box.put(_keyOnboarded, 'true');
        }
      } else {
        _pushUserData('settings', _getSettingsObject());
      }

      // Check if anything changed
      changed = prevPrefs != _box.get(_keyPrefs) ||
          prevBoards != _box.get(_keyBoards) ||
          prevTheme != _box.get(_keyTheme) ||
          prevLocation != _box.get(_keyLocation);
    } catch (_) {
      // Silent fail
    } finally {
      _syncingUserData = false;
    }
    return changed;
  }

  /// Migrate all local data to Supabase on first sign-in.
  Future<void> migrateGuestData() async {
    if (_guest) return;
    final userId = _userId;
    if (userId == null) return;

    try {
      await _supabase!.from('user_data').upsert(
        {
          'user_id': userId,
          'boards': getBoards().map((b) => b.toJson()).toList(),
          'prefs': getPrefs().toJson(),
          'settings': _getSettingsObject(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );
    } catch (_) {}
  }

  /// Clear all local data.
  Future<void> clearAll() async {
    await _box.clear();
  }
}
