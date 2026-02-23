import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:muscle_selector/muscle_selector.dart';

import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';
import 'package:pose_detection/features/anatomy/domain/entities/muscle_status.dart';

/// Maps between app muscle IDs and the muscle_selector package group names.
///
/// The package uses group names like 'forearm', 'trapezius', 'harmstrings'
/// while the app uses 'forearms', 'traps', 'hamstrings'.
class _MuscleIdMapper {
  static const _appToPackage = {
    'forearms': 'forearm',
    'traps': 'trapezius',
    'hamstrings': 'harmstrings',
  };

  static const _packageToApp = {
    'forearm': 'forearms',
    'trapezius': 'traps',
    'harmstrings': 'hamstrings',
  };

  /// Package muscle sub-IDs grouped by their group name.
  /// Mirrors the package's internal Parser.muscleGroups.
  static const _packageGroups = {
    'chest': ['chest1', 'chest2'],
    'shoulders': ['shoulder1', 'shoulder2', 'shoulder3', 'shoulder4'],
    'obliques': ['obliques1', 'obliques2'],
    'abs': ['abs1', 'abs2', 'abs3', 'abs4', 'abs5', 'abs6', 'abs7', 'abs8'],
    'abductor': ['abductor1', 'abductor2'],
    'biceps': ['biceps1', 'biceps2'],
    'calves': ['calves1', 'calves2', 'calves3', 'calves4'],
    'forearm': ['forearm1', 'forearm2', 'forearm3', 'forearm4'],
    'glutes': ['glutes1', 'glutes2'],
    'harmstrings': ['harmstrings1', 'harmstrings2'],
    'lats': ['lats1', 'lats2'],
    'upper_back': ['upper_back1', 'upper_back2'],
    'quads': ['quads1', 'quads2', 'quads3', 'quads4'],
    'trapezius': ['trapezius1', 'trapezius2', 'trapezius3', 'trapezius4', 'trapezius5'],
    'triceps': ['triceps1', 'triceps2'],
    'adductors': ['adductors1', 'adductors2'],
    'lower_back': ['lower_back'],
    'neck': ['neck'],
  };

  /// Convert an app muscle ID to the package group name.
  static String toPackageGroup(String appId) => _appToPackage[appId] ?? appId;

  /// Given a package [Muscle.id] like 'chest1', find the app muscle ID.
  static String? appIdFromMuscleSubId(String subId) {
    for (final entry in _packageGroups.entries) {
      if (entry.value.contains(subId)) {
        return _packageToApp[entry.key] ?? entry.key;
      }
    }
    return null;
  }
}

/// Interactive body view using the muscle_selector package SVG body.
///
/// Renders a professional anatomical SVG with tappable muscle regions.
/// Non-normal muscles are highlighted with a single accent color.
class AnatomyBodyView extends StatefulWidget {
  final List<MuscleGroup> muscles;
  final String? selectedMuscleId;
  final ValueChanged<String> onMuscleSelected;

  const AnatomyBodyView({
    super.key,
    required this.muscles,
    this.selectedMuscleId,
    required this.onMuscleSelected,
  });

  @override
  State<AnatomyBodyView> createState() => _AnatomyBodyViewState();
}

class _AnatomyBodyViewState extends State<AnatomyBodyView> {
  final _mapKey = GlobalKey<MusclePickerMapState>();

  /// Build the list of package group names that should be highlighted.
  List<String> _highlightedGroups() {
    return widget.muscles
        .where((m) => m.status is! NormalStatus)
        .map((m) => _MuscleIdMapper.toPackageGroup(m.id))
        .toList();
  }

  void _handleSelectionChanged(Set<Muscle> selected) {
    if (selected.isEmpty) return;

    // Find which muscle group was tapped from the selected set.
    for (final muscle in selected) {
      final appId = _MuscleIdMapper.appIdFromMuscleSubId(muscle.id);
      if (appId != null) {
        HapticFeedback.lightImpact();
        widget.onMuscleSelected(appId);

        // Clear the package's internal selection after handling the tap,
        // since we manage selection state via our own cubit.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapKey.currentState?.clearSelect();
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.0,
      child: Center(
        child: MusclePickerMap(
          key: _mapKey,
          map: Maps.BODY,
          onChanged: _handleSelectionChanged,
          selectedColor: const Color(0xFF4CAF50),
          strokeColor: Colors.white60,
          dotColor: Colors.transparent,
          actAsToggle: true,
          initialSelectedGroups: _highlightedGroups(),
        ),
      ),
    );
  }
}
