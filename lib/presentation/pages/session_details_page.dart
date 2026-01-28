import 'package:flutter/material.dart';
import 'package:pose_detection/domain/models/pose_session.dart';
import 'package:pose_detection/presentation/widgets/raw_data_view.dart';

/// Details page showing captured poses from a completed session
class SessionDetailsPage extends StatefulWidget {
  final PoseSession session;

  const SessionDetailsPage({super.key, required this.session});

  @override
  State<SessionDetailsPage> createState() => _SessionDetailsPageState();
}

class _SessionDetailsPageState extends State<SessionDetailsPage> {
  int _currentPoseIndex = 0;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final hasPoses = session.capturedPoses.isNotEmpty;
    final currentPose = hasPoses ? session.capturedPoses[_currentPoseIndex] : null;

    final duration = session.duration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.cyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Session Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Session stats header
            _buildSessionHeader(minutes, seconds, session),

            const SizedBox(height: 16),

            // Pose navigator
            if (hasPoses) _buildPoseNavigator(session.capturedPoses.length),

            const SizedBox(height: 16),

            // Raw data view
            Expanded(
              child: hasPoses
                  ? Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.cyan.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: RawDataView(pose: currentPose),
                    )
                  : _buildNoPosesMessage(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionHeader(int minutes, int seconds, PoseSession session) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.cyan.withValues(alpha: 0.2),
            Colors.cyan.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
              SizedBox(width: 8),
              Text(
                'Session Completed',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn(
                icon: Icons.timer,
                label: 'Duration',
                value: '${minutes}m ${seconds}s',
              ),
              _buildStatColumn(
                icon: Icons.video_camera_back,
                label: 'Frames',
                value: '${session.totalFramesProcessed}',
              ),
              _buildStatColumn(
                icon: Icons.accessibility_new,
                label: 'Poses',
                value: '${session.capturedPoses.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.cyan, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
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

  Widget _buildPoseNavigator(int totalPoses) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.cyan),
            onPressed: _currentPoseIndex > 0
                ? () => setState(() => _currentPoseIndex--)
                : null,
          ),

          // Pose indicator
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Viewing Pose',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currentPoseIndex + 1} of $totalPoses',
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                // Progress indicator
                LinearProgressIndicator(
                  value: (_currentPoseIndex + 1) / totalPoses,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                ),
              ],
            ),
          ),

          // Next button
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.cyan),
            onPressed: _currentPoseIndex < totalPoses - 1
                ? () => setState(() => _currentPoseIndex++)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNoPosesMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white.withValues(alpha: 0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No poses captured in this session',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
