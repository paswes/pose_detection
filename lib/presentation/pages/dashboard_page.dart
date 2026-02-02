import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/di/service_locator.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';
import 'package:pose_detection/presentation/pages/capture_page.dart';

/// Minimal dashboard - entry point to capture
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  late final PoseDetectionBloc _bloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Lock to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Get BLoC from service locator (DI)
    _bloc = sl<PoseDetectionBloc>();

    // Initialize camera
    _bloc.add(InitializeEvent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.add(DisposeEvent());
    _bloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bloc.add(InitializeEvent());
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
            if (state is CameraInitializing || state is PoseDetectionInitial) {
              return _buildLoadingView();
            }

            if (state is PoseDetectionError) {
              return _buildErrorView(state.message);
            }

            if (state is CameraReady || state is SessionSummary) {
              return _buildDashboard();
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

  Widget _buildDashboard() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Pose Engine',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Core Inspection Dashboard',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),

            const Spacer(),

            // Start capture button
            Center(
              child: GestureDetector(
                onTap: _startCapture,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E1E1E),
                    border: Border.all(
                      color: const Color(0xFF333333),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Color(0xFF888888),
                    size: 48,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Start Capture',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 14,
                ),
              ),
            ),

            const Spacer(),

            // Version info
            const Center(
              child: Text(
                'v1.0 · ML Kit · 33 Landmarks',
                style: TextStyle(
                  color: Color(0xFF444444),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startCapture() async {
    final navigator = Navigator.of(context);
    _bloc.add(StartCaptureEvent());
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      await navigator.push(
        MaterialPageRoute(
          builder: (context) => BlocProvider.value(
            value: _bloc,
            child: const CapturePage(),
          ),
        ),
      );
    }
  }
}
