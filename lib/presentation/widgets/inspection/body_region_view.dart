import 'package:flutter/material.dart';
import 'package:pose_detection/domain/models/body_region.dart';

/// Displays body region breakdown with confidence bars
class BodyRegionView extends StatelessWidget {
  final BodyRegionBreakdown regions;

  const BodyRegionView({
    super.key,
    required this.regions,
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
          const Row(
            children: [
              Icon(Icons.accessibility_new, color: Color(0xFF666666), size: 16),
              SizedBox(width: 8),
              Text(
                'BODY REGIONS',
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
          _buildRegionBar(regions.head),
          const SizedBox(height: 8),
          _buildRegionBar(regions.upperBody),
          const SizedBox(height: 8),
          _buildRegionBar(regions.core),
          const SizedBox(height: 8),
          _buildRegionBar(regions.lowerBody),
          const SizedBox(height: 12),
          _buildOverallConfidence(),
        ],
      ),
    );
  }

  Widget _buildRegionBar(BodyRegion region) {
    final color = _getConfidenceColor(region.confidence);

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            region.name,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              // Background bar
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Filled bar
              FractionallySizedBox(
                widthFactor: region.confidence.clamp(0.0, 1.0),
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            region.confidence.toStringAsFixed(2),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallConfidence() {
    final overall = regions.overallConfidence;
    final color = _getConfidenceColor(overall);
    final weakest = regions.weakestRegion;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'Overall: ',
              style: TextStyle(color: Color(0xFF666666), fontSize: 11),
            ),
            Text(
              overall.toStringAsFixed(2),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text(
              'Weakest: ',
              style: TextStyle(color: Color(0xFF666666), fontSize: 11),
            ),
            Text(
              weakest.name,
              style: TextStyle(
                color: _getConfidenceColor(weakest.confidence),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return const Color(0xFF4CAF50); // Green
    if (confidence > 0.6) return const Color(0xFF8BC34A); // Light green
    if (confidence > 0.4) return const Color(0xFFFFEB3B); // Yellow
    return const Color(0xFFF44336); // Red
  }
}
