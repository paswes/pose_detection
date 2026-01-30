import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/utils/logger.dart';
import 'package:pose_detection/domain/analyzers/squat_analyzer.dart';
import 'package:pose_detection/domain/models/squat_metrics.dart';
import 'package:pose_detection/domain/models/squat_rep.dart';
import 'package:pose_detection/domain/models/squat_session.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';
import 'package:pose_detection/presentation/bloc/squat_analysis_event.dart';
import 'package:pose_detection/presentation/bloc/squat_analysis_state.dart';

/// BLoC for squat-specific analysis
///
/// Subscribes to PoseDetectionBloc and processes poses through SquatAnalyzer
/// to provide real-time squat form feedback and rep counting.
class SquatAnalysisBloc extends Bloc<SquatAnalysisEvent, SquatAnalysisState> {
  final PoseDetectionBloc _poseDetectionBloc;
  final SquatAnalyzer _analyzer = SquatAnalyzer();

  StreamSubscription? _poseSubscription;
  SquatMetrics? _previousMetrics;
  SquatSession _session = SquatSession.start();

  SquatAnalysisBloc({
    required PoseDetectionBloc poseDetectionBloc,
  })  : _poseDetectionBloc = poseDetectionBloc,
        super(const SquatAnalysisInitial()) {
    on<StartSquatAnalysisEvent>(_onStart);
    on<StopSquatAnalysisEvent>(_onStop);
    on<ResetSquatAnalysisEvent>(_onReset);
    // Use droppable transformer for high-frequency pose events
    on<AnalyzePoseEvent>(_onAnalyzePose, transformer: droppable());
  }

  Future<void> _onStart(
    StartSquatAnalysisEvent event,
    Emitter<SquatAnalysisState> emit,
  ) async {
    Logger.info('SquatAnalysisBloc', 'Starting squat analysis...');

    // Reset analyzer state
    _analyzer.reset();
    _previousMetrics = null;
    _session = SquatSession.start();

    // Emit initial analyzing state
    emit(SquatAnalyzing(
      currentMetrics: SquatMetrics.initial(),
      session: _session,
    ));

    // Subscribe to pose detection state changes
    _poseSubscription?.cancel();
    _poseSubscription = _poseDetectionBloc.stream.listen((poseState) {
      if (poseState is Detecting && poseState.currentPose != null) {
        add(AnalyzePoseEvent(poseState.currentPose!));
      }
    });

    Logger.info('SquatAnalysisBloc', 'Squat analysis started');
  }

  Future<void> _onAnalyzePose(
    AnalyzePoseEvent event,
    Emitter<SquatAnalysisState> emit,
  ) async {
    if (state is! SquatAnalyzing) return;

    try {
      // Analyze the pose
      final metrics = _analyzer.analyzePose(event.pose, _previousMetrics);

      // Check for rep completion
      SquatRep? completedRep;
      if (_previousMetrics != null) {
        completedRep = _analyzer.checkRepCompletion(metrics, _previousMetrics!);

        if (completedRep != null) {
          Logger.info(
            'SquatAnalysisBloc',
            'Rep ${completedRep.repNumber} completed! '
            'Form: ${(completedRep.overallFormScore * 100).toStringAsFixed(0)}%, '
            'Depth: ${completedRep.depthPercentage.toStringAsFixed(0)}%',
          );

          // Update session with completed rep
          _session = _session.withCompletedRep(completedRep);
        }
      }

      // Update session metrics
      _session = _session.copyWith(currentMetrics: metrics);

      // Store previous metrics for next frame
      _previousMetrics = metrics;

      // Emit updated state
      emit(SquatAnalyzing(
        currentMetrics: metrics,
        session: _session,
        lastCompletedRep: completedRep,
      ));
    } catch (e) {
      Logger.error('SquatAnalysisBloc', 'Error analyzing pose: $e');
      // Don't emit error state for single frame failures
      // Just continue with next frame
    }
  }

  Future<void> _onStop(
    StopSquatAnalysisEvent event,
    Emitter<SquatAnalysisState> emit,
  ) async {
    Logger.info('SquatAnalysisBloc', 'Stopping squat analysis...');

    // Cancel pose subscription
    await _poseSubscription?.cancel();
    _poseSubscription = null;

    // Finalize session
    final finalSession = _session.finish();

    Logger.info('SquatAnalysisBloc', 'Squat Analysis Summary:');
    Logger.info('SquatAnalysisBloc', '  Total Reps: ${finalSession.totalReps}');
    Logger.info(
      'SquatAnalysisBloc',
      '  Overall Form: ${(finalSession.overallFormScore * 100).toStringAsFixed(0)}%',
    );
    Logger.info(
      'SquatAnalysisBloc',
      '  Avg Depth: ${finalSession.averageDepth.toStringAsFixed(0)}%',
    );
    Logger.info(
      'SquatAnalysisBloc',
      '  Duration: ${finalSession.duration.inSeconds}s',
    );

    emit(SquatAnalysisCompleted(finalSession: finalSession));
  }

  Future<void> _onReset(
    ResetSquatAnalysisEvent event,
    Emitter<SquatAnalysisState> emit,
  ) async {
    Logger.info('SquatAnalysisBloc', 'Resetting squat analysis...');

    await _poseSubscription?.cancel();
    _poseSubscription = null;

    _analyzer.reset();
    _previousMetrics = null;
    _session = SquatSession.start();

    emit(const SquatAnalysisInitial());
  }

  @override
  Future<void> close() async {
    await _poseSubscription?.cancel();
    return super.close();
  }
}
