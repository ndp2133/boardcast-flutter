/// Board quiver provider — CRUD + sync
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board.dart';
import 'store_provider.dart';

class BoardsNotifier extends Notifier<List<Board>> {
  @override
  List<Board> build() {
    final store = ref.read(storeServiceProvider);
    return store.getBoards();
  }

  Future<void> add(Board board) async {
    final store = ref.read(storeServiceProvider);
    state = await store.addBoard(board);
  }

  Future<void> update(String id, Board updated) async {
    final store = ref.read(storeServiceProvider);
    state = await store.updateBoard(id, updated);
  }

  Future<void> delete(String id) async {
    final store = ref.read(storeServiceProvider);
    state = await store.deleteBoard(id);
  }

  /// Refresh from store (e.g. after sync).
  void refresh() {
    final store = ref.read(storeServiceProvider);
    state = store.getBoards();
  }
}

final boardsProvider =
    NotifierProvider<BoardsNotifier, List<Board>>(BoardsNotifier.new);
