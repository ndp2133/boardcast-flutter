/// Riverpod provider for HealthKit import state machine.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/preference_inference.dart';
import '../services/health_import_service.dart';
import 'sessions_provider.dart';

enum ImportPhase { idle, requesting, discovering, enriching, complete, error }

class HealthImportState {
  final ImportPhase phase;
  final int discoveredCount;
  final int enrichProgress;
  final int enrichTotal;
  final ImportResult? result;
  final InferredPrefs? inferredPrefs;
  final String? errorMessage;

  const HealthImportState({
    this.phase = ImportPhase.idle,
    this.discoveredCount = 0,
    this.enrichProgress = 0,
    this.enrichTotal = 0,
    this.result,
    this.inferredPrefs,
    this.errorMessage,
  });

  HealthImportState copyWith({
    ImportPhase? phase,
    int? discoveredCount,
    int? enrichProgress,
    int? enrichTotal,
    ImportResult? result,
    InferredPrefs? inferredPrefs,
    String? errorMessage,
  }) =>
      HealthImportState(
        phase: phase ?? this.phase,
        discoveredCount: discoveredCount ?? this.discoveredCount,
        enrichProgress: enrichProgress ?? this.enrichProgress,
        enrichTotal: enrichTotal ?? this.enrichTotal,
        result: result ?? this.result,
        inferredPrefs: inferredPrefs ?? this.inferredPrefs,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class HealthImportNotifier extends Notifier<HealthImportState> {
  final HealthImportService _service = HealthImportService();

  @override
  HealthImportState build() => const HealthImportState();

  /// Check if HealthKit is available on this platform
  Future<bool> isAvailable() async {
    try {
      return await _service.isHealthAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Run the full import flow
  Future<void> startImport({String? homeLocationId, String? userId}) async {
    // Phase 1: Request permission
    state = state.copyWith(phase: ImportPhase.requesting);

    final granted = await _service.requestPermission();
    if (!granted) {
      state = state.copyWith(
        phase: ImportPhase.error,
        errorMessage: 'Health permission denied',
      );
      return;
    }

    // Phase 2: Discover workouts
    state = state.copyWith(phase: ImportPhase.discovering);

    final workouts = await _service.readSurfWorkouts();
    if (workouts.isEmpty) {
      state = state.copyWith(
        phase: ImportPhase.complete,
        discoveredCount: 0,
        result: const ImportResult(sessions: [], totalDiscovered: 0),
      );
      return;
    }

    final candidates = _service.snapToLocations(
      workouts,
      homeLocationId: homeLocationId,
    );

    state = state.copyWith(discoveredCount: candidates.length);

    // Phase 3: Enrich with conditions
    state = state.copyWith(
      phase: ImportPhase.enriching,
      enrichTotal: candidates.length,
    );

    // Get existing session IDs for dedup
    final existingSessions = ref.read(sessionsProvider);
    final existingIds = existingSessions.map((s) => s.id).toSet();

    try {
      final result = await _service.enrichWithConditions(
        candidates,
        existingIds: existingIds,
        userId: userId,
        onProgress: (completed, total) {
          state = state.copyWith(
            enrichProgress: completed,
            enrichTotal: total,
          );
        },
      );

      // Infer preferences from imported sessions
      final inferredPrefs = inferPrefsFromSessions(result.sessions);

      state = state.copyWith(
        phase: ImportPhase.complete,
        result: result,
        inferredPrefs: inferredPrefs,
      );
    } catch (e) {
      state = state.copyWith(
        phase: ImportPhase.error,
        errorMessage: 'Import failed: $e',
      );
    }
  }

  /// Persist imported sessions to store
  Future<void> saveImportedSessions() async {
    final result = state.result;
    if (result == null || result.sessions.isEmpty) return;

    await ref.read(sessionsProvider.notifier).addBatch(result.sessions);
  }

  /// Reset state for re-import
  void reset() {
    state = const HealthImportState();
  }
}

final healthImportProvider =
    NotifierProvider<HealthImportNotifier, HealthImportState>(
        HealthImportNotifier.new);
