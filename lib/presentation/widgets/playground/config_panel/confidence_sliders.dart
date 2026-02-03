import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_event.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_state.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';

/// Confidence threshold configuration sliders.
class ConfidenceSliders extends StatelessWidget {
  const ConfidenceSliders({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundBloc, PlaygroundState>(
      buildWhen: (prev, curr) =>
          prev.poseConfig != curr.poseConfig ||
          prev.confidenceSectionExpanded != curr.confidenceSectionExpanded,
      builder: (context, state) {
        final config = state.poseConfig;

        return _ExpandableSection(
          title: 'CONFIDENCE',
          isExpanded: state.confidenceSectionExpanded,
          onToggle: () {
            context
                .read<PlaygroundBloc>()
                .add(const TogglePanelEvent(PanelType.confidenceSection));
          },
          child: Column(
            children: [
              // Filter toggle
              _ToggleRow(
                label: 'Filter Low Conf.',
                value: config.filterLowConfidenceLandmarks,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdatePoseConfigEvent(
                          config.copyWith(filterLowConfidenceLandmarks: value),
                        ),
                      );
                },
              ),

              const SizedBox(height: PlaygroundTheme.spacingSm),

              // High confidence threshold
              _SliderRow(
                label: 'High Threshold',
                value: config.highConfidenceThreshold,
                min: 0.5,
                max: 1.0,
                decimals: 2,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdatePoseConfigEvent(
                          config.copyWith(highConfidenceThreshold: value),
                        ),
                      );
                },
              ),

              // Low confidence threshold
              _SliderRow(
                label: 'Low Threshold',
                value: config.lowConfidenceThreshold,
                min: 0.2,
                max: 0.8,
                decimals: 2,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdatePoseConfigEvent(
                          config.copyWith(lowConfidenceThreshold: value),
                        ),
                      );
                },
              ),

              // Min confidence threshold
              _SliderRow(
                label: 'Min Threshold',
                value: config.minConfidenceThreshold,
                min: 0.0,
                max: 0.5,
                decimals: 2,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdatePoseConfigEvent(
                          config.copyWith(minConfidenceThreshold: value),
                        ),
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  const _ExpandableSection({
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: PlaygroundTheme.textMuted,
                ),
                const SizedBox(width: 4),
                Text(title, style: PlaygroundTheme.labelStyle),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(
              left: PlaygroundTheme.spacingSm,
              top: PlaygroundTheme.spacingSm,
            ),
            child: child,
          ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: PlaygroundTheme.labelStyle),
        ),
        SizedBox(
          height: 24,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: PlaygroundTheme.accent,
            activeThumbColor: PlaygroundTheme.textPrimary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int decimals;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.decimals = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: PlaygroundTheme.labelStyle),
            ),
            Text(
              value.toStringAsFixed(decimals),
              style: PlaygroundTheme.valueSmallStyle,
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: PlaygroundTheme.accent,
            inactiveTrackColor: PlaygroundTheme.border,
            thumbColor: PlaygroundTheme.accent,
            overlayColor: PlaygroundTheme.accent.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
