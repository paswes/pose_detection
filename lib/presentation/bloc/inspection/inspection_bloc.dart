import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/config/inspection_config.dart';
import 'package:pose_detection/core/data_structures/rolling_window.dart';
import 'package:pose_detection/core/interfaces/motion_analyzer_interface.dart';
import 'package:pose_detection/core/services/motion_analyzer.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/motion_metrics.dart';
import 'package:pose_detection/domain/models/inspection_snapshot.dart';

import 'inspection_event.dart';
import 'inspection_state.dart';

/// BLoC for managing inspection tool state
/// Processes pose data and maintains rolling windows for charts
class InspectionBloc extends Bloc<InspectionEvent, InspectionState> {
  final IMotionAnalyzer _motionAnalyzer;
  final InspectionConfig _config;

  // Rolling windows for chart data
  late final RollingDoubleWindow _fpsWindow;
  late final RollingDoubleWindow _latencyWindow;
  late final RollingDoubleWindow _confidenceWindow;

  // Pose history for velocity calculations
  final List<TimestampedPose> _recentPoses = [];
  static const _maxHistorySize = 10;

  InspectionBloc({
    IMotionAnalyzer? motionAnalyzer,
    InspectionConfig? config,
  })  : _motionAnalyzer = motionAnalyzer ?? MotionAnalyzer(),
        _config = config ?? InspectionConfig.defaultConfig,
        super(const InspectionInitial()) {
    // Initialize rolling windows
    _fpsWindow = RollingDoubleWindow(
      windowDuration: Duration(seconds: _config.chartWindowSeconds),
    );
    _latencyWindow = RollingDoubleWindow(
      windowDuration: Duration(seconds: _config.chartWindowSeconds),
    );
    _confidenceWindow = RollingDoubleWindow(
      windowDuration: Duration(seconds: _config.chartWindowSeconds),
    );

    // Register event handlers
    on<UpdateInspectionDataEvent>(_onUpdateData);
    on<SelectLandmarkEvent>(_onSelectLandmark);
    on<ClearInspectionEvent>(_onClear);
  }

  void _onUpdateData(
    UpdateInspectionDataEvent event,
    Emitter<InspectionState> emit,
  ) {
    final session = event.session;
    final currentPose = event.currentPose;
    final timestampMicros = DateTime.now().microsecondsSinceEpoch;

    // Update rolling windows with current metrics
    final fps = session.metrics.effectiveFps(session.duration);
    final latency = session.metrics.lastEndToEndLatencyMs;

    _fpsWindow.add(fps, timestampMicros);
    _latencyWindow.add(latency, timestampMicros);

    MotionMetrics motionMetrics = MotionMetrics.empty;

    if (currentPose != null) {
      _confidenceWindow.add(currentPose.avgConfidence, timestampMicros);

      // Maintain pose history for velocity calculation
      _recentPoses.add(currentPose);
      if (_recentPoses.length > _maxHistorySize) {
        _recentPoses.removeAt(0);
      }

      // Analyze motion with history
      motionMetrics = _motionAnalyzer.analyzeWithHistory(
        currentPose,
        _recentPoses.sublist(0, _recentPoses.length - 1),
      );
    }

    // Build inspection snapshot
    final snapshot = InspectionSnapshot(
      performanceMetrics: session.metrics,
      sessionDuration: session.duration,
      motionMetrics: motionMetrics,
      currentPose: currentPose,
      fpsHistory: _fpsWindow.values,
      latencyHistory: _latencyWindow.values,
      confidenceHistory: _confidenceWindow.values,
    );

    // Preserve selected landmark if already active
    final selectedLandmarkId =
        state is InspectionActive ? (state as InspectionActive).selectedLandmarkId : null;

    emit(InspectionActive(
      snapshot: snapshot,
      selectedLandmarkId: selectedLandmarkId,
    ));
  }

  void _onSelectLandmark(
    SelectLandmarkEvent event,
    Emitter<InspectionState> emit,
  ) {
    if (state is InspectionActive) {
      final currentState = state as InspectionActive;
      emit(currentState.copyWith(
        selectedLandmarkId: event.landmarkId,
        clearSelectedLandmark: event.landmarkId == null,
      ));
    }
  }

  void _onClear(
    ClearInspectionEvent event,
    Emitter<InspectionState> emit,
  ) {
    _fpsWindow.clear();
    _latencyWindow.clear();
    _confidenceWindow.clear();
    _recentPoses.clear();
    emit(const InspectionInitial());
  }
}
