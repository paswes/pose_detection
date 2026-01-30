import 'package:flutter/material.dart';
import 'package:pose_detection/domain/models/squat_session.dart';
import 'package:pose_detection/presentation/widgets/squat_rep_card.dart';

/// Summary page shown after completing a squat session
class SquatSessionSummaryPage extends StatefulWidget {
  final SquatSession session;

  const SquatSessionSummaryPage({
    super.key,
    required this.session,
  });

  @override
  State<SquatSessionSummaryPage> createState() => _SquatSessionSummaryPageState();
}

class _SquatSessionSummaryPageState extends State<SquatSessionSummaryPage> {
  int? _expandedRepIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Session Complete',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero stats
            _buildHeroStats(),
            const SizedBox(height: 24),

            // Form breakdown
            _buildFormBreakdown(),
            const SizedBox(height: 24),

            // Session details
            _buildSessionDetails(),
            const SizedBox(height: 24),

            // Individual reps
            if (widget.session.completedReps.isNotEmpty) ...[
              _buildSectionHeader('Individual Reps'),
              const SizedBox(height: 12),
              ...widget.session.completedReps.asMap().entries.map((entry) {
                final index = entry.key;
                final rep = entry.value;
                return SquatRepCard(
                  rep: rep,
                  expanded: _expandedRepIndex == index,
                  onTap: () {
                    setState(() {
                      _expandedRepIndex =
                          _expandedRepIndex == index ? null : index;
                    });
                  },
                );
              }),
            ],

            const SizedBox(height: 32),

            // Action button
            _buildActionButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStats() {
    final session = widget.session;
    final formColor = _getFormColor(session.overallFormScore);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            formColor.withValues(alpha: 0.2),
            Colors.grey.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: formColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroStat(
                value: '${session.totalReps}',
                label: 'Reps',
                color: Colors.cyanAccent,
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              _buildHeroStat(
                value: '${(session.overallFormScore * 100).round()}%',
                label: 'Avg Form',
                color: formColor,
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              _buildHeroStat(
                value: _formatDuration(session.duration),
                label: 'Duration',
                color: Colors.white,
              ),
            ],
          ),
          if (session.bestRep != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Best Rep: #${session.bestRep!.repNumber} '
                    '(${(session.bestRep!.overallFormScore * 100).round()}%)',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroStat({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFormBreakdown() {
    if (widget.session.completedReps.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate average scores across all reps
    final reps = widget.session.completedReps;
    final avgKneeTracking =
        reps.map((r) => r.kneeTrackingScore).reduce((a, b) => a + b) / reps.length;
    final avgTrunk =
        reps.map((r) => r.trunkAngleScore).reduce((a, b) => a + b) / reps.length;
    final avgSymmetry =
        reps.map((r) => r.symmetryScore).reduce((a, b) => a + b) / reps.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Form Breakdown'),
          const SizedBox(height: 16),
          _buildScoreBar('Knee Tracking', avgKneeTracking, 0.4),
          const SizedBox(height: 12),
          _buildScoreBar('Trunk Angle', avgTrunk, 0.3),
          const SizedBox(height: 12),
          _buildScoreBar('Symmetry', avgSymmetry, 0.3),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, double score, double weight) {
    final color = _getFormColor(score);
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: score,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 45,
          child: Text(
            '${(score * 100).round()}%',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '(${(weight * 100).round()}%)',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionDetails() {
    final session = widget.session;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Session Details'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(
                'Avg Depth',
                '${session.averageDepth.round()}%',
                session.averageDepth >= 100
                    ? Colors.greenAccent
                    : Colors.yellowAccent,
              ),
              _buildDetailItem(
                'Parallel %',
                '${session.parallelPercentage.round()}%',
                session.parallelPercentage >= 80
                    ? Colors.greenAccent
                    : Colors.yellowAccent,
              ),
              _buildDetailItem(
                'Consistency',
                '${(session.consistencyScore * 100).round()}%',
                _getFormColor(session.consistencyScore),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(
                'Active Time',
                _formatDuration(session.totalActiveTime),
                Colors.cyanAccent,
              ),
              _buildDetailItem(
                'Avg Rep',
                session.averageRepDuration != null
                    ? '${(session.averageRepDuration!.inMilliseconds / 1000).toStringAsFixed(1)}s'
                    : '-',
                Colors.white70,
              ),
              _buildDetailItem(
                'Avg Rest',
                session.averageRestTime != null
                    ? '${(session.averageRestTime!.inMilliseconds / 1000).toStringAsFixed(1)}s'
                    : '-',
                Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Done',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  Color _getFormColor(double score) {
    if (score >= 0.8) return Colors.greenAccent;
    if (score >= 0.6) return Colors.yellowAccent;
    if (score >= 0.4) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
