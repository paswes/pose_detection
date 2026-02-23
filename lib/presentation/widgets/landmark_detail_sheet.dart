import 'package:flutter/material.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/data/models/landmark_data.dart';

/// Shows a bottom sheet with details for a single pose landmark.
///
/// Displays the landmark name, raw coordinates (x, y, z),
/// likelihood score, and connected landmarks.
void showLandmarkDetailSheet({
  required BuildContext context,
  required LandmarkData landmark,
  VoidCallback? onDismissed,
}) {
  final schema = sl<LandmarkSchema>();

  WoltModalSheet.show(
    context: context,
    pageListBuilder: (bottomSheetContext) => [
      _buildPage(bottomSheetContext, landmark, schema),
    ],
    modalBarrierColor: Colors.black54,
  ).whenComplete(() => onDismissed?.call());
}

SliverWoltModalSheetPage _buildPage(
  BuildContext context,
  LandmarkData landmark,
  LandmarkSchema schema,
) {
  final name = schema.getLandmarkName(landmark.id);
  final connections = _getConnectedLandmarks(landmark.id, schema);

  return SliverWoltModalSheetPage(
    backgroundColor: const Color(0xFF1E1E1E),
    surfaceTintColor: Colors.transparent,
    hasSabGradient: false,
    topBarTitle: Text(
      name,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    isTopBarLayerAlwaysVisible: true,
    trailingNavBarWidget: Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: const Icon(Icons.close, color: Color(0xFF888888)),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    mainContentSliversBuilder: (context) => [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        sliver: SliverList.list(
          children: [
            // Landmark ID
            Text(
              'ID: ${landmark.id}',
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 20),

            // Coordinates section
            const _SectionHeader(title: 'KOORDINATEN'),
            const SizedBox(height: 12),
            _InfoRow(label: 'X', value: landmark.x.toStringAsFixed(1)),
            const SizedBox(height: 8),
            _InfoRow(label: 'Y', value: landmark.y.toStringAsFixed(1)),
            const SizedBox(height: 8),
            _InfoRow(label: 'Z (Tiefe)', value: landmark.z.toStringAsFixed(1)),

            const SizedBox(height: 24),

            // Likelihood section
            const _SectionHeader(title: 'LIKELIHOOD'),
            const SizedBox(height: 12),
            _LikelihoodIndicator(likelihood: landmark.likelihood),

            if (connections.isNotEmpty) ...[
              const SizedBox(height: 24),

              // Connections section
              const _SectionHeader(title: 'VERBINDUNGEN'),
              const SizedBox(height: 12),
              ...connections.map(
                (name) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF666666),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

/// Returns names of landmarks connected to [landmarkId].
List<String> _getConnectedLandmarks(int landmarkId, LandmarkSchema schema) {
  final connectedIds = <int>{};
  for (final connection in schema.skeletonConnections) {
    if (connection[0] == landmarkId) {
      connectedIds.add(connection[1]);
    } else if (connection[1] == landmarkId) {
      connectedIds.add(connection[0]);
    }
  }
  return connectedIds.map((id) => schema.getLandmarkName(id)).toList();
}

// ── Private widgets ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF666666),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFFCCCCCC),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _LikelihoodIndicator extends StatelessWidget {
  final double likelihood;

  const _LikelihoodIndicator({required this.likelihood});

  @override
  Widget build(BuildContext context) {
    final percent = (likelihood * 100).toStringAsFixed(0);
    final color = _getLikelihoodColor(likelihood);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$percent%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          likelihood > 0.8
              ? 'Im Bild'
              : likelihood > 0.5
                  ? 'Teilweise'
                  : 'Unsicher',
          style: TextStyle(
            color: color,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Color _getLikelihoodColor(double likelihood) {
    if (likelihood > 0.8) return const Color(0xFF4CAF50);
    if (likelihood > 0.5) return const Color(0xFFFFEB3B);
    return const Color(0xFFF44336);
  }
}
