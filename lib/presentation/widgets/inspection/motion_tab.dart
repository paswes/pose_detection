import 'package:flutter/material.dart';
import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/domain/models/inspection_snapshot.dart';
import 'body_region_view.dart';
import 'joint_angle_view.dart';
import 'landmark_detail_view.dart';
import 'rolling_chart.dart';

/// Motion tab showing pose quality and kinematics
class MotionTab extends StatelessWidget {
  final InspectionSnapshot snapshot;
  final int? selectedLandmarkId;
  final ValueChanged<int?>? onLandmarkSelected;

  const MotionTab({
    super.key,
    required this.snapshot,
    this.selectedLandmarkId,
    this.onLandmarkSelected,
  });

  @override
  Widget build(BuildContext context) {
    final motion = snapshot.motionMetrics;
    final pose = snapshot.currentPose;

    if (pose == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.accessibility_new,
              color: Color(0xFF333333),
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No pose detected',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Body Regions
          BodyRegionView(regions: motion.bodyRegions),
          const SizedBox(height: 16),

          // Joint Angles
          JointAngleView(angles: motion.jointAngles),
          const SizedBox(height: 16),

          // Velocity Summary
          _buildVelocitySection(),
          const SizedBox(height: 16),

          // Confidence Chart
          _buildConfidenceChart(),
          const SizedBox(height: 16),

          // Landmark Detail List
          _buildSectionHeader('LANDMARK DETAIL'),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: LandmarkDetailView(
              pose: pose,
              velocities: motion.velocities,
              selectedLandmarkId: selectedLandmarkId,
              onLandmarkSelected: onLandmarkSelected,
            ),
          ),
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

  Widget _buildVelocitySection() {
    final motion = snapshot.motionMetrics;
    final avgSpeed = motion.averageSpeed;
    final fastest = motion.fastestLandmark;
    final speedColor = _getSpeedColor(avgSpeed);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed, color: Color(0xFF666666), size: 16),
              SizedBox(width: 8),
              Text(
                'VELOCITY',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildVelocityCard(
                  'Avg Speed',
                  avgSpeed.toStringAsFixed(3),
                  motion.movementCategory.name.toUpperCase(),
                  speedColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVelocityCard(
                  'Fastest',
                  fastest != null ? fastest.speed.toStringAsFixed(3) : '-',
                  fastest != null
                      ? LandmarkSchema.mlKit33.getLandmarkName(fastest.landmarkId)
                      : 'N/A',
                  fastest != null
                      ? _getSpeedColor(fastest.speed)
                      : const Color(0xFF555555),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVelocityCard(
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 9,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceChart() {
    final confidence = snapshot.currentPose?.avgConfidence ?? 0;
    final confColor = _getConfidenceColor(confidence);

    return RollingChart(
      data: snapshot.confidenceHistory,
      minValue: 0,
      maxValue: 1,
      lineColor: confColor,
      fillColor: confColor.withValues(alpha: 0.2),
      label: 'Overall Confidence',
      currentValueLabel: confidence.toStringAsFixed(2),
      thresholds: [
        const ChartThreshold(value: 0.8, color: Color(0xFF4CAF50)),
        const ChartThreshold(value: 0.5, color: Color(0xFFFFEB3B)),
      ],
    );
  }

  Color _getSpeedColor(double speed) {
    if (speed < 0.1) return const Color(0xFF555555); // Stationary
    if (speed < 0.3) return const Color(0xFF4CAF50); // Slow
    if (speed < 0.7) return const Color(0xFFFFEB3B); // Moderate
    return const Color(0xFFF44336); // Fast
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return const Color(0xFF4CAF50);
    if (confidence > 0.5) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }
}
