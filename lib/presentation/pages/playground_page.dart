import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/config/pose_detection_config.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/core/interfaces/camera_service_interface.dart';
import 'package:pose_detection/core/interfaces/pose_detector_interface.dart';
import 'package:pose_detection/domain/motion/services/motion_analyzer.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_event.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_state.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';
import 'package:pose_detection/presentation/widgets/camera_preview_widget.dart';
import 'package:pose_detection/presentation/widgets/playground/playground_overlay.dart';
import 'package:pose_detection/presentation/widgets/pose_painter.dart';

/// Developer Playground page for exploring motion tracking capabilities.
///
/// Features:
/// - Real-time pose detection with skeleton overlay
/// - Motion analysis data visualization (angles, velocities, ROM)
/// - Dynamic configuration with presets and sliders
/// - Performance metrics display
class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage>
    with WidgetsBindingObserver {
  late final PlaygroundBloc _bloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Lock to portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Create bloc with dependencies
    _bloc = PlaygroundBloc(
      cameraService: sl<ICameraService>(),
      poseDetector: sl<IPoseDetector>(),
      initialPoseConfig: sl<PoseDetectionConfig>(),
      initialMotionConfig: sl<MotionAnalyzerConfig>(),
    );

    // Initialize
    _bloc.add(const InitializePlaygroundEvent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.add(const DisposePlaygroundEvent());
    _bloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_bloc.state.cameraController == null) {
        _bloc.add(const InitializePlaygroundEvent());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: PlaygroundTheme.background,
        body: BlocBuilder<PlaygroundBloc, PlaygroundState>(
          builder: (context, state) {
            if (state.isInitializing) {
              return _buildLoadingView();
            }

            if (state.hasError && !state.isRecoverable) {
              return _buildErrorView(state);
            }

            return _buildMainView(state);
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
          CircularProgressIndicator(
            color: PlaygroundTheme.accent,
          ),
          SizedBox(height: PlaygroundTheme.spacingLg),
          Text(
            'Initializing...',
            style: PlaygroundTheme.labelStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(PlaygroundState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PlaygroundTheme.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: PlaygroundTheme.error,
              size: 64,
            ),
            const SizedBox(height: PlaygroundTheme.spacingLg),
            Text(
              state.errorMessage ?? 'An error occurred',
              style: PlaygroundTheme.labelStyle.copyWith(
                color: PlaygroundTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PlaygroundTheme.spacingXl),
            ElevatedButton.icon(
              onPressed: () {
                _bloc.add(const InitializePlaygroundEvent());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PlaygroundTheme.accent,
                foregroundColor: PlaygroundTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView(PlaygroundState state) {
    final cameraController = state.cameraController;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview (base layer)
        if (cameraController != null && cameraController.value.isInitialized)
          CameraPreviewWidget(
            cameraController: cameraController,
            isFrontCamera: state.isFrontCamera,
          ),

        // Pose overlay
        if (state.currentPose != null && cameraController != null)
          LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: PosePainter(
                  pose: state.currentPose!,
                  imageSize: state.currentPose!.imageSize,
                  widgetSize: Size(constraints.maxWidth, constraints.maxHeight),
                  schema: sl<LandmarkSchema>(),
                ),
              );
            },
          ),

        // Playground overlay (controls, panels, metrics)
        const PlaygroundOverlay(),
      ],
    );
  }
}
