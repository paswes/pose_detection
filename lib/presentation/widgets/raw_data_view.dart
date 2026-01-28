import 'package:flutter/material.dart';
import 'package:pose_detection/domain/models/motion_data.dart';

/// Widget to display raw landmark data in a structured format
class RawDataView extends StatelessWidget {
  final TimestampedPose? pose;

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
          // Header with temporal metadata
          _buildHeader(),
          const SizedBox(height: 16),

          // Table header
          _buildTableHeader(),
          const SizedBox(height: 8),

          // Landmark list
          Expanded(
            child: ListView.builder(
              itemCount: pose!.landmarks.length,
              itemBuilder: (context, index) {
                final landmark = pose!.landmarks[index];
                return _buildLandmarkRow(index, landmark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Motion Data Stream',
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
                '${pose!.landmarks.length} pts',
                style: const TextStyle(
                  color: Colors.cyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Temporal metadata
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 1),
          ),
          child: Column(
            children: [
              _buildMetadataRow('Frame Index', '#${pose!.frameIndex}'),
              _buildMetadataRow('Timestamp', '${pose!.timestampMicros} μs'),
              _buildMetadataRow('Image Size', '${pose!.imageWidth.toInt()} × ${pose!.imageHeight.toInt()}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
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

  Widget _buildLandmarkRow(int index, RawLandmark landmark) {
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
              '${landmark.id}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _getLandmarkName(landmark.id),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              landmark.x.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              landmark.y.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              landmark.z.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              landmark.likelihood.toStringAsFixed(4),
              style: TextStyle(
                color: landmark.likelihood > 0.7
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
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

  String _getLandmarkName(int id) {
    // Standard 33 pose landmark names
    const landmarkNames = [
      'Nose', 'Left Eye Inner', 'Left Eye', 'Left Eye Outer',
      'Right Eye Inner', 'Right Eye', 'Right Eye Outer', 'Left Ear', 'Right Ear',
      'Mouth Left', 'Mouth Right', 'Left Shoulder', 'Right Shoulder',
      'Left Elbow', 'Right Elbow', 'Left Wrist', 'Right Wrist',
      'Left Pinky', 'Right Pinky', 'Left Index', 'Right Index',
      'Left Thumb', 'Right Thumb', 'Left Hip', 'Right Hip',
      'Left Knee', 'Right Knee', 'Left Ankle', 'Right Ankle',
      'Left Heel', 'Right Heel', 'Left Foot Index', 'Right Foot Index',
    ];
    return id < landmarkNames.length ? landmarkNames[id] : 'Unknown $id';
  }
}
