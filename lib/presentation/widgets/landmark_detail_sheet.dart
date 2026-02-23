import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import 'package:pose_detection/core/config/landmark_schema.dart';
import 'package:pose_detection/data/models/landmark_data.dart';

/// Shows a bottom sheet with details for a single pose landmark.
///
/// Displays the landmark name, raw coordinates (x, y, z),
/// and connected landmarks as tappable navigation links.
void showLandmarkDetailSheet({
  required BuildContext context,
  required LandmarkData landmark,
  required List<LandmarkData> allLandmarks,
  ValueChanged<int>? onLandmarkSelected,
  VoidCallback? onDismissed,
}) {
  final schema = LandmarkSchema.rdl;

  late final ValueNotifier<WoltModalSheetPageListBuilder> pageListNotifier;
  pageListNotifier = ValueNotifier<WoltModalSheetPageListBuilder>(
    (sheetContext) => [
      _buildPage(sheetContext, landmark, schema, allLandmarks, (id) {
        onLandmarkSelected?.call(id);
        final next = allLandmarks.firstWhere((l) => l.id == id);
        _updateNotifier(
          pageListNotifier,
          next,
          schema,
          allLandmarks,
          onLandmarkSelected,
        );
      }),
    ],
  );

  WoltModalSheet.showWithDynamicPath(
    context: context,
    pageListBuilderNotifier: pageListNotifier,
    modalBarrierColor: Colors.black54,
  ).whenComplete(() {
    pageListNotifier.dispose();
    onDismissed?.call();
  });
}

/// Recursive helper to keep navigations working at any depth.
void _updateNotifier(
  ValueNotifier<WoltModalSheetPageListBuilder> notifier,
  LandmarkData landmark,
  LandmarkSchema schema,
  List<LandmarkData> allLandmarks,
  ValueChanged<int>? onLandmarkSelected,
) {
  notifier.value = (ctx) => [
    _buildPage(ctx, landmark, schema, allLandmarks, (id) {
      onLandmarkSelected?.call(id);
      final next = allLandmarks.firstWhere((l) => l.id == id);
      _updateNotifier(notifier, next, schema, allLandmarks, onLandmarkSelected);
    }),
  ];
}

SliverWoltModalSheetPage _buildPage(
  BuildContext context,
  LandmarkData landmark,
  LandmarkSchema schema,
  List<LandmarkData> allLandmarks,
  ValueChanged<int> onConnectionTapped,
) {
  final name = schema.getLandmarkName(landmark.id);
  final connections = _getConnectedLandmarks(landmark.id, schema, allLandmarks);

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
            // Coordinates section
            const _SectionHeader(title: 'KOORDINATEN'),
            const SizedBox(height: 12),
            _InfoRow(label: 'X', value: landmark.x.toStringAsFixed(1)),
            const SizedBox(height: 8),
            _InfoRow(label: 'Y', value: landmark.y.toStringAsFixed(1)),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Z (Tiefe)',
              value: landmark.z.toStringAsFixed(1),
            ),

            if (connections.isNotEmpty) ...[
              const SizedBox(height: 24),

              // Connections section — tappable navigation
              const _SectionHeader(title: 'VERBINDUNGEN'),
              const SizedBox(height: 12),
              ...connections.map(
                (conn) => _ConnectionRow(
                  name: conn.name,
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

class _ConnectionRow extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _ConnectionRow({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
