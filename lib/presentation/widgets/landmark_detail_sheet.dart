import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/utils/rdl_rep_counter.dart';
import 'package:pose_detection/data/models/landmark_data.dart';
import 'package:pose_detection/data/models/tracked_frame.dart';

/// Shows a bottom sheet with details for a single pose landmark.
///
/// Displays RDL biomechanical metrics (hip angle, knee angle, torso lean),
/// the selected landmark with a green indicator, injury toggle,
/// and connected landmarks as tappable navigation links.
void showLandmarkDetailSheet({
  required BuildContext context,
  required LandmarkData landmark,
  required List<LandmarkData> allLandmarks,
  TrackedFrame? frame,
  Set<int> injuredLandmarkIds = const {},
  ValueChanged<int>? onLandmarkSelected,
  ValueChanged<int>? onInjuryToggled,
  VoidCallback? onDismissed,
}) {
  final schema = LandmarkSchema.rdl;

  // Local mutable copy so the sheet can react to toggles immediately.
  final injuredIds = ValueNotifier<Set<int>>(Set<int>.from(injuredLandmarkIds));

  late final ValueNotifier<WoltModalSheetPageListBuilder> pageListNotifier;

  void rebuildPage(LandmarkData current) {
    pageListNotifier.value = (ctx) => [
      _buildPage(
        ctx,
        current,
        schema,
        allLandmarks,
        frame,
        injuredIds.value,
        (id) {
          // Toggle locally + notify cubit
          final updated = Set<int>.from(injuredIds.value);
          if (updated.contains(id)) {
            updated.remove(id);
          } else {
            updated.add(id);
          }
          injuredIds.value = updated;
          onInjuryToggled?.call(id);
          rebuildPage(current);
        },
        (id) {
          onLandmarkSelected?.call(id);
          final next = allLandmarks.firstWhere((l) => l.id == id);
          rebuildPage(next);
        },
      ),
    ];
  }

  pageListNotifier = ValueNotifier<WoltModalSheetPageListBuilder>(
    (_) => [], // placeholder, overwritten immediately
  );
  rebuildPage(landmark);

  WoltModalSheet.showWithDynamicPath(
    context: context,
    pageListBuilderNotifier: pageListNotifier,
    modalBarrierColor: Colors.black54,
  ).whenComplete(() {
    pageListNotifier.dispose();
    injuredIds.dispose();
    onDismissed?.call();
  });
}

SliverWoltModalSheetPage _buildPage(
  BuildContext context,
  LandmarkData landmark,
  LandmarkSchema schema,
  List<LandmarkData> allLandmarks,
  TrackedFrame? frame,
  Set<int> injuredLandmarkIds,
  ValueChanged<int> onInjuryToggled,
  ValueChanged<int> onConnectionTapped,
) {
  final name = schema.getLandmarkName(landmark.id);
  final connections = _getConnectedLandmarks(landmark.id, schema, allLandmarks);
  final metrics = frame != null ? _computeMetrics(frame) : <_MetricInfo>[];
  final isInjured = injuredLandmarkIds.contains(landmark.id);

  return SliverWoltModalSheetPage(
    backgroundColor: const Color(0xFF1E1E1E),
    surfaceTintColor: Colors.transparent,
    hasSabGradient: false,
    hasTopBarLayer: false,
    mainContentSliversBuilder: (context) => [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
        sliver: SliverList.list(
          children: [
            // Metrics section
            Row(
              spacing: 8,
              children: [
                for (final m in metrics)
                  _MetricBox(
                    label: m.label,
                    value: m.value != null
                        ? '${m.value!.toStringAsFixed(1)}°'
                        : '–',
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Selected landmark with green indicator + injury toggle
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isInjured
                        ? const Color(0xFFF44336)
                        : const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onInjuryToggled(landmark.id);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isInjured
                          ? const Color(0xFFF44336).withValues(alpha: 0.15)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Schmerz',
                      style: TextStyle(
                        color: isInjured
                            ? const Color(0xFFF44336)
                            : const Color(0xFF666666),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (connections.isNotEmpty) ...[
              const SizedBox(height: 16),
              // Connections section — tappable navigation
              ...connections.map(
                (conn) => _ConnectionRow(
                  name: conn.name,
                  isInjured: injuredLandmarkIds.contains(conn.id),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onConnectionTapped(conn.id);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

/// A single metric to display in the detail sheet.
typedef _MetricInfo = ({String label, double? value});

/// Compute the 3 RDL biomechanical metrics for the current frame.
List<_MetricInfo> _computeMetrics(TrackedFrame frame) {
  // Hip angle (bilateral center)
  final hipAngle = RdlRepCounter.calculateHipAngle(frame);

  // Knee angle (average of both sides, or whichever is available)
  final leftKnee = RdlRepCounter.calculateKneeAngle(frame, left: true);
  final rightKnee = RdlRepCounter.calculateKneeAngle(frame, left: false);
  final double? kneeAngle;
  if (leftKnee != null && rightKnee != null) {
    kneeAngle = (leftKnee + rightKnee) / 2;
  } else {
    kneeAngle = leftKnee ?? rightKnee;
  }

  // Torso lean angle
  final torsoLean = RdlRepCounter.calculateTorsoLean(frame);

  return [
    (label: 'Hüftwinkel', value: hipAngle),
    (label: 'Kniewinkel', value: kneeAngle),
    (label: 'Oberkörper', value: torsoLean),
  ];
}

/// Connected landmark with ID and display name.
typedef _Connection = ({int id, String name});

/// Returns connected landmarks that are present in the current frame.
List<_Connection> _getConnectedLandmarks(
  int landmarkId,
  LandmarkSchema schema,
  List<LandmarkData> allLandmarks,
) {
  final presentIds = {for (final l in allLandmarks) l.id};
  final connectedIds = <int>{};
  for (final connection in schema.skeletonConnections) {
    if (connection[0] == landmarkId && presentIds.contains(connection[1])) {
      connectedIds.add(connection[1]);
    } else if (connection[1] == landmarkId &&
        presentIds.contains(connection[0])) {
      connectedIds.add(connection[0]);
    }
  }
  return connectedIds
      .map((id) => (id: id, name: schema.getLandmarkName(id)))
      .toList();
}

// -- Private widgets ---------------------------------------------------------

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBox({required this.label, required this.value});

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
              label,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  final String name;
  final bool isInjured;
  final VoidCallback onTap;

  const _ConnectionRow({
    required this.name,
    this.isInjured = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isInjured
                    ? const Color(0xFFF44336)
                    : const Color(0xFF666666),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: const Color(0xFFCCCCCC),
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF666666),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
