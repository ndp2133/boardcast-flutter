/// Sessions provider — CRUD + sync
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import 'store_provider.dart';

class SessionsNotifier extends Notifier<List<Session>> {
  @override
  List<Session> build() {
    final store = ref.read(storeServiceProvider);
    return store.getSessions();
  }

  Future<void> add(Session session) async {
    final store = ref.read(storeServiceProvider);
    state = await store.addSession(session);
  }

  Future<void> update(String id, Session updated) async {
    final store = ref.read(storeServiceProvider);
    state = await store.updateSession(id, updated);
  }

  Future<void> delete(String id) async {
    final store = ref.read(storeServiceProvider);
    state = await store.deleteSession(id);
  }

  /// Sync with Supabase and refresh local state.
  Future<void> sync() async {
    final store = ref.read(storeServiceProvider);
    await store.syncSessions();
    state = store.getSessions();
  }

  /// Refresh from store (e.g. after migration).
  void refresh() {
    final store = ref.read(storeServiceProvider);
    state = store.getSessions();
  }
}

final sessionsProvider =
    NotifierProvider<SessionsNotifier, List<Session>>(SessionsNotifier.new);
