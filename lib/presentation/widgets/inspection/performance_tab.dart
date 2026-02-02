import 'package:flutter/material.dart';
import 'package:pose_detection/domain/models/inspection_snapshot.dart';
import 'rolling_chart.dart';

/// Performance tab showing pipeline health metrics
class PerformanceTab extends StatelessWidget {
  final InspectionSnapshot snapshot;

  const PerformanceTab({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('PIPELINE HEALTH'),
          const SizedBox(height: 12),
          _buildFpsChart(),
          const SizedBox(height: 12),
          _buildLatencyChart(),
          const SizedBox(height: 20),
          _buildSectionHeader('FRAME STATISTICS'),
          const SizedBox(height: 12),
          _buildFrameStats(),
          const SizedBox(height: 20),
          _buildSectionHeader('SESSION'),
          const SizedBox(height: 12),
          _buildSessionInfo(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF666666),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildFpsChart() {
    final fps = snapshot.currentFps;
    final fpsColor = _getFpsColor(fps);

    return RollingChart(
      data: snapshot.fpsHistory,
      minValue: 0,
      maxValue: 35,
      lineColor: fpsColor,
      fillColor: fpsColor.withValues(alpha: 0.2),
      label: 'FPS',
      currentValueLabel: '${fps.toStringAsFixed(1)} FPS',
      thresholds: [
        const ChartThreshold(value: 25, color: Color(0xFF4CAF50)),
        const ChartThreshold(value: 15, color: Color(0xFFFFEB3B)),
      ],
    );
  }

  Widget _buildLatencyChart() {
    final latency = snapshot.currentLatency;
    final latencyColor = _getLatencyColor(latency);

    return RollingChart(
      data: snapshot.latencyHistory,
      minValue: 0,
      maxValue: 150,
      lineColor: latencyColor,
      fillColor: latencyColor.withValues(alpha: 0.2),
      label: 'End-to-End Latency',
      currentValueLabel: '${latency.toStringAsFixed(0)} ms',
      thresholds: [
        const ChartThreshold(value: 50, color: Color(0xFF4CAF50)),
        const ChartThreshold(value: 100, color: Color(0xFFFFEB3B)),
      ],
    );
  }

  Widget _buildFrameStats() {
    final metrics = snapshot.performanceMetrics;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Received',
            metrics.totalFramesReceived.toString(),
            Icons.input,
            const Color(0xFF64B5F6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Processed',
            metrics.totalFramesProcessed.toString(),
            Icons.check_circle_outline,
            const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfo() {
    final metrics = snapshot.performanceMetrics;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Duration', snapshot.durationFormatted),
          const SizedBox(height: 8),
          _buildInfoRow('Poses Detected', snapshot.totalPoses.toString()),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Drop Rate',
            '${snapshot.dropRate.toStringAsFixed(1)}%',
            valueColor: _getDropRateColor(snapshot.dropRate),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Detection Rate',
            '${snapshot.detectionRate.toStringAsFixed(1)}%',
            valueColor: _getDetectionRateColor(snapshot.detectionRate),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Avg ML Latency',
            '${metrics.averageLatencyMs.toStringAsFixed(1)} ms',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Dropped Frames',
            metrics.totalFramesDropped.toString(),
            valueColor: metrics.totalFramesDropped > 0
                ? const Color(0xFFFFEB3B)
                : const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Color _getFpsColor(double fps) {
    if (fps >= 25) return const Color(0xFF4CAF50);
    if (fps >= 15) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }

  Color _getLatencyColor(double latency) {
    if (latency <= 50) return const Color(0xFF4CAF50);
    if (latency <= 100) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }

  Color _getDropRateColor(double dropRate) {
    if (dropRate < 5) return const Color(0xFF4CAF50);
    if (dropRate < 15) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }

  Color _getDetectionRateColor(double detectionRate) {
    if (detectionRate >= 95) return const Color(0xFF4CAF50);
    if (detectionRate >= 80) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }
}
