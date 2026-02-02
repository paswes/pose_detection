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
/// Supports Minimal and Detail view modes
class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  bool _isDetailMode = false;
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
      backgroundColor: const Color(0xFF121212),
      body: BlocConsumer<PoseDetectionBloc, PoseDetectionState>(
        listener: (context, state) {
          if (state is SessionSummary) {
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          if (state is! Detecting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF888888)),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview (mirrored for front camera)
              CameraPreviewWidget(
                cameraController: state.cameraController,
                isFrontCamera: state.isFrontCamera,
              ),

              // Pose overlay
              if (state.currentPose != null && state.imageSize != null)
                _buildPoseOverlay(state),

              // Top metrics bar
              _isDetailMode
                  ? _buildDetailTopBar(state)
                  : _buildMinimalTopBar(state),

              // Bottom controls
              _buildBottomControls(state),

              // Raw data overlay (detail mode only)
              if (_isDetailMode && _showRawData) _buildRawDataOverlay(state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPoseOverlay(Detecting state) {
    final screenSize = MediaQuery.of(context).size;

    Widget overlay = SizedBox.expand(
      child: CustomPaint(
        painter: PosePainter(
          pose: state.currentPose!,
          imageSize: state.imageSize!,
          widgetSize: screenSize,
        ),
      ),
    );

    // Mirror the pose overlay for front camera (to match mirrored preview)
    if (state.isFrontCamera) {
      overlay = Transform.flip(
        flipX: true,
        child: overlay,
      );
    }

    return overlay;
  }

  // ============================================================
  // MINIMAL MODE - 3 metrics only
  // ============================================================

  Widget _buildMinimalTopBar(Detecting state) {
    final metrics = state.session.metrics;
    final duration = state.session.duration;
    final fps = metrics.effectiveFps(duration);
    final latency = metrics.lastEndToEndLatencyMs;
    final confidence = state.currentPose?.avgConfidence ?? 0.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMinimalMetric(
              fps.toStringAsFixed(1),
              'FPS',
              _getFpsColor(fps),
            ),
            _buildMinimalMetric(
              '${latency.toStringAsFixed(0)}ms',
              'Latency',
              _getLatencyColor(latency),
            ),
            _buildMinimalMetric(
              confidence.toStringAsFixed(2),
              'Conf',
              _getConfidenceColor(confidence),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalMetric(String value, String label, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL MODE - All metrics
  // ============================================================

  Widget _buildDetailTopBar(Detecting state) {
    final duration = state.session.duration;
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final metrics = state.session.metrics;
    final fps = metrics.effectiveFps(duration);
    final avgConfidence = state.currentPose?.avgConfidence ?? 0.0;
    final highConf = state.currentPose?.highConfidenceLandmarks ?? 0;
    final lowConf = state.currentPose?.lowConfidenceLandmarks ?? 0;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF333333), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Duration + FPS + Poses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  '${fps.toStringAsFixed(1)} FPS  ·  ${state.session.capturedPoses.length} poses',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Latency metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDetailMetric(
                  'E2E',
                  '${metrics.lastEndToEndLatencyMs.toStringAsFixed(0)}ms',
                  _getLatencyColor(metrics.lastEndToEndLatencyMs),
                ),
                _buildDetailMetric(
                  'ML',
                  '${metrics.averageLatencyMs.toStringAsFixed(0)}ms',
                  _getLatencyColor(metrics.averageLatencyMs),
                ),
                _buildDetailMetric(
                  'Drop',
                  '${metrics.dropRate.toStringAsFixed(1)}%',
                  metrics.dropRate > 5
                      ? const Color(0xFFF44336)
                      : const Color(0xFF888888),
                ),
                _buildDetailMetric(
                  'Detect',
                  '${metrics.detectionRate.toStringAsFixed(0)}%',
                  metrics.detectionRate > 90
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF888888),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 3: Confidence metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDetailMetric(
                  'Avg Conf',
                  avgConfidence.toStringAsFixed(2),
                  _getConfidenceColor(avgConfidence),
                ),
                _buildDetailMetric(
                  'High',
                  '$highConf',
                  const Color(0xFF4CAF50),
                ),
                _buildDetailMetric(
                  'Low',
                  '$lowConf',
                  lowConf > 5
                      ? const Color(0xFFF44336)
                      : const Color(0xFF888888),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailMetric(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF666666), fontSize: 9),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM CONTROLS
  // ============================================================

  Widget _buildBottomControls(Detecting state) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Toggle mode button
              _buildControlButton(
                icon: _isDetailMode ? Icons.visibility_off : Icons.visibility,
                label: _isDetailMode ? 'Minimal' : 'Detail',
                onTap: () => setState(() {
                  _isDetailMode = !_isDetailMode;
                  if (!_isDetailMode) _showRawData = false;
                }),
              ),

              // Camera switch button (only if device has multiple cameras)
              if (state.canSwitchCamera)
                _buildControlButton(
                  icon: Icons.flip_camera_ios,
                  label: state.isFrontCamera ? 'Back' : 'Front',
                  onTap: () {
                    context.read<PoseDetectionBloc>().add(SwitchCameraEvent());
                  },
                ),

              // Raw data button (only in detail mode)
              if (_isDetailMode)
                _buildControlButton(
                  icon: _showRawData ? Icons.close : Icons.data_array,
                  label: _showRawData ? 'Hide' : 'Data',
                  onTap: () => setState(() => _showRawData = !_showRawData),
                ),

              // Stop button
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
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF44336),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.stop, color: Colors.white, size: 24),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF333333), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF888888), size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RAW DATA OVERLAY
  // ============================================================

  Widget _buildRawDataOverlay(Detecting state) {
    return GestureDetector(
      onTap: () => setState(() => _showRawData = false),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: const Color(0xFF121212).withValues(alpha: 0.9),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            children: [
              // Tap to close hint
              const Expanded(
                flex: 1,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF444444),
                        size: 28,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap to close',
                        style: TextStyle(color: Color(0xFF444444), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              // Data view
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () {}, // Prevent close when tapping inside
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF333333),
                        width: 1,
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

  // ============================================================
  // COLOR HELPERS
  // ============================================================

  Color _getFpsColor(double fps) {
    if (fps >= 25) return const Color(0xFF4CAF50);
    if (fps >= 15) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }

  Color _getLatencyColor(double latencyMs) {
    if (latencyMs < _thresholds.excellent) return const Color(0xFF4CAF50);
    if (latencyMs < _thresholds.acceptable) return const Color(0xFFFFEB3B);
    if (latencyMs < _thresholds.warning) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return const Color(0xFF4CAF50);
    if (confidence > 0.5) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }
}
