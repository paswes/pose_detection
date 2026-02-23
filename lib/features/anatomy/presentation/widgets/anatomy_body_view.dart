import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';

import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';
import 'package:pose_detection/features/anatomy/domain/entities/muscle_status.dart';

/// Maps between app muscle IDs and the [Muscle] enum from
/// `flutter_body_part_selector`.
class _BodyPartMapper {
  /// App muscle ID → package [Muscle] enum values (left/right pairs).
  static const Map<String, Set<Muscle>> _appIdToMuscles = {
    // Front view
    'traps': {Muscle.trapsLeft, Muscle.trapsRight},
    'shoulders': {Muscle.deltsLeft, Muscle.deltsRight},
    'chest': {Muscle.chestLeft, Muscle.chestRight},
    'biceps': {Muscle.bicepsLeft, Muscle.bicepsRight},
    'triceps': {Muscle.tricepsLeft, Muscle.tricepsRight},
    'forearms': {Muscle.forearmsLeft, Muscle.forearmsRight},
    'abs': {Muscle.abs},
    'quads': {Muscle.quadsLeft, Muscle.quadsRight},
    'calves': {Muscle.calvesLeft, Muscle.calvesRight},
    // Back view
    'lats': {Muscle.latsBackLeft, Muscle.latsBackRight},
    'lower_back': {Muscle.lowerLatsBackLeft, Muscle.lowerLatsBackRight},
    'glutes': {Muscle.glutesLeft, Muscle.glutesRight},
    'hamstrings': {Muscle.hamstringsLeft, Muscle.hamstringsRight},
  };

  /// Reverse lookup: given a tapped [Muscle], return the app muscle ID.
  static final Map<Muscle, String> _muscleToAppId = () {
    final map = <Muscle, String>{};
    for (final entry in _appIdToMuscles.entries) {
      for (final muscle in entry.value) {
        map[muscle] = entry.key;
      }
    }
    return map;
  }();

  /// Get all [Muscle] values for a given app muscle ID.
  static Set<Muscle> musclesForAppId(String appId) {
    return _appIdToMuscles[appId] ?? {};
  }

  /// Get the app muscle ID for a tapped [Muscle].
  static String? appIdFromMuscle(Muscle muscle) {
    return _muscleToAppId[muscle];
  }
}

/// Interactive body view using `flutter_body_part_selector`.
///
/// Uses stacked [InteractiveBodySvg] layers to show multiple status colors
/// simultaneously (trained=green, complaint=red, weak=yellow).
/// The top layer handles tap interaction.
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

  /// Collect [Muscle] enum values for all muscles matching a given [test].
  Set<Muscle> _collectMuscles(bool Function(MuscleGroup) test) {
    final result = <Muscle>{};
    for (final m in muscles) {
      if (m.view == currentView && test(m)) {
        result.addAll(_BodyPartMapper.musclesForAppId(m.id));
      }
    }
    return result;
  }

  void _handleMuscleTap(Muscle muscle) {
    final appId = _BodyPartMapper.appIdFromMuscle(muscle);
    if (appId == null) return;

    // Verify this muscle belongs to the current view.
    final inView = muscles.any((m) => m.id == appId && m.view == currentView);
    if (!inView) return;

    HapticFeedback.lightImpact();
    onMuscleSelected(appId);
  }

  @override
  Widget build(BuildContext context) {
    final isFront = currentView == BodyView.front;

    // Build muscle sets per status.
    final trainedMuscles = _collectMuscles((m) => m.status is TrainedStatus);
    final complaintMuscles =
        _collectMuscles((m) => m.status is ComplaintStatus);
    final weakMuscles = _collectMuscles((m) => m.status is WeakStatus);

    // Currently selected/tapped muscle highlight.
    final selectedMuscles = selectedMuscleId != null
        ? _BodyPartMapper.musclesForAppId(selectedMuscleId!)
        : <Muscle>{};

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.0,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Trained muscles (green)
            if (trainedMuscles.isNotEmpty)
              _StatusLayer(
                key: ValueKey('trained_${isFront}_$trainedMuscles'),
                isFront: isFront,
                selectedMuscles: trainedMuscles,
                color: const Color(0xFF4CAF50),
              ),

            // Layer 2: Complaint muscles (red)
            if (complaintMuscles.isNotEmpty)
              _StatusLayer(
                key: ValueKey('complaint_${isFront}_$complaintMuscles'),
                isFront: isFront,
                selectedMuscles: complaintMuscles,
                color: const Color(0xFFFF5252),
              ),

            // Layer 3: Weak muscles (yellow)
            if (weakMuscles.isNotEmpty)
              _StatusLayer(
                key: ValueKey('weak_${isFront}_$weakMuscles'),
                isFront: isFront,
                selectedMuscles: weakMuscles,
                color: const Color(0xFFFFEB3B),
              ),

            // Layer 4: Interactive tap layer
            InteractiveBodySvg(
              key: ValueKey('interactive_$isFront'),
              isFront: isFront,
              selectedMuscles: selectedMuscles,
              onMuscleTap: _handleMuscleTap,
              highlightColor: Colors.white.withValues(alpha: 0.25),
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

/// A non-interactive SVG layer that displays selected muscles with a given
/// highlight color. Used to show status colors underneath the interactive layer.
class _StatusLayer extends StatelessWidget {
  final bool isFront;
  final Set<Muscle> selectedMuscles;
  final Color color;

  const _StatusLayer({
    super.key,
    required this.isFront,
    required this.selectedMuscles,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: InteractiveBodySvg(
        isFront: isFront,
        selectedMuscles: selectedMuscles,
        enableSelection: false,
        highlightColor: color,
        fit: BoxFit.contain,
      ),
    );
  }
}
