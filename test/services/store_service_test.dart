import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:boardcast_flutter/services/store_service.dart';
import 'package:boardcast_flutter/models/models.dart';

void main() {
  late StoreService store;

  setUpAll(() async {
    // Use temp directory for Hive in tests
    Hive.init('/tmp/hive_test_${DateTime.now().millisecondsSinceEpoch}');
  });

  setUp(() async {
    store = StoreService();
    await store.init();
  });

  tearDown(() async {
    await store.clearAll();
  });

  group('Preferences', () {
    test('returns default prefs when empty', () {
      final prefs = store.getPrefs();
      expect(prefs.skillLevel, 'intermediate');
      expect(prefs.minWaveHeight, 0.6);
    });

    test('saves and retrieves prefs', () async {
      const prefs = UserPrefs(
        minWaveHeight: 0.5,
        maxWaveHeight: 3.0,
        maxWindSpeed: 40,
        preferredWindDir: 'any',
        skillLevel: 'advanced',
      );
      await store.savePrefs(prefs);
      final retrieved = store.getPrefs();
      expect(retrieved.minWaveHeight, 0.5);
      expect(retrieved.maxWaveHeight, 3.0);
      expect(retrieved.skillLevel, 'advanced');
    });
  });

  group('Onboarding', () {
    test('defaults to not onboarded', () {
      expect(store.isOnboarded, false);
    });

    test('setOnboarded persists', () async {
      await store.setOnboarded();
      expect(store.isOnboarded, true);
    });
  });

  group('Sessions', () {
    Session _makeSession({String id = 'test-1'}) => Session(
          id: id,
          locationId: 'rockaway',
          date: '2025-01-15',
          status: 'planned',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    test('starts empty', () {
      expect(store.getSessions(), isEmpty);
    });

    test('addSession persists', () async {
      await store.addSession(_makeSession());
      final sessions = store.getSessions();
      expect(sessions.length, 1);
      expect(sessions[0].id, 'test-1');
    });

    test('updateSession modifies existing', () async {
      final session = _makeSession();
      await store.addSession(session);

      final updated = session.copyWith(status: 'completed', rating: 4);
      await store.updateSession('test-1', updated);

      final sessions = store.getSessions();
      expect(sessions[0].status, 'completed');
      expect(sessions[0].rating, 4);
    });

    test('deleteSession removes', () async {
      await store.addSession(_makeSession(id: 'a'));
      await store.addSession(_makeSession(id: 'b'));
      expect(store.getSessions().length, 2);

      await store.deleteSession('a');
      final sessions = store.getSessions();
      expect(sessions.length, 1);
      expect(sessions[0].id, 'b');
    });
  });

  group('Location', () {
    test('defaults to rockaway', () {
      expect(store.getSelectedLocationId(), 'rockaway');
    });

    test('persists selection', () async {
      await store.setSelectedLocationId('huntington');
      expect(store.getSelectedLocationId(), 'huntington');
    });
  });

  group('Theme', () {
    test('defaults to null (system)', () {
      expect(store.getThemePref(), isNull);
    });

    test('persists dark', () async {
      await store.setThemePref('dark');
      expect(store.getThemePref(), 'dark');
    });

    test('null clears to system', () async {
      await store.setThemePref('dark');
      await store.setThemePref(null);
      expect(store.getThemePref(), isNull);
    });
  });

  group('Boards', () {
    test('starts empty', () {
      expect(store.getBoards(), isEmpty);
    });

    test('addBoard persists', () async {
      const board =
          Board(id: 'b1', name: 'My Fish', type: 'fish');
      await store.addBoard(board);
      final boards = store.getBoards();
      expect(boards.length, 1);
      expect(boards[0].name, 'My Fish');
    });

    test('updateBoard modifies existing', () async {
      const board =
          Board(id: 'b1', name: 'My Fish', type: 'fish');
      await store.addBoard(board);

      await store.updateBoard('b1', board.copyWith(name: 'Big Fish'));
      final boards = store.getBoards();
      expect(boards[0].name, 'Big Fish');
    });

    test('deleteBoard removes', () async {
      const b1 = Board(id: 'b1', name: 'Fish', type: 'fish');
      const b2 = Board(id: 'b2', name: 'Log', type: 'longboard');
      await store.addBoard(b1);
      await store.addBoard(b2);
      expect(store.getBoards().length, 2);

      await store.deleteBoard('b1');
      final boards = store.getBoards();
      expect(boards.length, 1);
      expect(boards[0].id, 'b2');
    });
  });

  group('clearAll', () {
    test('clears everything', () async {
      await store.savePrefs(const UserPrefs(skillLevel: 'advanced'));
      await store.setOnboarded();
      await store.setSelectedLocationId('miami');
      await store.setThemePref('dark');
      await store.addBoard(const Board(id: 'b1', name: 'X', type: 'fish'));

      await store.clearAll();

      expect(store.getPrefs().skillLevel, 'intermediate'); // default
      expect(store.isOnboarded, false);
      expect(store.getSelectedLocationId(), 'rockaway'); // default
      expect(store.getThemePref(), isNull);
      expect(store.getBoards(), isEmpty);
    });
  });

  group('skillDefaults', () {
    test('has three skill levels', () {
      expect(skillDefaults.keys, containsAll(['beginner', 'intermediate', 'advanced']));
    });

    test('beginner has lower wave heights', () {
      expect(skillDefaults['beginner']!.maxWaveHeight,
          lessThan(skillDefaults['advanced']!.maxWaveHeight!));
    });
  });
}
