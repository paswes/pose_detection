import 'package:flutter/material.dart';
import 'package:pose_detection/domain/models/squat_rep.dart';

/// Card widget displaying details of a single squat rep
class SquatRepCard extends StatelessWidget {
  /// The rep data to display
  final SquatRep rep;

  /// Whether this card is expanded (shows more details)
  final bool expanded;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  const SquatRepCard({
    super.key,
    required this.rep,
    this.expanded = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getFormColor(rep.overallFormScore).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            _buildMainContent(),
            if (expanded) _buildExpandedContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Rep number badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getFormColor(rep.overallFormScore).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${rep.repNumber}',
                style: TextStyle(
                  color: _getFormColor(rep.overallFormScore),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Rep details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${(rep.overallFormScore * 100).round()}%',
                      style: TextStyle(
                        color: _getFormColor(rep.overallFormScore),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getFormColor(rep.overallFormScore).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        rep.formGrade,
                        style: TextStyle(
                          color: _getFormColor(rep.overallFormScore),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildMiniStat(
                      Icons.height,
                      rep.depthDescription,
                      _getDepthColor(rep.depthPercentage),
                    ),
                    const SizedBox(width: 12),
                    _buildMiniStat(
                      Icons.timer,
                      '${(rep.totalDuration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                      Colors.white70,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chevron
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.white38,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 8),

          // Form scores breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildScorePill(
                'Knees',
                rep.kneeTrackingScore,
                Icons.accessibility_new,
              ),
              _buildScorePill(
                'Trunk',
                rep.trunkAngleScore,
                Icons.straighten,
              ),
              _buildScorePill(
                'Symmetry',
                rep.symmetryScore,
                Icons.balance,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Phase timing
          Row(
            children: [
              Expanded(
                child: _buildTimingBar(
                  'Down',
                  rep.descentDuration,
                  rep.totalDuration,
                  Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimingBar(
                  'Hold',
                  rep.bottomDuration,
                  rep.totalDuration,
                  Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimingBar(
                  'Up',
                  rep.ascentDuration,
                  rep.totalDuration,
                  Colors.cyanAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Raw data
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lowest: ${rep.lowestKneeAngle.toStringAsFixed(0)}°',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                'Trunk: ${rep.maxTrunkAngle.toStringAsFixed(0)}°',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                'Valgus: ${rep.avgKneeValgusAngle.toStringAsFixed(1)}°',
                style: TextStyle(
                  color: rep.avgKneeValgusAngle.abs() > 5
                      ? Colors.orangeAccent
                      : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildScorePill(String label, double score, IconData icon) {
    final color = _getFormColor(score);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                '${(score * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildTimingBar(
    String label,
    Duration duration,
    Duration total,
    Color color,
  ) {
    final fraction = total.inMicroseconds > 0
        ? duration.inMicroseconds / total.inMicroseconds
        : 0.0;
    final ms = duration.inMilliseconds;

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${ms}ms',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getFormColor(double score) {
    if (score >= 0.8) return Colors.greenAccent;
    if (score >= 0.6) return Colors.yellowAccent;
    if (score >= 0.4) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Color _getDepthColor(double percentage) {
    if (percentage >= 100) return Colors.greenAccent;
    if (percentage >= 80) return Colors.lightGreenAccent;
    if (percentage >= 50) return Colors.yellowAccent;
    return Colors.orangeAccent;
  }
}
