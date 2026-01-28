import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';
import 'package:pose_detection/presentation/widgets/camera_preview_widget.dart';
import 'package:pose_detection/presentation/widgets/pose_painter.dart';
import 'package:pose_detection/presentation/widgets/raw_data_view.dart';

/// Fullscreen camera capture page with pose overlay
class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  bool _showRawData = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<PoseDetectionBloc, PoseDetectionState>(
        listener: (context, state) {
          if (state is SessionSummary) {
            // Navigate back to dashboard with summary
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          if (state is! Detecting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyan),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview
              CameraPreviewWidget(cameraController: state.cameraController),

              // Pose overlay
              if (state.currentPose != null && state.imageSize != null)
                _buildPoseOverlay(state),

              // Top stats bar
              _buildTopBar(state),

              // Bottom controls
              _buildBottomControls(),

              // Raw data overlay (optional)
              if (_showRawData) _buildRawDataOverlay(state),
            ],
          );
        },
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

  Widget _buildTopBar(Detecting state) {
    final duration = state.session.duration;
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Duration
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$minutes:$seconds',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Frames: ${state.session.totalFramesProcessed}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    'Poses: ${state.session.capturedPoses.length}',
                    style: const TextStyle(color: Colors.cyan, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Toggle raw data
              _buildControlButton(
                icon: _showRawData ? Icons.visibility_off : Icons.data_array,
                label: _showRawData ? 'Hide Data' : 'Show Data',
                onTap: () => setState(() => _showRawData = !_showRawData),
              ),

              // Stop button (larger, primary action)
              _buildStopButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: () {
        context.read<PoseDetectionBloc>().add(StopCaptureEvent());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
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
            Icon(Icons.stop, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              'STOP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.cyan.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.cyan, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawDataOverlay(Detecting state) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 2),
            ),
            child: RawDataView(pose: state.currentPose),
          );
        },
      ),
    );
  }
}
