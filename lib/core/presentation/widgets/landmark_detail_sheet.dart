import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/interfaces/exercise_analyzer.dart';
import 'package:pose_detection/core/domain/models/landmark.dart';
import 'package:pose_detection/core/data/models/tracked_frame.dart';

/// Shows a bottom sheet with details for a single pose landmark.
///
/// When an [ExerciseAnalyzer] is provided, displays exercise-specific
/// metrics (e.g. hip angle, knee angle). Otherwise shows landmark
/// details and connections only.
void showLandmarkDetailSheet({
  required BuildContext context,
  required Landmark landmark,
  required List<Landmark> allLandmarks,
  TrackedFrame? frame,
  ExerciseAnalyzer? analyzer,
  Set<int> injuredLandmarkIds = const {},
  ValueChanged<int>? onLandmarkSelected,
  ValueChanged<int>? onInjuryToggled,
  VoidCallback? onDismissed,
}) {
  final schema = analyzer?.schema ?? LandmarkSchema.mlKit33;

  // Local mutable copy so the sheet can react to toggles immediately.
  final injuredIds = ValueNotifier<Set<int>>(Set<int>.from(injuredLandmarkIds));

  late final ValueNotifier<WoltModalSheetPageListBuilder> pageListNotifier;

  void rebuildPage(Landmark current) {
    pageListNotifier.value = (ctx) => [
      _buildPage(
        ctx,
        current,
        schema,
        allLandmarks,
        frame,
        analyzer,
        injuredIds.value,
        (id) {
          // Toggle locally + notify caller
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
  Landmark landmark,
  LandmarkSchema schema,
  List<Landmark> allLandmarks,
  TrackedFrame? frame,
  ExerciseAnalyzer? analyzer,
  Set<int> injuredLandmarkIds,
  ValueChanged<int> onInjuryToggled,
  ValueChanged<int> onConnectionTapped,
) {
  final name = schema.getLandmarkName(landmark.id);
  final connections = _getConnectedLandmarks(landmark.id, schema, allLandmarks);
  final metrics = analyzer?.computeDetailMetrics(frame) ?? [];
  final isInjured = injuredLandmarkIds.contains(landmark.id);

  return SliverWoltModalSheetPage(
    backgroundColor: const Color(0xFF1E1E1E),
    surfaceTintColor: Colors.transparent,
    hasSabGradient: false,
    hasTopBarLayer: false,
    mainContentSliversBuilder: (context) => [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 48),
        sliver: SliverList.list(
          children: [
            // Exercise-specific metrics (if any)
            if (metrics.isNotEmpty) ...[
              Row(
                spacing: 8,
                children: [
                  for (final m in metrics)
                    _MetricBox(label: m.label, value: m.value),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Selected landmark with green/red indicator + injury toggle
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

/// Connected landmark with ID and display name.
typedef _Connection = ({int id, String name});

/// Returns connected landmarks that are present in the current frame.
List<_Connection> _getConnectedLandmarks(
  int landmarkId,
  LandmarkSchema schema,
  List<Landmark> allLandmarks,
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
                style: const TextStyle(
                  color: Color(0xFFCCCCCC),
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
