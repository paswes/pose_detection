import 'package:flutter/material.dart';
import 'package:pose_detection/domain/models/joint_angle.dart';

/// Displays joint angles in a horizontal scrollable list
class JointAngleView extends StatelessWidget {
  final List<JointAngle> angles;

  const JointAngleView({
    super.key,
    required this.angles,
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
                  Icon(Icons.rotate_right, color: Color(0xFF666666), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'JOINT ANGLES',
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
                '${angles.length}/10 valid',
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (angles.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No angles detected\n(low confidence)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: angles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _buildAngleCard(angles[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAngleCard(JointAngle angle) {
    final color = _getConfidenceColor(angle.confidence);

    return Container(
      width: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            angle.shortLabel,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 9,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${angle.angleDegrees.toStringAsFixed(1)}°',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: angle.confidence.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return const Color(0xFF4CAF50);
    if (confidence > 0.6) return const Color(0xFF8BC34A);
    if (confidence > 0.4) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }
}
