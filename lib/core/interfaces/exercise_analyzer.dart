import 'package:flutter/widgets.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/data/models/session.dart';
import 'package:pose_detection/core/data/models/tracked_frame.dart';

abstract class ExerciseAnalyzer {
  LandmarkSchema get schema;

  Set<int>? get visibleLandmarkIds;

  void precompute(List<TrackedFrame> frames);

  void processFrame(TrackedFrame frame, {required int globalFrameIndex});

  void processFrameRange(
    List<TrackedFrame> frames,
    int startIndex,
    int endIndex,
  );

  void replayUpTo(List<TrackedFrame> frames, int targetIndex);

  void reset();

  Widget? buildHud(BuildContext context, int currentFrameIndex);

  Widget? buildSliderExtras(
    BuildContext context, {
    required int totalFrames,
    required int currentFrameIndex,
    required void Function(int frameIndex) onSeekToFrame,
  });

  List<({String label, String value})> computeDetailMetrics(
    TrackedFrame? frame,
  );

  Widget? buildAnalyticsPage(Session session);

  Set<int> get injuredLandmarkIds => const {};

  void toggleInjury(int id) {}
}
