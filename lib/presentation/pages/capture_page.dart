import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';
import 'package:pose_detection/presentation/widgets/camera_preview_widget.dart';
import 'package:pose_detection/presentation/widgets/pose_painter.dart';

/// Fullscreen camera capture page with pose overlay
/// Single-screen app with start/stop detection controls
class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> with WidgetsBindingObserver {
  late final PoseDetectionBloc _bloc;

  @override
  void initState() {
    super.initState();

    // Lock to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    WidgetsBinding.instance.addObserver(this);

    // Initialize BLoC from service locator
    _bloc = sl<PoseDetectionBloc>();
    _bloc.add(InitializeEvent());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bloc.add(InitializeEvent());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.add(DisposeEvent());
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: BlocBuilder<PoseDetectionBloc, PoseDetectionState>(
          builder: (context, state) {
            // Handle initialization states
            if (state is PoseDetectionInitial || state is CameraInitializing) {
              return _buildLoadingView();
            }

            // Handle error state
            if (state is PoseDetectionError) {
              return _buildErrorView(state.message);
            }

            // Handle CameraReady state (idle, not detecting)
            if (state is CameraReady) {
              return _buildIdleView(state);
            }

            // Handle Detecting state (active detection)
            if (state is Detecting) {
              return _buildDetectingView(state);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF888888)),
          SizedBox(height: 24),
          Text(
            'Initializing...',
            style: TextStyle(color: Color(0xFF888888), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFF44336), size: 48),
            const SizedBox(height: 24),
            const Text(
              'Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => _bloc.add(InitializeEvent()),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF888888),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleView(CameraReady state) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview (clean, no overlays)
        CameraPreviewWidget(
          cameraController: state.cameraController,
          isFrontCamera:
              state.cameraController.description.lensDirection ==
              CameraLensDirection.front,
        ),

        // Bottom controls with Start button
        _buildIdleControls(state),
      ],
    );
  }

  Widget _buildDetectingView(Detecting state) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        CameraPreviewWidget(
          cameraController: state.cameraController,
          isFrontCamera: state.isFrontCamera,
        ),

        // Pose overlay (skeleton with connected landmarks)
        if (state.currentPose != null) _buildPoseOverlay(state),

        // Top metrics bar (live data)
        _buildMinimalTopBar(state),

        // Bottom controls with Stop button
        _buildDetectingControls(state),
      ],
    );
  }

  Widget _buildPoseOverlay(Detecting state) {
    final screenSize = MediaQuery.of(context).size;
    final pose = state.currentPose!;

    Widget overlay = SizedBox.expand(
      child: CustomPaint(
        painter: PosePainter(
          pose: pose,
          imageSize: pose.imageSize,
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
    final detection = state.personDetection;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Haupt-Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: detection.isPersonDetected
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF5252),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      detection.isPersonDetected ? Icons.person : Icons.person_off,
                      color: detection.isPersonDetected
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF5252),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      detection.isPersonDetected ? 'Person erkannt' : 'Keine Person',
                      style: TextStyle(
                        color: detection.isPersonDetected
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF5252),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Debug-Info Panel
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Größe & Proportionen
                    _buildDebugRow('Size', [
                      Text(
                        'SW:${detection.shoulderWidth.toStringAsFixed(0)} T:${detection.torsoLength.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: detection.minSizeOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                          fontSize: 11, fontFamily: 'monospace',
                        ),
                      ),
                      _debugCheck('min', detection.minSizeOk),
                      _debugCheck('ratio', detection.proportionsOk),
                    ]),
                    const SizedBox(height: 4),
                    // Geometrie
                    _buildDebugRow('Geo', [
                      _debugCheck('K>S', detection.headAboveShoulders),
                      _debugCheck('S>H', detection.shouldersAboveHips),
                    ]),
                    const SizedBox(height: 4),
                    // Symmetrie
                    _buildDebugRow('Sym', [
                      Text(
                        'S:${detection.shoulderSymmetry.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: detection.shoulderSymmetryOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                          fontSize: 11, fontFamily: 'monospace',
                        ),
                      ),
                      _debugCheck('', detection.shoulderSymmetryOk),
                      Text(
                        'H:${detection.hipSymmetry.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: detection.hipSymmetryOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                          fontSize: 11, fontFamily: 'monospace',
                        ),
                      ),
                      _debugCheck('', detection.hipSymmetryOk),
                    ]),
                    const SizedBox(height: 4),
                    // Nacken & Gesicht
                    _buildDebugRow('Head', [
                      Text(
                        'Neck:${detection.neckRatio.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: detection.neckOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                          fontSize: 11, fontFamily: 'monospace',
                        ),
                      ),
                      _debugCheck('', detection.neckOk),
                      Text(
                        'Face:${detection.facePartsDetected}/4',
                        style: TextStyle(
                          color: detection.faceOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                          fontSize: 11, fontFamily: 'monospace',
                        ),
                      ),
                      _debugCheck('', detection.faceOk),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, List<Widget> children) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _debugCheck(String label, bool ok) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty) ...[
            Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 10)),
            const SizedBox(width: 4),
          ],
          Icon(
            ok ? Icons.check : Icons.close,
            size: 12,
            color: ok ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM CONTROLS
  // ============================================================

  Widget _buildIdleControls(CameraReady state) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Camera switch button
              _buildCameraSwitchButton(
                state.cameraController.description.lensDirection ==
                    CameraLensDirection.front,
              ),

              // Start button
              _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetectingControls(Detecting state) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Camera switch button
              if (state.canSwitchCamera)
                _buildCameraSwitchButton(state.isFrontCamera),

              // Stop button
              _buildStopButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: () {
        _bloc.add(StartCaptureEvent());
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: () {
        _bloc.add(StopCaptureEvent());
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5252),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Icon(
          Icons.stop,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildCameraSwitchButton(bool isFrontCamera) {
    return GestureDetector(
      onTap: () {
        _bloc.add(SwitchCameraEvent());
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Icon(
          Icons.flip_camera_ios,
          color: Color(0xFF888888),
          size: 24,
        ),
      ),
    );
  }

}
