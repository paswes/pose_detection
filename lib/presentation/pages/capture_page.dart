import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/di/service_locator.dart';
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
  late final LatencyThresholds _thresholds;

  @override
  void initState() {
    super.initState();
    _thresholds = sl<PoseDetectionConfig>().latencyThresholds;
  }

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
    final metrics = state.session.metrics;
    final fps = metrics.effectiveFps(duration);
    final avgConfidence = state.currentPose?.avgConfidence ?? 0.0;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: Duration + FPS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Duration
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF404040),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$minutes:$seconds',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),

                // FPS + Poses
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF404040),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${fps.toStringAsFixed(1)} FPS  |  ${state.session.capturedPoses.length} poses',
                    style: const TextStyle(
                      color: Color(0xFFBBBBBB),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Metrics grid - row 1
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF333333),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricChip(
                        'Latency',
                        '${metrics.lastEndToEndLatencyMs.toStringAsFixed(0)}ms',
                        _getLatencyColor(metrics.lastEndToEndLatencyMs),
                      ),
                      _buildMetricChip(
                        'Drop',
                        '${metrics.dropRate.toStringAsFixed(1)}%',
                        metrics.dropRate > 5
                            ? const Color(0xFFF44336)
                            : const Color(0xFF888888),
                      ),
                      _buildMetricChip(
                        'Detect',
                        '${metrics.detectionRate.toStringAsFixed(0)}%',
                        metrics.detectionRate > 90
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF888888),
                      ),
                      _buildMetricChip(
                        'Conf',
                        avgConfidence.toStringAsFixed(2),
                        _getConfidenceColor(avgConfidence),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 9),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// Returns color based on end-to-end latency thresholds from config
  Color _getLatencyColor(double latencyMs) {
    if (latencyMs < _thresholds.excellent) {
      return const Color(0xFF4CAF50); // Green
    }
    if (latencyMs < _thresholds.acceptable) {
      return const Color(0xFFFFEB3B); // Yellow
    }
    if (latencyMs < _thresholds.warning) {
      return const Color(0xFFFF9800); // Orange
    }
    return const Color(0xFFF44336); // Red
  }

  /// Returns color based on average confidence
  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) {
      return const Color(0xFF4CAF50); // Green
    }
    if (confidence > 0.5) {
      return const Color(0xFFFFEB3B); // Yellow
    }
    return const Color(0xFFF44336); // Red
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
        child: Icon(Icons.stop, color: Colors.white, size: 28),
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
          border: Border.all(
            color: Colors.cyan.withValues(alpha: 0.5),
            width: 1,
          ),
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
    return GestureDetector(
      onTap: () => setState(() => _showRawData = false),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        padding: EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            children: [
              // Tap area to close
              Expanded(
                flex: 1,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white54,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap to close',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              // Data view
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () {}, // Prevent close when tapping inside data view
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      border: Border.all(
                        color: Colors.cyan.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: RawDataView(pose: state.currentPose),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
