import 'package:flutter/material.dart' hide Velocity;
import 'package:pose_detection/domain/models/landmark_type.dart';
import 'package:pose_detection/domain/motion/models/velocity.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';
import 'package:pose_detection/presentation/widgets/playground/visualizations/velocity_indicator.dart';

/// Section displaying landmark velocities.
class VelocitiesSection extends StatelessWidget {
  final Map<int, Velocity> velocities;
  final bool showAllVelocities;
  final bool isStationary;
  final double averageSpeed;

  const VelocitiesSection({
    super.key,
    required this.velocities,
    required this.showAllVelocities,
    required this.isStationary,
    required this.averageSpeed,
  });

  /// Key landmarks to show when not showing all
  static const _keyLandmarks = [
    LandmarkType.leftWrist,
    LandmarkType.rightWrist,
    LandmarkType.leftAnkle,
    LandmarkType.rightAnkle,
    LandmarkType.nose,
  ];

  @override
  Widget build(BuildContext context) {
    final landmarksToShow = showAllVelocities
        ? LandmarkType.values
        : _keyLandmarks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Icon(Icons.speed, size: 14, color: PlaygroundTheme.textMuted),
            const SizedBox(width: PlaygroundTheme.spacingSm),
            Text(
              'VELOCITIES',
              style: PlaygroundTheme.headingStyle.copyWith(fontSize: 11),
            ),
            const Spacer(),
            Text(
              'Avg: ${averageSpeed.toInt()} px/s',
              style: PlaygroundTheme.labelStyle.copyWith(fontSize: 9),
            ),
          ],
        ),

        const SizedBox(height: PlaygroundTheme.spacingSm),

        // Body movement indicator
        BodyMovementIndicator(
          isStationary: isStationary,
          averageSpeed: averageSpeed,
        ),

        const SizedBox(height: PlaygroundTheme.spacingSm),

        // Velocity list
        ...landmarksToShow.map((landmark) {
          final velocity = velocities[landmark.id];
          return VelocityIndicator(
            label: _landmarkLabel(landmark),
            velocity: velocity,
          );
        }),
      ],
    );
  }

  String _landmarkLabel(LandmarkType landmark) {
    // Convert enum name to readable label
    final name = landmark.name;

    // Handle left/right prefix
    if (name.startsWith('left')) {
      return 'L ${_capitalize(name.substring(4))}';
    } else if (name.startsWith('right')) {
      return 'R ${_capitalize(name.substring(5))}';
    }

    return _capitalize(name);
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;

    // Split camelCase
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final char = s[i];
      if (i > 0 && char.toUpperCase() == char && char != char.toLowerCase()) {
        buffer.write(' ');
      }
      buffer.write(i == 0 ? char.toUpperCase() : char);
    }
    return buffer.toString();
  }
}
