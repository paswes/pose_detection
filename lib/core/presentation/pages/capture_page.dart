import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/domain/models/detected_pose.dart';
import 'package:pose_detection/core/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/core/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/core/presentation/bloc/pose_detection_state.dart';
import 'package:pose_detection/core/presentation/widgets/camera_preview_widget.dart';
import 'package:pose_detection/core/presentation/widgets/pose_painter.dart';

/// Fullscreen camera capture page with pose overlay and recording.
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

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addObserver(this);

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

    if (_isPortrait) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    _bloc.add(ChangeOrientationEvent(newOrientation));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: BlocConsumer<PoseDetectionBloc, PoseDetectionState>(
          listener: (context, state) {
            if (state is RecordingStopped) {
              _showSaveSessionDialog();
            }
            if (state is SessionSaved) {
              Navigator.pop(context, true);
            }
          },
          builder: (context, state) {
            if (state is PoseDetectionInitial || state is CameraInitializing) {
              return _buildLoadingView();
            }
            if (state is PoseDetectionError) {
              return _buildErrorView(state.message);
            }
            if (state is CameraReady) {
              return _buildIdleView(state);
            }
            if (state is Recording) {
              return _buildRecordingView(state);
            }
            if (state is RecordingStopped || state is SavingSession) {
              return _buildSavingView();
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // ============================================================
  // VIEWS
  // ============================================================

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

  Widget _buildSavingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4CAF50)),
          SizedBox(height: 24),
          Text(
            'Saving session...',
            style: TextStyle(color: Color(0xFF888888), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleView(CameraReady state) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewWidget(
          cameraController: state.cameraController,
          isLandscape: !_isPortrait,
        ),
        _buildBackButton(),
        _buildIdleControls(state),
      ],
    );
  }

  Widget _buildRecordingView(Recording state) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewWidget(
          cameraController: state.cameraController,
          isLandscape: !_isPortrait,
        ),

        // Pose overlay
        if (state.currentPose != null && state.isPersonDetected)
          _buildPoseOverlayFromRecording(state),

        // Back button (top-left)
        _buildBackButton(),

        // Person indicator (top-right)
        _buildPersonIndicator(state.isPersonDetected),

        // Bottom: recording time (left) + stop button (right)
        _buildRecordingControls(state),
      ],
    );
  }

  // ============================================================
  // OVERLAYS & INDICATORS
  // ============================================================

  Widget _buildBackButton() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF888888),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoseOverlayFromRecording(Recording state) {
    return _buildPoseOverlay(
      state.currentPose!,
      state.isFrontCamera,
    );
  }

  Widget _buildPoseOverlay(DetectedPose pose, bool isFrontCamera) {
    final screenSize = MediaQuery.of(context).size;

    Widget overlay = SizedBox.expand(
      child: CustomPaint(
        painter: PosePainter(
          pose: pose,
          imageSize: pose.imageSize,
          widgetSize: screenSize,
        ),
      ),
    );

    if (isFrontCamera) {
      overlay = Transform.flip(flipX: true, child: overlay);
    }

    return overlay;
  }

  Widget _buildPersonIndicator(bool isPersonDetected) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPersonDetected
                  ? Icons.person_rounded
                  : Icons.person_off_rounded,
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

  // ============================================================
  // DIALOGS
  // ============================================================

  void _showSaveSessionDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Session speichern',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Session Name',
            hintStyle: TextStyle(color: Color(0xFF666666)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF444444)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4CAF50)),
            ),
          ),
          onSubmitted: (value) {
            Navigator.pop(context);
            final title = value.trim().isEmpty
                ? _defaultSessionTitle()
                : value.trim();
            _bloc.add(SaveSessionEvent(title: title));
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final title = controller.text.trim().isEmpty
                  ? _defaultSessionTitle()
                  : controller.text.trim();
              _bloc.add(SaveSessionEvent(title: title));
            },
            child: const Text(
              'Speichern',
              style: TextStyle(color: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }

  String _defaultSessionTitle() {
    final now = DateTime.now();
    return 'Session ${now.day}.${now.month}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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
              Row(
                children: [
                  _buildCameraSwitchButton(),
                  const SizedBox(width: 16),
                  _buildOrientationSwitchButton(),
                ],
              ),
              // Green play button — starts recording
              GestureDetector(
                onTap: () => _bloc.add(StartRecordingEvent()),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingControls(Recording state) {
    final duration = state.recordingDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Recording time indicator (replaces camera/orientation buttons)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5252),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              // Red stop button
              GestureDetector(
                onTap: () => _bloc.add(StopRecordingEvent()),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Icon(
                    Icons.stop_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSwitchButton() {
    return GestureDetector(
      onTap: () => _bloc.add(SwitchCameraEvent()),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Icon(
          Icons.flip_camera_ios_rounded,
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
              ? Icons.stay_current_landscape_rounded
              : Icons.stay_current_portrait_rounded,
          color: const Color(0xFF888888),
          size: 24,
        ),
      ),
    );
  }
}
