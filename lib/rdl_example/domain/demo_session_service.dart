/// Interface for feature-provided demo session seeding.
///
/// Features can implement this to provide a pre-bundled demo session
/// that gets processed on first launch. The [SessionListCubit] calls
/// this during [loadSessions] to seed demo data before showing the list.
///
/// Set to `null` in [initializeDependencies] if no demo is needed.
abstract class DemoSessionService {
  /// Whether the demo session still needs processing.
  Future<bool> needsProcessing();

  /// Process and save the demo session.
  Future<void> ensureDemoSession({
    void Function(int completed, int total)? onProgress,
  });
}
