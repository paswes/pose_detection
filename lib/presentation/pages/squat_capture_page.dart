import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';
import 'package:pose_detection/presentation/bloc/squat_analysis_bloc.dart';
import 'package:pose_detection/presentation/bloc/squat_analysis_event.dart';
import 'package:pose_detection/presentation/bloc/squat_analysis_state.dart';
import 'package:pose_detection/presentation/pages/squat_session_summary_page.dart';
import 'package:pose_detection/presentation/widgets/camera_preview_widget.dart';
import 'package:pose_detection/presentation/widgets/pose_painter.dart';
import 'package:pose_detection/presentation/widgets/squat_feedback_overlay.dart';

/// Fullscreen squat capture page with real-time form feedback
class SquatCapturePage extends StatefulWidget {
  const SquatCapturePage({super.key});

  @override
  State<SquatCapturePage> createState() => _SquatCapturePageState();
}

class _SquatCapturePageState extends State<SquatCapturePage> {
  DateTime? _sessionStartTime;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();

    // Start squat analysis when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SquatAnalysisBloc>().add(const StartSquatAnalysisEvent());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MultiBlocListener(
        listeners: [
          // Listen for pose detection state changes
          BlocListener<PoseDetectionBloc, PoseDetectionState>(
            listener: (context, state) {
              if (state is SessionSummary) {
                // Pose detection stopped, stop squat analysis
                context.read<SquatAnalysisBloc>().add(const StopSquatAnalysisEvent());
              }
            },
          ),
          // Listen for squat analysis completion
          BlocListener<SquatAnalysisBloc, SquatAnalysisState>(
            listener: (context, state) {
              if (state is SquatAnalysisCompleted) {
                // Navigate to summary page
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => SquatSessionSummaryPage(
                      session: state.finalSession,
                    ),
                  ),
                );
              }
            },
          ),
        ],
        child: BlocBuilder<PoseDetectionBloc, PoseDetectionState>(
          builder: (context, poseState) {
            if (poseState is! Detecting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.cyan),
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                CameraPreviewWidget(cameraController: poseState.cameraController),

                // Pose overlay
                if (poseState.currentPose != null && poseState.imageSize != null)
                  _buildPoseOverlay(poseState),

                // Squat feedback overlay
                _buildSquatFeedback(),

                // Stop button (bottom center)
                _buildStopButton(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPoseOverlay(Detecting state) {
    final screenSize = MediaQuery.of(context).size;

    return SizedBox.expand(
      child: CustomPaint(
        painter: PosePainter(
          pose: state.currentPose!,
          imageSize: state.imageSize!,
          widgetSize: screenSize,
        ),
      ),
    );
  }

  Widget _buildSquatFeedback() {
    return BlocBuilder<SquatAnalysisBloc, SquatAnalysisState>(
      builder: (context, state) {
        if (state is! SquatAnalyzing) {
          return const SizedBox.shrink();
        }

        final sessionDuration = _sessionStartTime != null
            ? DateTime.now().difference(_sessionStartTime!)
            : Duration.zero;

        return SquatFeedbackOverlay(
          metrics: state.currentMetrics,
          lastCompletedRep: state.lastCompletedRep,
          sessionDuration: sessionDuration,
        );
      },
    );
  }

  Widget _buildStopButton() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: GestureDetector(
            onTap: _stopSession,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'FINISH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _stopSession() {
    // Stop pose detection (this will trigger squat analysis stop via listener)
    context.read<PoseDetectionBloc>().add(StopCaptureEvent());
  }
}
