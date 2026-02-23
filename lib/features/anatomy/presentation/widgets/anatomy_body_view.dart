import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:muscle_selector/muscle_selector.dart';

import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';

/// Maps between app muscle IDs and the muscle_selector package group names.
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
    'trapezius': [
      'trapezius1',
      'trapezius2',
      'trapezius3',
      'trapezius4',
      'trapezius5',
    ],
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
/// Tap a muscle → it highlights green and the detail sheet opens.
/// When the sheet is dismissed, [selectedMuscleId] becomes null and the
/// highlight disappears (the widget rebuilds with no initial selection).
class AnatomyBodyView extends StatefulWidget {
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
  State<AnatomyBodyView> createState() => _AnatomyBodyViewState();
}

class _AnatomyBodyViewState extends State<AnatomyBodyView> {
  bool _initialized = false;
  Set<String> _previousSelectedIds = {};

  /// Set of app muscle IDs that belong to the current view.
  Set<String> get _currentViewMuscleIds => widget.muscles
      .where((m) => m.view == widget.currentView)
      .map((m) => m.id)
      .toSet();

  void _handleSelectionChanged(Set<Muscle> selected) {
    final currentIds = selected.map((m) => m.id).toSet();

    // Skip the init callback fired by the package after SVG load.
    if (!_initialized) {
      _initialized = true;
      _previousSelectedIds = currentIds;
      return;
    }

    // Detect which muscle was just added by the user's tap.
    final newlyAdded = currentIds.difference(_previousSelectedIds);
    _previousSelectedIds = currentIds;

    if (newlyAdded.isEmpty) return;

    final viewIds = _currentViewMuscleIds;

    for (final subId in newlyAdded) {
      final appId = _MuscleIdMapper.appIdFromMuscleSubId(subId);
      if (appId != null && viewIds.contains(appId)) {
        HapticFeedback.lightImpact();
        widget.onMuscleSelected(appId);
        return;
      }
    }
  }

  @override
  void didUpdateWidget(AnatomyBodyView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset when the ValueKey will change (different view or selection).
    if (oldWidget.currentView != widget.currentView ||
        oldWidget.selectedMuscleId != widget.selectedMuscleId) {
      _initialized = false;
      _previousSelectedIds = {};
    }
  }

  @override
  Widget build(BuildContext context) {
    // Highlight only the currently selected muscle (if any).
    final highlighted = <String>[];
    if (widget.selectedMuscleId != null) {
      highlighted.add(
        _MuscleIdMapper.toPackageGroup(widget.selectedMuscleId!),
      );
    }

    // Key changes when view or selection changes → fresh MusclePickerMap.
    final mapKey = ValueKey(
      '${widget.currentView.name}_${widget.selectedMuscleId ?? 'none'}',
    );

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.0,
      child: Center(
        child: MusclePickerMap(
          key: mapKey,
          height: 800,
          width: 200,
          map: Maps.BODY,
          onChanged: _handleSelectionChanged,
          selectedColor: const Color(0xFF4CAF50),
          strokeColor: Colors.white60,
          dotColor: Colors.transparent,
          initialSelectedGroups: highlighted,
        ),
      ),
    );
  }
}
