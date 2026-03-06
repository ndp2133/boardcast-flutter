// Riverpod provider for Strava import state machine.
// Mirrors HealthImportProvider pattern: connect → discover → enrich → save.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/strava_service.dart';
import '../services/health_import_service.dart';
import 'sessions_provider.dart';

enum StravaImportPhase {
  idle,
  connecting,
  discovering,
  enriching,
  complete,
  error,
}

class StravaImportState {
  final StravaImportPhase phase;
  final int discoveredCount;
  final int enrichProgress;
  final int enrichTotal;
  final ImportResult? result;
  final String? errorMessage;
  final bool isConnected;

  const StravaImportState({
    this.phase = StravaImportPhase.idle,
    this.discoveredCount = 0,
    this.enrichProgress = 0,
    this.enrichTotal = 0,
    this.result,
    this.errorMessage,
    this.isConnected = false,
  });

  StravaImportState copyWith({
    StravaImportPhase? phase,
    int? discoveredCount,
    int? enrichProgress,
    int? enrichTotal,
    ImportResult? result,
    String? errorMessage,
    bool? isConnected,
  }) =>
      StravaImportState(
        phase: phase ?? this.phase,
        discoveredCount: discoveredCount ?? this.discoveredCount,
        enrichProgress: enrichProgress ?? this.enrichProgress,
        enrichTotal: enrichTotal ?? this.enrichTotal,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
        isConnected: isConnected ?? this.isConnected,
      );
}

class StravaImportNotifier extends Notifier<StravaImportState> {
  final StravaService _strava = StravaService();
  final HealthImportService _importService = HealthImportService();

  @override
  StravaImportState build() {
    _initConnected();
    return const StravaImportState();
  }

  Future<void> _initConnected() async {
    final connected = await _strava.isConnected;
    state = state.copyWith(isConnected: connected);
  }

  /// Start Strava OAuth flow (opens browser)
  Future<void> startAuth() async {
    state = state.copyWith(phase: StravaImportPhase.connecting);
    final launched = await _strava.startAuth();
    if (!launched) {
      state = state.copyWith(
        phase: StravaImportPhase.error,
        errorMessage: 'Could not open Strava authorization page',
      );
    }
  }

  /// Handle OAuth callback with authorization code
  Future<void> handleCallback(String code, {String? state}) async {
    this.state = this.state.copyWith(phase: StravaImportPhase.connecting);

    final success = await _strava.exchangeCode(code, state: state);
    if (!success) {
      state = state.copyWith(
        phase: StravaImportPhase.error,
        errorMessage: 'Failed to connect to Strava',
      );
      return;
    }

    state = state.copyWith(isConnected: true);
    await _discoverAndImport();
  }

  /// Run import on an already-connected account
  Future<void> startImport() async {
    final connected = await _strava.isConnected;
    if (!connected) {
      await startAuth();
      return;
    }
    await _discoverAndImport();
  }

  Future<void> _discoverAndImport() async {
    state = state.copyWith(phase: StravaImportPhase.discovering);

    final activities = await _strava.fetchSurfActivityDetails();
    if (activities.isEmpty) {
      state = state.copyWith(
        phase: StravaImportPhase.complete,
        discoveredCount: 0,
        result: const ImportResult(sessions: [], totalDiscovered: 0),
      );
      return;
    }

    // Pre-filter: remove activities already imported (by strava fingerprint)
    final existingSessions = ref.read(sessionsProvider);
    final existingIds = existingSessions.map((s) => s.id).toSet();
    final newActivities =
        activities.where((a) => !existingIds.contains(a.fingerprint)).toList();
    final skippedDuplicates = activities.length - newActivities.length;

    state = state.copyWith(discoveredCount: activities.length);

    if (newActivities.isEmpty) {
      state = state.copyWith(
        phase: StravaImportPhase.complete,
        discoveredCount: activities.length,
        result: ImportResult(
          sessions: const [],
          totalDiscovered: activities.length,
          skippedDuplicate: skippedDuplicates,
        ),
      );
      return;
    }

    // Build lookup from startTime (ms) → StravaActivity for re-ID after enrichment
    final activityByStartMs = <int, StravaActivity>{};
    for (final a in newActivities) {
      activityByStartMs[a.startTime.millisecondsSinceEpoch] = a;
    }

    // Convert to RawHealthSession for the shared pipeline
    final rawSessions = newActivities.map((a) => a.toRawSession()).toList();
    final candidates = _importService.snapToLocations(rawSessions);

    state = state.copyWith(
      phase: StravaImportPhase.enriching,
      enrichTotal: candidates.length,
    );

    try {
      final result = await _importService.enrichWithConditions(
        candidates,
        existingIds: existingIds,
        onProgress: (completed, total) {
          state = state.copyWith(
            enrichProgress: completed,
            enrichTotal: total,
          );
        },
      );

      // Re-ID and re-source sessions: use strava_{activity_id} fingerprints
      final finalSessions = result.sessions.map((session) {
        // Match back to Strava activity by startTime milliseconds
        final match =
            activityByStartMs[session.createdAt.millisecondsSinceEpoch];

        final stravaId = match?.fingerprint ?? session.id;
        final hasGps = match?.lat != null;

        return Session(
          id: stravaId,
          userId: session.userId,
          locationId: session.locationId,
          date: session.date,
          status: session.status,
          selectedHours: session.selectedHours,
          conditions: session.conditions,
          source: hasGps ? 'strava' : 'strava_nogps',
          createdAt: session.createdAt,
          updatedAt: session.updatedAt,
        );
      }).toList();

      state = state.copyWith(
        phase: StravaImportPhase.complete,
        result: ImportResult(
          sessions: finalSessions,
          totalDiscovered: activities.length,
          skippedTooFar: result.skippedTooFar,
          skippedTooShort: result.skippedTooShort,
          skippedDuplicate: result.skippedDuplicate + skippedDuplicates,
          enrichedCount: result.enrichedCount,
          locationsFound: result.locationsFound,
          earliestDate: result.earliestDate,
          latestDate: result.latestDate,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        phase: StravaImportPhase.error,
        errorMessage: 'Import failed: $e',
      );
    }
  }

  /// Persist imported sessions
  Future<void> saveImportedSessions() async {
    final result = state.result;
    if (result == null || result.sessions.isEmpty) return;
    await ref.read(sessionsProvider.notifier).addBatch(result.sessions);
  }

  /// Disconnect Strava
  Future<void> disconnect() async {
    await _strava.disconnect();
    state = const StravaImportState();
  }

  void reset() {
    state = const StravaImportState();
    _initConnected();
  }
}

final stravaImportProvider =
    NotifierProvider<StravaImportNotifier, StravaImportState>(
        StravaImportNotifier.new);
