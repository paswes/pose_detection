import 'package:flutter/material.dart';
import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/domain/models/motion_data.dart';
import 'package:pose_detection/domain/models/landmark_velocity.dart';

/// Displays detailed landmark information in a scrollable list
class LandmarkDetailView extends StatelessWidget {
  final TimestampedPose pose;
  final List<LandmarkVelocity> velocities;
  final int? selectedLandmarkId;
  final ValueChanged<int?>? onLandmarkSelected;

  const LandmarkDetailView({
    super.key,
    required this.pose,
    required this.velocities,
    this.selectedLandmarkId,
    this.onLandmarkSelected,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: Color(0xFF666666), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'LANDMARKS',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Text(
                '${pose.landmarkCount} points',
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Header row
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 24, child: Text('#', style: _headerStyle)),
                Expanded(flex: 3, child: Text('Name', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Conf', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Speed', style: _headerStyle)),
              ],
            ),
          ),
          const Divider(color: Color(0xFF333333), height: 1),
          // Landmark list
          Expanded(
            child: ListView.builder(
              itemCount: pose.normalizedLandmarks.length,
              itemBuilder: (context, index) {
                final landmark = pose.normalizedLandmarks[index];
                final velocity = _getVelocity(index);
                final isSelected = selectedLandmarkId == index;

                return _buildLandmarkRow(
                  index: index,
                  landmark: landmark,
                  velocity: velocity,
                  isSelected: isSelected,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  LandmarkVelocity? _getVelocity(int landmarkId) {
    for (final v in velocities) {
      if (v.landmarkId == landmarkId) return v;
    }
    return null;
  }

  Widget _buildLandmarkRow({
    required int index,
    required NormalizedLandmark landmark,
    LandmarkVelocity? velocity,
    required bool isSelected,
  }) {
    final confColor = _getConfidenceColor(landmark.likelihood);
    final speedColor = velocity != null ? _getSpeedColor(velocity.speed) : const Color(0xFF555555);
    final name = LandmarkSchema.mlKit33.getLandmarkName(index);

    return GestureDetector(
      onTap: () {
        if (onLandmarkSelected != null) {
          onLandmarkSelected!(isSelected ? null : index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2A2A) : Colors.transparent,
          border: isSelected
              ? Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.5))
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                index.toString(),
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF888888),
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                landmark.likelihood.toStringAsFixed(2),
                style: TextStyle(
                  color: confColor,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                velocity != null ? velocity.speed.toStringAsFixed(2) : '-',
                style: TextStyle(
                  color: speedColor,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return const Color(0xFF4CAF50);
    if (confidence > 0.5) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }

  Color _getSpeedColor(double speed) {
    if (speed < 0.1) return const Color(0xFF555555); // Stationary
    if (speed < 0.3) return const Color(0xFF4CAF50); // Slow
    if (speed < 0.7) return const Color(0xFFFFEB3B); // Moderate
    return const Color(0xFFF44336); // Fast
  }

  static const _headerStyle = TextStyle(
    color: Color(0xFF555555),
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );
}
