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
  int _selectedTabIndex = 0; // 0 = Overview, 1 = Raw Data

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final hasPoses = session.capturedPoses.isNotEmpty;
    final currentPose = hasPoses
        ? session.capturedPoses[_currentPoseIndex]
        : null;

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
            // Tab selector
            _buildTabSelector(),

            const SizedBox(height: 16),

            // Content based on selected tab
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildOverviewTab(minutes, seconds, session)
                  : _buildRawDataTab(hasPoses, currentPose, session),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              index: 0,
              icon: Icons.dashboard,
              label: 'Overview',
            ),
          ),
          Expanded(
            child: _buildTab(
              index: 1,
              icon: Icons.data_array,
              label: 'Raw Data',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyan.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.cyan : Colors.white60,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.cyan : Colors.white60,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(int minutes, int seconds, PoseSession session) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Session stats header
          _buildSessionHeader(minutes, seconds, session),

          const SizedBox(height: 16),

          // Info cards
          _buildInfoCards(session),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRawDataTab(
    bool hasPoses,
    dynamic currentPose,
    PoseSession session,
  ) {
    if (!hasPoses) {
      return _buildNoPosesMessage();
    }

    return Column(
      children: [
        // Pose navigator
        _buildPoseNavigator(session.capturedPoses.length),

        const SizedBox(height: 16),

        // Full-height raw data view
        Expanded(
          child: Container(
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
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoCards(PoseSession session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildInfoCard(
            icon: Icons.analytics,
            title: 'Motion Data Quality',
            children: [
              _buildInfoRow(
                'Total Poses Captured',
                '${session.capturedPoses.length}',
                Colors.cyan,
              ),
              _buildInfoRow(
                'Landmarks per Pose',
                '33 points (3D)',
                Colors.white70,
              ),
              _buildInfoRow(
                'Coordinate Systems',
                'Raw + Normalized',
                Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.timeline,
            title: 'Temporal Resolution',
            children: [
              _buildInfoRow(
                'Frame Indexing',
                'Sequential',
                Colors.cyan,
              ),
              _buildInfoRow(
                'Timestamp Precision',
                'Microseconds',
                Colors.white70,
              ),
              _buildInfoRow(
                'Effective FPS',
                session.effectiveFps.toStringAsFixed(2),
                Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.cyan, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHeader(int minutes, int seconds, PoseSession session) {
    final metrics = session.metrics;

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
                icon: Icons.accessibility_new,
                label: 'Poses',
                value: '${session.capturedPoses.length}',
              ),
              _buildStatColumn(
                icon: Icons.speed,
                label: 'FPS',
                value: session.effectiveFps.toStringAsFixed(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Pipeline metrics
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pipeline Metrics',
                  style: TextStyle(
                    color: Colors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricItem(
                      'Received',
                      '${metrics.totalFramesReceived}',
                    ),
                    _buildMetricItem(
                      'Processed',
                      '${metrics.totalFramesProcessed}',
                    ),
                    _buildMetricItem(
                      'Dropped',
                      '${metrics.totalFramesDropped}',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricItem(
                      'Drop Rate',
                      '${metrics.dropRate.toStringAsFixed(1)}%',
                    ),
                    _buildMetricItem(
                      'Avg Latency',
                      '${metrics.averageLatencyMs.toStringAsFixed(1)} ms',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
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
