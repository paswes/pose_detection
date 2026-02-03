import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_event.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_state.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';
import 'package:pose_detection/presentation/widgets/playground/config_panel/confidence_sliders.dart';
import 'package:pose_detection/presentation/widgets/playground/config_panel/motion_config_section.dart';
import 'package:pose_detection/presentation/widgets/playground/config_panel/preset_button_row.dart';
import 'package:pose_detection/presentation/widgets/playground/config_panel/smoothing_sliders.dart';

/// Collapsible left-side panel for configuration controls.
class ConfigPanel extends StatelessWidget {
  const ConfigPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundBloc, PlaygroundState>(
      buildWhen: (prev, curr) =>
          prev.configPanelExpanded != curr.configPanelExpanded,
      builder: (context, state) {
        return AnimatedContainer(
          duration: PlaygroundTheme.panelAnimation,
          curve: Curves.easeOutCubic,
          width: state.configPanelExpanded
              ? PlaygroundTheme.configPanelWidth
              : PlaygroundTheme.collapsedPanelWidth,
          decoration: PlaygroundTheme.panelDecoration,
          clipBehavior: Clip.antiAlias,
          child: state.configPanelExpanded
              ? const _ExpandedContent()
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
        context.read<PlaygroundBloc>().add(const TogglePanelEvent(PanelType.config));
      },
      child: const Center(
        child: RotatedBox(
          quarterTurns: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_right,
                size: 16,
                color: PlaygroundTheme.textMuted,
              ),
              SizedBox(width: 4),
              Text(
                'CONFIG',
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
  const _ExpandedContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with collapse button
        _PanelHeader(
          onCollapse: () {
            context.read<PlaygroundBloc>().add(const TogglePanelEvent(PanelType.config));
          },
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PlaygroundTheme.spacingSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pose detection presets
                const PresetButtonRow(),

                const SizedBox(height: PlaygroundTheme.spacingLg),

                // Motion analyzer presets
                const MotionPresetButtonRow(),

                const SizedBox(height: PlaygroundTheme.spacingLg),

                // Smoothing sliders
                const SmoothingSliders(),

                const SizedBox(height: PlaygroundTheme.spacingMd),

                // Confidence sliders
                const ConfidenceSliders(),

                const SizedBox(height: PlaygroundTheme.spacingMd),

                // Motion analysis config
                const MotionConfigSection(),

                // Bottom padding for safe area
                const SizedBox(height: PlaygroundTheme.spacingXl),
              ],
            ),
          ),
        ),
      ],
    );
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
          InkWell(
            onTap: onCollapse,
            borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.chevron_left,
                size: 20,
                color: PlaygroundTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: PlaygroundTheme.spacingSm),
          const Text(
            'Configuration',
            style: PlaygroundTheme.headingStyle,
          ),
        ],
      ),
    );
  }
}
