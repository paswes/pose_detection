import 'package:flutter/material.dart';
import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/di/service_locator.dart';
import 'package:pose_detection/domain/models/motion_data.dart';

/// Widget to display raw landmark data in a structured format
class RawDataView extends StatelessWidget {
  final TimestampedPose? pose;
  final LandmarkSchema _schema;

  RawDataView({super.key, this.pose}) : _schema = sl<LandmarkSchema>();

  String _getLandmarkName(int id) => _schema.getLandmarkName(id);

  @override
  Widget build(BuildContext context) {
    if (pose == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text(
            'No pose detected',
            style: TextStyle(color: Color(0xFF666666), fontSize: 14),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
                'Raw Landmark Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${pose!.landmarks.length} pts',
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  fontFamily: 'monospace',
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
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF333333), width: 1),
          ),
          child: Column(
            children: [
              _buildMetadataRow('Frame', '#${pose!.frameIndex}'),
              _buildMetadataRow('Timestamp', '${pose!.timestampMicros} μs'),
              _buildMetadataRow(
                'Image',
                '${pose!.imageWidth.toInt()} × ${pose!.imageHeight.toInt()}',
              ),
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
            style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#',
              style: TextStyle(
                color: Color(0xFF888888),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Landmark',
              style: TextStyle(
                color: Color(0xFF888888),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'X',
              style: TextStyle(
                color: Color(0xFF888888),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Y',
              style: TextStyle(
                color: Color(0xFF888888),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Z',
              style: TextStyle(
                color: Color(0xFF888888),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Conf',
              style: TextStyle(
                color: Color(0xFF888888),
                fontWeight: FontWeight.w600,
                fontSize: 10,
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
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: index.isEven
            ? const Color(0xFF1A1A1A)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${landmark.id}',
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _getLandmarkName(landmark.id),
              style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              landmark.x.toStringAsFixed(1),
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
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
                color: Color(0xFF888888),
                fontSize: 10,
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
                color: Color(0xFF888888),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              landmark.likelihood.toStringAsFixed(2),
              style: TextStyle(
                color: _getConfidenceColor(landmark.likelihood),
                fontSize: 10,
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

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return const Color(0xFF4CAF50);
    if (confidence > 0.5) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }
}
