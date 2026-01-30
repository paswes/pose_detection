import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/core/services/camera_service.dart';
import 'package:pose_detection/core/services/pose_detection_service.dart';
import 'package:pose_detection/domain/models/pose_session.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_bloc.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_event.dart';
import 'package:pose_detection/presentation/bloc/pose_detection_state.dart';
import 'package:pose_detection/presentation/bloc/squat_analysis_bloc.dart';
import 'package:pose_detection/presentation/pages/capture_page.dart';
import 'package:pose_detection/presentation/pages/session_details_page.dart';
import 'package:pose_detection/presentation/pages/squat_capture_page.dart';

/// Main dashboard for the Pose Engine Core
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

    // Initialize BLoC
    _bloc = PoseDetectionBloc(
      cameraService: CameraService(),
      poseDetectionService: PoseDetectionService(),
    );

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
        backgroundColor: const Color(0xFF0A0E21),
        body: BlocBuilder<PoseDetectionBloc, PoseDetectionState>(
          builder: (context, state) {
            if (state is CameraInitializing || state is PoseDetectionInitial) {
              return _buildLoadingView();
            }

            if (state is PoseDetectionError) {
              return _buildErrorView(state.message);
            }

            if (state is CameraReady || state is SessionSummary) {
              final lastSession = state is CameraReady
                  ? state.lastSession
                  : (state as SessionSummary).session;

              return _buildDashboard(lastSession);
            }

            return const SizedBox.shrink();
          },
        ),
        floatingActionButton:
            BlocBuilder<PoseDetectionBloc, PoseDetectionState>(
              builder: (context, state) {
                if (state is CameraReady || state is SessionSummary) {
                  return FloatingActionButton(
                    onPressed: () async {
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
                    },
                    backgroundColor: Colors.cyan,
                    child: const Icon(Icons.play_arrow, size: 32),
                  );
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
          CircularProgressIndicator(color: Colors.cyan),
          SizedBox(height: 24),
          Text(
            'Initializing Pose Engine...',
            style: TextStyle(color: Colors.white70, fontSize: 18),
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
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 24),
            Text(
              'Error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _bloc.add(InitializeEvent()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(dynamic lastSession) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 40),

            // Last session stats (if available)
            // Squat session button
            _buildSquatSessionButton(),
            const SizedBox(height: 24),

            if (lastSession != null) ...[
              _buildLastSessionCard(lastSession),
              const SizedBox(height: 24),
            ] else ...[
              _buildEmptyStateCard(),
              const SizedBox(height: 24),
            ],

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pose Engine Core',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Generic Pose Detection System',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSquatSessionButton() {
    return GestureDetector(
      onTap: () => _startSquatSession(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.greenAccent.withValues(alpha: 0.2),
              Colors.cyanAccent.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.greenAccent.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: Colors.greenAccent,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Squat Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time form feedback & rep counting',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.greenAccent,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSquatSession() async {
    final navigator = Navigator.of(context);

    // Start pose detection
    _bloc.add(StartCaptureEvent());
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      // Navigate to squat capture page with both blocs
      await navigator.push(
        MaterialPageRoute(
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: _bloc),
              BlocProvider(
                create: (_) => SquatAnalysisBloc(poseDetectionBloc: _bloc),
              ),
            ],
            child: const SquatCapturePage(),
          ),
        ),
      );
    }
  }

  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: const Column(
        children: [
          Text(
            'No Session History',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start a new capture to begin tracking poses',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLastSessionCard(PoseSession session) {
    final duration = session.duration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final metrics = session.metrics;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SessionDetailsPage(session: session),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.cyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.cyan.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, color: Colors.cyan, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Last Session',
                      style: TextStyle(
                        color: Colors.cyan,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Tap indicator
                const Row(
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, color: Colors.cyan, size: 14),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Duration', '${minutes}m ${seconds}s'),
                _buildStatColumn('Poses', '${session.capturedPoses.length}'),
                _buildStatColumn(
                  'FPS',
                  session.effectiveFps.toStringAsFixed(1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Pipeline metrics
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildMetricRow(
                    'Processed',
                    '${metrics.totalFramesProcessed}',
                  ),
                  _buildMetricRow(
                    'Dropped',
                    '${metrics.totalFramesDropped} (${metrics.dropRate.toStringAsFixed(1)}%)',
                  ),
                  _buildMetricRow(
                    'Avg Latency',
                    '${metrics.averageLatencyMs.toStringAsFixed(1)} ms',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
