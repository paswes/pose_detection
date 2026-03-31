import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pose_detection/rdl_example/domain/rdl_rep_counter.dart';
import 'package:pose_detection/core/data/models/session.dart';

/// Displays per-rep analytics for an RDL session.
///
/// Shows a set summary at the top followed by individual rep cards.
/// Tapping a rep card returns the rep's [startFrameIndex] as the
/// navigation result so the caller can seek to that frame.
class RdlAnalyticsPage extends StatelessWidget {
  final Session session;
  final List<RdlRepData> reps;

  const RdlAnalyticsPage({
    super.key,
    required this.session,
    required this.reps,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Analyse',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
              itemCount: reps.length + 1, // +1 for summary
              itemBuilder: (context, index) {
                if (index == 0) return _SetSummary(reps: reps);
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _RepCard(
                    rep: reps[index - 1],
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, reps[index - 1].startFrameIndex);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SetSummary extends StatelessWidget {
  final List<RdlRepData> reps;

  const _SetSummary({required this.reps});

  @override
  Widget build(BuildContext context) {
    final avgMinAngle = reps.isEmpty
        ? 0.0
        : reps.map((r) => r.minHipAngle).reduce((a, b) => a + b) / reps.length;
    final avgDescentSec = reps.isEmpty
        ? 0.0
        : reps
                  .map((r) => r.descentDuration.inMilliseconds)
                  .reduce((a, b) => a + b) /
              reps.length /
              1000;
    final avgTotalSec = reps.isEmpty
        ? 0.0
        : reps
                  .map((r) => r.totalDuration.inMilliseconds)
                  .reduce((a, b) => a + b) /
              reps.length /
              1000;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ZUSAMMENFASSUNG',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            spacing: 8,
            children: [
              _SummaryBox(
                label: 'Reps',
                value: '${reps.length}',
              ),
              _SummaryBox(
                label: 'Ø Tiefe',
                value: '${avgMinAngle.toStringAsFixed(0)}°',
              ),
              _SummaryBox(
                label: 'Ø Abstieg',
                value: '${avgDescentSec.toStringAsFixed(1)}s',
              ),
              _SummaryBox(
                label: 'Ø Dauer',
                value: '${avgTotalSec.toStringAsFixed(1)}s',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          spacing: 4,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepCard extends StatelessWidget {
  final RdlRepData rep;
  final VoidCallback onTap;

  const _RepCard({required this.rep, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final descentSec = rep.descentDuration.inMilliseconds / 1000;
    final totalSec = rep.totalDuration.inMilliseconds / 1000;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Rep ${rep.repNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFF555555),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              spacing: 8,
              children: [
                _MetricBox(
                  label: 'Tiefe',
                  value: '${rep.minHipAngle.toStringAsFixed(0)}°',
                  color: _depthColor(rep.minHipAngle),
                ),
                _MetricBox(
                  label: 'Abstieg',
                  value: '${descentSec.toStringAsFixed(1)}s',
                ),
                _MetricBox(
                  label: 'Dauer',
                  value: '${totalSec.toStringAsFixed(1)}s',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              spacing: 8,
              children: [
                _MetricBox(
                  label: 'L Hüfte',
                  value: _formatAngle(rep.leftHipAngle),
                ),
                _MetricBox(
                  label: 'R Hüfte',
                  value: _formatAngle(rep.rightHipAngle),
                ),
                _MetricBox(
                  label: 'Δ Hüfte',
                  value: rep.hipAsymmetry != null
                      ? '${rep.hipAsymmetry!.toStringAsFixed(0)}°'
                      : '–',
                  color: _asymmetryColor(rep.hipAsymmetry),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              spacing: 8,
              children: [
                _MetricBox(
                  label: 'L Knie',
                  value: _formatAngle(rep.leftKneeAngle),
                ),
                _MetricBox(
                  label: 'R Knie',
                  value: _formatAngle(rep.rightKneeAngle),
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAngle(double? angle) {
    if (angle == null) return '–';
    return '${angle.toStringAsFixed(0)}°';
  }

  /// Green for good depth (< 90°), yellow for moderate, red for shallow.
  Color _depthColor(double angle) {
    if (angle < 90) return const Color(0xFF4CAF50);
    if (angle < 100) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }

  /// Green for low asymmetry, yellow for moderate, red for high.
  Color? _asymmetryColor(double? asymmetry) {
    if (asymmetry == null) return null;
    if (asymmetry < 5) return const Color(0xFF4CAF50);
    if (asymmetry < 10) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MetricBox({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          spacing: 2,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
