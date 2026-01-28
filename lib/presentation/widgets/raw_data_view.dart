import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Widget to display raw landmark data in a structured format
class RawDataView extends StatelessWidget {
  final Pose? pose;

  const RawDataView({super.key, this.pose});

  @override
  Widget build(BuildContext context) {
    if (pose == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(
          child: Text(
            'No pose detected',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Landmark Data (33 Points)',
                  style: TextStyle(
                    color: Colors.cyan,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${pose!.landmarks.length}',
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table header
          _buildTableHeader(),
          const SizedBox(height: 8),

          // Landmark list
          Expanded(
            child: ListView.builder(
              itemCount: PoseLandmarkType.values.length,
              itemBuilder: (context, index) {
                final type = PoseLandmarkType.values[index];
                final landmark = pose!.landmarks[type];

                if (landmark == null) {
                  return _buildLandmarkRow(
                    index,
                    _getLandmarkName(type),
                    null,
                  );
                }

                return _buildLandmarkRow(
                  index,
                  _getLandmarkName(type),
                  landmark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.cyan.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Landmark',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'X',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Y',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Z',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Conf',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandmarkRow(int index, String name, PoseLandmark? landmark) {
    final isDetected = landmark != null;
    final textColor = isDetected ? Colors.white70 : Colors.white30;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: index.isEven
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: TextStyle(color: textColor, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isDetected ? landmark.x.toStringAsFixed(1) : '-',
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isDetected ? landmark.y.toStringAsFixed(1) : '-',
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isDetected ? landmark.z.toStringAsFixed(1) : '-',
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isDetected ? landmark.likelihood.toStringAsFixed(4) : '-',
              style: TextStyle(
                color: isDetected
                    ? (landmark.likelihood > 0.7
                          ? Colors.greenAccent
                          : Colors.orangeAccent)
                    : textColor,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getLandmarkName(PoseLandmarkType type) {
    return type.name
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim();
  }
}
