import 'package:flutter/widgets.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/data/models/session.dart';
import 'package:pose_detection/core/data/models/tracked_frame.dart';

/// Extension point for exercise-specific analysis on top of generic
/// session playback.
///
/// The generic [SessionDetailsCubit] delegates frame processing and UI
/// extensions to an optional [ExerciseAnalyzer]. When no analyzer is
/// provided, the session details page shows a raw landmark view.
///
/// **To create a new exercise feature:**
/// 1. Create a new folder under `lib/features/your_exercise/`.
/// 2. Implement this interface for your exercise.
/// 3. Create a feature entry point file (see `lib/features/rdl_example/rdl_feature.dart`).
/// 4. Wire it into `main.dart` via `initializeDependencies`.
///
/// See `lib/features/rdl_example/` for a complete reference implementation.
abstract class ExerciseAnalyzer {
  /// Landmark schema for overlay rendering (connections, names).
  LandmarkSchema get schema;

  /// Landmark IDs to draw on the overlay. Null = show all 33.
  Set<int>? get visibleLandmarkIds;

  /// Pre-compute analysis over all frames (called once on load).
  void precompute(List<TrackedFrame> frames);

  /// Process a single frame during forward playback.
  void processFrame(TrackedFrame frame, {required int globalFrameIndex});

  /// Process a contiguous range of frames (catch-up during fast playback).
  void processFrameRange(
    List<TrackedFrame> frames,
    int startIndex,
    int endIndex,
  );

  /// Replay from frame 0 to [targetIndex] (for backward seeks).
  void replayUpTo(List<TrackedFrame> frames, int targetIndex);

  /// Reset all analysis state.
  void reset();

  /// HUD widget for the top overlay (e.g. rep badge). Null = none.
  Widget? buildHud(BuildContext context, int currentFrameIndex);

  /// Widget above the slider (e.g. rep markers). Null = none.
  Widget? buildSliderExtras(
    BuildContext context, {
    required int totalFrames,
    required int currentFrameIndex,
    required void Function(int frameIndex) onSeekToFrame,
  });

  /// Metrics for the landmark detail sheet. Empty = no metrics row.
  List<({String label, String value})> computeDetailMetrics(
    TrackedFrame? frame,
  );

  /// Full-page analytics widget. Null = no analytics button in HUD.
  Widget? buildAnalyticsPage(Session session);

  /// Landmark IDs currently marked as injured/painful. Empty = none.
  Set<int> get injuredLandmarkIds => const {};

  /// Toggle injury marking for a landmark.
  void toggleInjury(int id) {}
}
