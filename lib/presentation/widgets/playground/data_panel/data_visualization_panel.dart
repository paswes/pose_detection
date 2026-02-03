import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_event.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_state.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';
import 'package:pose_detection/presentation/widgets/playground/data_panel/joint_angles_section.dart';
import 'package:pose_detection/presentation/widgets/playground/data_panel/rom_section.dart';
import 'package:pose_detection/presentation/widgets/playground/data_panel/velocities_section.dart';

/// Collapsible right-side panel for motion data visualization.
class DataVisualizationPanel extends StatelessWidget {
  const DataVisualizationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundBloc, PlaygroundState>(
      buildWhen: (prev, curr) =>
          prev.dataPanelExpanded != curr.dataPanelExpanded ||
          prev.motionData != curr.motionData ||
          prev.displayJoints != curr.displayJoints ||
          prev.showAllVelocities != curr.showAllVelocities ||
          prev.motionConfig != curr.motionConfig,
      builder: (context, state) {
        return AnimatedContainer(
          duration: PlaygroundTheme.panelAnimation,
          curve: Curves.easeOutCubic,
          width: state.dataPanelExpanded
              ? PlaygroundTheme.dataPanelWidth
              : PlaygroundTheme.collapsedPanelWidth,
          decoration: PlaygroundTheme.panelDecoration,
          clipBehavior: Clip.antiAlias,
          child: state.dataPanelExpanded
              ? _ExpandedContent(state: state)
              : _CollapsedContent(),
        );
      },
    );
  }
}

class _CollapsedContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.read<PlaygroundBloc>().add(const TogglePanelEvent(PanelType.data));
      },
      child: const Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left,
                size: 16,
                color: PlaygroundTheme.textMuted,
              ),
              SizedBox(width: 4),
              Text(
                'DATA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: PlaygroundTheme.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  final PlaygroundState state;

  const _ExpandedContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final motionData = state.motionData;
    final config = state.motionConfig;

    return Column(
      children: [
        // Header with collapse button
        _PanelHeader(
          onCollapse: () {
            context.read<PlaygroundBloc>().add(const TogglePanelEvent(PanelType.data));
          },
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PlaygroundTheme.spacingSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Joint Angles
                if (config.trackAngles)
                  JointAnglesSection(
                    angles: motionData?.angles ?? {},
                    displayJoints: state.displayJoints,
                  ),

                if (config.trackAngles && config.trackVelocities)
                  const SizedBox(height: PlaygroundTheme.spacingLg),

                // Velocities
                if (config.trackVelocities)
                  VelocitiesSection(
                    velocities: motionData?.velocities ?? {},
                    showAllVelocities: state.showAllVelocities,
                    isStationary: state.metrics.isStationary,
                    averageSpeed: _calculateAverageSpeed(motionData?.velocities ?? {}),
                  ),

                if (config.trackVelocities && config.trackRom)
                  const SizedBox(height: PlaygroundTheme.spacingLg),

                // Range of Motion
                if (config.trackRom)
                  RomSection(
                    romData: motionData?.rangeOfMotion ?? {},
                    currentAngles: motionData?.angles ?? {},
                    displayJoints: state.displayJoints,
                  ),

                // Bottom padding for safe area
                const SizedBox(height: PlaygroundTheme.spacingXl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _calculateAverageSpeed(Map<int, dynamic> velocities) {
    if (velocities.isEmpty) return 0;
    double total = 0;
    for (final v in velocities.values) {
      total += v.speed;
    }
    return total / velocities.length;
  }
}

class _PanelHeader extends StatelessWidget {
  final VoidCallback onCollapse;

  const _PanelHeader({required this.onCollapse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PlaygroundTheme.spacingSm,
        vertical: PlaygroundTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PlaygroundTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Motion Data',
            style: PlaygroundTheme.headingStyle,
          ),
          const Spacer(),
          InkWell(
            onTap: onCollapse,
            borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: PlaygroundTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
