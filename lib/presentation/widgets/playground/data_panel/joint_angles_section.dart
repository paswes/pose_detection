import 'package:flutter/material.dart';
import 'package:pose_detection/domain/models/body_joint.dart';
import 'package:pose_detection/domain/motion/models/joint_angle.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';
import 'package:pose_detection/presentation/widgets/playground/visualizations/angle_gauge.dart';

/// Section displaying joint angles in a grid layout.
class JointAnglesSection extends StatelessWidget {
  final Map<String, JointAngle> angles;
  final Set<BodyJoint> displayJoints;

  const JointAnglesSection({
    super.key,
    required this.angles,
    required this.displayJoints,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        const _SectionHeader(
          title: 'JOINT ANGLES',
          icon: Icons.rotate_right,
        ),

        const SizedBox(height: PlaygroundTheme.spacingSm),

        // Paired joints grid
        ...BodyJoint.pairedJoints.map((pair) {
          final showLeft = displayJoints.contains(pair.$1);
          final showRight = displayJoints.contains(pair.$2);

          if (!showLeft && !showRight) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: PlaygroundTheme.spacingSm),
            child: Row(
              children: [
                if (showLeft)
                  Expanded(
                    child: AngleGauge(
                      label: _shortLabel(pair.$1),
                      angle: angles[pair.$1.jointId],
                      size: 50,
                    ),
                  ),
                if (showLeft && showRight)
                  const SizedBox(width: PlaygroundTheme.spacingSm),
                if (showRight)
                  Expanded(
                    child: AngleGauge(
                      label: _shortLabel(pair.$2),
                      angle: angles[pair.$2.jointId],
                      size: 50,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _shortLabel(BodyJoint joint) {
    // Extract short name: "leftElbow" -> "L Elbow"
    final name = joint.name;
    if (name.startsWith('left')) {
      return 'L ${_capitalize(name.substring(4))}';
    } else if (name.startsWith('right')) {
      return 'R ${_capitalize(name.substring(5))}';
    }
    return _capitalize(name);
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

/// Compact list view for angles (alternative display)
class JointAnglesListSection extends StatelessWidget {
  final Map<String, JointAngle> angles;
  final Set<BodyJoint> displayJoints;

  const JointAnglesListSection({
    super.key,
    required this.angles,
    required this.displayJoints,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'JOINT ANGLES',
          icon: Icons.rotate_right,
        ),
        const SizedBox(height: PlaygroundTheme.spacingSm),
        ...displayJoints.map((joint) {
          return AngleListItem(
            label: joint.displayName,
            angle: angles[joint.jointId],
          );
        }),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: PlaygroundTheme.textMuted),
        const SizedBox(width: PlaygroundTheme.spacingSm),
        Text(title, style: PlaygroundTheme.headingStyle.copyWith(fontSize: 11)),
      ],
    );
  }
}
