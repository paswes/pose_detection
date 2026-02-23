import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';
import 'package:pose_detection/features/anatomy/presentation/data/muscle_path_data.dart';
import 'package:pose_detection/features/anatomy/presentation/widgets/anatomy_body_painter.dart';

/// Interactive body view with tappable muscle regions.
///
/// Handles gesture detection, hit-testing against muscle paths,
/// and delegates selection to the parent via [onMuscleSelected].
class AnatomyBodyView extends StatelessWidget {
  final List<MuscleGroup> muscles;
  final BodyView currentView;
  final String? selectedMuscleId;
  final ValueChanged<String> onMuscleSelected;

  const AnatomyBodyView({
    super.key,
    required this.muscles,
    required this.currentView,
    this.selectedMuscleId,
    required this.onMuscleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Body aspect ratio ~0.45 width-to-height
        final maxHeight = constraints.maxHeight;
        final maxWidth = constraints.maxWidth;
        final bodyWidth = (maxHeight * 0.45).clamp(0.0, maxWidth * 0.9);
        final bodyHeight = maxHeight;

        return Center(
          child: SizedBox(
            width: bodyWidth,
            height: bodyHeight,
            child: GestureDetector(
              onTapDown: (details) =>
                  _handleTap(details, Size(bodyWidth, bodyHeight)),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: CustomPaint(
                  key: ValueKey(currentView),
                  size: Size(bodyWidth, bodyHeight),
                  painter: AnatomyBodyPainter(
                    muscles: muscles,
                    currentView: currentView,
                    selectedMuscleId: selectedMuscleId,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(TapDownDetails details, Size size) {
    final localPosition = details.localPosition;
    final paths = getMusclePathsForView(currentView);

    // Hit-test against muscle paths (front-to-back, first hit wins)
    for (final pathDef in paths.reversed) {
      final path = pathDef.buildPath(size);
      if (path.contains(localPosition)) {
        HapticFeedback.lightImpact();
        onMuscleSelected(pathDef.muscleId);
        return;
      }
    }
  }
}
