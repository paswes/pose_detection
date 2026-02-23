import 'package:flutter/material.dart';

/// Color legend showing muscle status counts.
class AnatomyLegend extends StatelessWidget {
  final int trainedCount;
  final int complaintCount;
  final int weakCount;

  const AnatomyLegend({
    super.key,
    required this.trainedCount,
    required this.complaintCount,
    required this.weakCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LegendItem(
            color: const Color(0xFF4CAF50),
            label: 'Trainiert',
            count: trainedCount,
          ),
          _LegendItem(
            color: const Color(0xFFFF5252),
            label: 'Beschwerde',
            count: complaintCount,
          ),
          _LegendItem(
            color: const Color(0xFFFFEB3B),
            label: 'Schwach',
            count: weakCount,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
