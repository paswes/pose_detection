import 'package:flutter/material.dart';
import 'package:pose_detection/domain/models/body_joint.dart';
import 'package:pose_detection/domain/motion/models/joint_angle.dart';
import 'package:pose_detection/domain/motion/models/range_of_motion.dart';
import 'package:pose_detection/domain/motion/services/range_of_motion_analyzer.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';
import 'package:pose_detection/presentation/widgets/playground/visualizations/rom_progress_bar.dart';

/// Section displaying Range of Motion tracking data.
class RomSection extends StatelessWidget {
  final Map<String, RangeOfMotion> romData;
  final Map<String, JointAngle> currentAngles;
  final Set<BodyJoint> displayJoints;
  final RomSummary? summary;

  const RomSection({
    super.key,
    required this.romData,
    required this.currentAngles,
    required this.displayJoints,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final meaningfulRom = romData.entries
        .where((e) => e.value.hasMeaningfulData)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Icon(Icons.straighten, size: 14, color: PlaygroundTheme.textMuted),
            const SizedBox(width: PlaygroundTheme.spacingSm),
            Text(
              'RANGE OF MOTION',
              style: PlaygroundTheme.headingStyle.copyWith(fontSize: 11),
            ),
          ],
        ),

        const SizedBox(height: PlaygroundTheme.spacingSm),

        // Summary card
        if (summary != null)
          RomSummaryCard(
            jointCount: summary!.jointCount,
            averageRom: summary!.averageRomDegrees,
            sessionDuration: summary!.durationSeconds,
            totalSamples: summary!.totalSamples,
          ),

        const SizedBox(height: PlaygroundTheme.spacingSm),

        // ROM progress bars for each joint
        if (meaningfulRom.isEmpty)
          _EmptyState()
        else
          ...displayJoints
              .where((j) => romData.containsKey(j.jointId))
              .map((joint) {
            return Padding(
              padding: const EdgeInsets.only(bottom: PlaygroundTheme.spacingSm),
              child: RomProgressBar(
                label: joint.displayName,
                rom: romData[joint.jointId],
                currentAngle: currentAngles[joint.jointId],
              ),
            );
          }),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PlaygroundTheme.spacingLg),
      decoration: PlaygroundTheme.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: PlaygroundTheme.textMuted,
            size: 24,
          ),
          const SizedBox(height: PlaygroundTheme.spacingSm),
          Text(
            'Start moving to track ROM',
            style: PlaygroundTheme.labelStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
