import 'package:flutter/material.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/session.dart';

/// Floating detail card shown when a landmark is tapped during playback.
///
/// Displays the landmark name, normalized 0-1 coordinates, Z depth,
/// likelihood with color indicator, and frame metadata.
class LandmarkDetailCard extends StatelessWidget {
  final LandmarkData landmark;
  final Session session;
  final int frameIndex;
  final int timestampMicros;
  final VoidCallback onDismiss;

  const LandmarkDetailCard({
    super.key,
    required this.landmark,
    required this.session,
    required this.frameIndex,
    required this.timestampMicros,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final schema = sl<LandmarkSchema>();
    final name = schema.getLandmarkName(landmark.id);

    // Normalized 0-1 coordinates
    final rawW = session.imageWidth;
    final rawH = session.imageHeight;
    final normX = rawW > 0 ? landmark.x / rawW : 0.0;
    final normY = rawH > 0 ? landmark.y / rawH : 0.0;

    final likelihoodColor = _getLikelihoodColor(landmark.likelihood);
    final timestampMs = timestampMicros / 1000.0;

    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: const Color(0xE6121212),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name + landmark ID
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: likelihoodColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '#${landmark.id}',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Coordinates
            _DetailRow(
              label: 'X',
              value: normX.toStringAsFixed(3),
            ),
            _DetailRow(
              label: 'Y',
              value: normY.toStringAsFixed(3),
            ),
            _DetailRow(
              label: 'Z',
              value: landmark.z.toStringAsFixed(1),
            ),
            const SizedBox(height: 4),
            // Likelihood
            _DetailRow(
              label: 'Confidence',
              value: '${(landmark.likelihood * 100).toStringAsFixed(1)}%',
              valueColor: likelihoodColor,
            ),
            const SizedBox(height: 4),
            // Frame info
            Text(
              'Frame $frameIndex  ·  ${timestampMs.toStringAsFixed(1)}ms',
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 10,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLikelihoodColor(double likelihood) {
    if (likelihood > 0.8) return const Color(0xFF4CAF50);
    if (likelihood > 0.5) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
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
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
