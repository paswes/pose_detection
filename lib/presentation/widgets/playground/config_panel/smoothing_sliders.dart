import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_event.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_state.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';

/// Smoothing configuration sliders (OneEuroFilter parameters).
class SmoothingSliders extends StatelessWidget {
  const SmoothingSliders({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundBloc, PlaygroundState>(
      buildWhen: (prev, curr) =>
          prev.poseConfig != curr.poseConfig ||
          prev.smoothingSectionExpanded != curr.smoothingSectionExpanded,
      builder: (context, state) {
        final config = state.poseConfig;

        return _ExpandableSection(
          title: 'SMOOTHING',
          isExpanded: state.smoothingSectionExpanded,
          onToggle: () {
            context
                .read<PlaygroundBloc>()
                .add(const TogglePanelEvent(PanelType.smoothingSection));
          },
          child: Column(
            children: [
              // Enable toggle
              _ToggleRow(
                label: 'Enabled',
                value: config.smoothingEnabled,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdatePoseConfigEvent(
                          config.copyWith(smoothingEnabled: value),
                        ),
                      );
                },
              ),

              const SizedBox(height: PlaygroundTheme.spacingSm),

              // Min Cutoff slider
              _SliderRow(
                label: 'Min Cutoff',
                value: config.smoothingMinCutoff,
                min: 0.1,
                max: 10.0,
                enabled: config.smoothingEnabled,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdatePoseConfigEvent(
                          config.copyWith(smoothingMinCutoff: value),
                        ),
                      );
                },
              ),

              // Beta slider
              _SliderRow(
                label: 'Beta',
                value: config.smoothingBeta,
                min: 0.0,
                max: 0.1,
                decimals: 3,
                enabled: config.smoothingEnabled,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdatePoseConfigEvent(
                          config.copyWith(smoothingBeta: value),
                        ),
                      );
                },
              ),

              // Derivative Cutoff slider
              _SliderRow(
                label: 'Deriv Cutoff',
                value: config.smoothingDerivativeCutoff,
                min: 0.1,
                max: 10.0,
                enabled: config.smoothingEnabled,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdatePoseConfigEvent(
                          config.copyWith(smoothingDerivativeCutoff: value),
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
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.decimals = 1,
    this.enabled = true,
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
              child: Text(
                label,
                style: PlaygroundTheme.labelStyle.copyWith(
                  color: enabled
                      ? PlaygroundTheme.textMuted
                      : PlaygroundTheme.textMuted.withValues(alpha: 0.5),
                ),
              ),
            ),
            Text(
              value.toStringAsFixed(decimals),
              style: PlaygroundTheme.valueSmallStyle.copyWith(
                color: enabled
                    ? PlaygroundTheme.textPrimary
                    : PlaygroundTheme.textMuted.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: enabled ? PlaygroundTheme.accent : PlaygroundTheme.border,
            inactiveTrackColor: PlaygroundTheme.border,
            thumbColor: enabled ? PlaygroundTheme.accent : PlaygroundTheme.textMuted,
            overlayColor: PlaygroundTheme.accent.withValues(alpha: 0.2),
            activeTickMarkColor: enabled ? PlaygroundTheme.accent : PlaygroundTheme.border,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: enabled ? onChanged : null,
            activeColor: enabled ? PlaygroundTheme.accent : PlaygroundTheme.border,
            inactiveColor: PlaygroundTheme.border,
          ),
        ),
      ],
    );
  }
}
