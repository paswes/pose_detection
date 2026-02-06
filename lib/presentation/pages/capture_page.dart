import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
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
  bool _isPortrait = true;

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
    // Reset to allow all orientations on dispose
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isPortrait = !_isPortrait;
    });

    final newOrientation = _isPortrait
        ? DeviceOrientation.portraitUp
        : DeviceOrientation.landscapeLeft;

    // Update system orientation
    if (_isPortrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    // Trigger camera reinitialization via BLoC
    _bloc.add(ChangeOrientationEvent(newOrientation));
  }

  // DEBUG: Capture frame and save to gallery
  Future<void> _captureFrame(CameraController controller) async {
    try {
      final XFile file = await controller.takePicture();
      final bytes = await File(file.path).readAsBytes();

      // Decode image to get actual dimensions
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final int width = frame.image.width;
      final int height = frame.image.height;
      final bool isActuallyPortrait = height > width;

      final result = await ImageGallerySaver.saveImage(
        bytes,
        name:
            'pose_debug_${_isPortrait ? "portrait" : "landscape"}_${width}x$height',
      );

      // Log for debugging
      debugPrint('========================================');
      debugPrint('DEBUG CAPTURE:');
      debugPrint('  UI Mode: ${_isPortrait ? "PORTRAIT" : "LANDSCAPE"}');
      debugPrint('  Image Size: ${width}x$height');
      debugPrint(
        '  Actual Orientation: ${isActuallyPortrait ? "PORTRAIT" : "LANDSCAPE"}',
      );
      debugPrint(
        '  Match: ${_isPortrait == isActuallyPortrait ? "YES" : "NO !!!"}',
      );
      debugPrint('  Saved: $result');
      debugPrint('========================================');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${width}x$height (${isActuallyPortrait ? "Portrait" : "Landscape"}) ${_isPortrait == isActuallyPortrait ? "" : "MISMATCH!"}',
            ),
            backgroundColor: _isPortrait == isActuallyPortrait
                ? Colors.green
                : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('DEBUG: Failed to capture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
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
          isLandscape: !_isPortrait,
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
          isLandscape: !_isPortrait,
        ),

        // Pose overlay (skeleton) - only show when person is detected
        if (state.currentPose !=
            null /* && state.personDetection.isPersonDetected */ )
          _buildPoseOverlay(state),

        // Person-in-view indicator (small icon, top-left)
        _buildPersonIndicator(state),

        // Position guidance banner (only when person detected but not positioned)
        /*  if (state.personDetection.isPersonDetected) */ _buildPositionBanner(
          state,
        ),

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

  /// Small icon indicator for person-in-view status (top-left)
  Widget _buildPersonIndicator(Detecting state) {
    final isPersonDetected = state.personDetection.isPersonDetected;

    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPersonDetected ? Icons.person : Icons.person_off,
              color: isPersonDetected
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF5252),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  /// Position guidance banner (top-center, only when person detected)
  Widget _buildPositionBanner(Detecting state) {
    final isProperlyPositioned =
        state.positionValidation?.isProperlyPositioned ?? false;
    final guidanceMessages = state.positionValidation?.guidanceMessages ?? [];

    // Determine status color and text
    final Color statusColor;
    final String statusText;

    if (isProperlyPositioned) {
      statusColor = const Color(0xFF4CAF50); // Green
      statusText = 'Bereit';
    } else {
      statusColor = const Color(0xFFFFEB3B); // Yellow
      statusText = 'Position anpassen';
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor, width: 2),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Guidance messages (always show for debugging)
              if (guidanceMessages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: guidanceMessages
                          .map(
                            (msg) => Text(
                              msg,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          )
                          .toList(),
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
              // Left side controls
              Row(
                children: [
                  // Camera switch button
                  _buildCameraSwitchButton(
                    state.cameraController.description.lensDirection ==
                        CameraLensDirection.front,
                  ),
                  const SizedBox(width: 16),
                  // Orientation switch button
                  _buildOrientationSwitchButton(),
                  const SizedBox(width: 16),
                  // DEBUG: Capture button
                  _buildCaptureButton(state.cameraController),
                ],
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
              // Left side controls
              Row(
                children: [
                  // Camera switch button
                  if (state.canSwitchCamera)
                    _buildCameraSwitchButton(state.isFrontCamera),
                  if (state.canSwitchCamera) const SizedBox(width: 16),
                  // Orientation switch button
                  _buildOrientationSwitchButton(),
                  const SizedBox(width: 16),
                  // DEBUG: Capture button
                  _buildCaptureButton(state.cameraController),
                ],
              ),

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

  Widget _buildOrientationSwitchButton() {
    return GestureDetector(
      onTap: _toggleOrientation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Icon(
          _isPortrait
              ? Icons.stay_current_landscape
              : Icons.stay_current_portrait,
          color: const Color(0xFF888888),
          size: 24,
        ),
      ),
    );
  }

  // DEBUG: Capture button
  Widget _buildCaptureButton(CameraController controller) {
    return GestureDetector(
      onTap: () => _captureFrame(controller),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9800).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Icon(
          Icons.camera_alt,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
