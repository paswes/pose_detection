import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_event.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_state.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';

/// Motion analyzer configuration section.
class MotionConfigSection extends StatelessWidget {
  const MotionConfigSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundBloc, PlaygroundState>(
      buildWhen: (prev, curr) =>
          prev.motionConfig != curr.motionConfig ||
          prev.motionSectionExpanded != curr.motionSectionExpanded,
      builder: (context, state) {
        final config = state.motionConfig;

        return _ExpandableSection(
          title: 'MOTION ANALYSIS',
          isExpanded: state.motionSectionExpanded,
          onToggle: () {
            context
                .read<PlaygroundBloc>()
                .add(const TogglePanelEvent(PanelType.motionSection));
          },
          child: Column(
            children: [
              // Feature toggles
              _ToggleRow(
                label: 'Track Angles',
                value: config.trackAngles,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdateMotionConfigEvent(
                          config.copyWith(trackAngles: value),
                        ),
                      );
                },
              ),

              _ToggleRow(
                label: 'Track Velocities',
                value: config.trackVelocities,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdateMotionConfigEvent(
                          config.copyWith(trackVelocities: value),
                        ),
                      );
                },
              ),

              _ToggleRow(
                label: 'Track ROM',
                value: config.trackRom,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdateMotionConfigEvent(
                          config.copyWith(trackRom: value),
                        ),
                      );
                },
              ),

              _ToggleRow(
                label: 'Use 3D Angles',
                value: config.use3DAngles,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdateMotionConfigEvent(
                          config.copyWith(use3DAngles: value),
                        ),
                      );
                },
              ),

              const SizedBox(height: PlaygroundTheme.spacingSm),

              // History capacity slider
              _SliderRow(
                label: 'History Size',
                value: config.historyCapacity.toDouble(),
                min: 10,
                max: 120,
                decimals: 0,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdateMotionConfigEvent(
                          config.copyWith(historyCapacity: value.toInt()),
                        ),
                      );
                },
              ),

              // Velocity smoothing slider
              _SliderRow(
                label: 'Velocity Smooth',
                value: config.velocitySmoothingFactor,
                min: 0.0,
                max: 1.0,
                decimals: 2,
                enabled: config.trackVelocities,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdateMotionConfigEvent(
                          config.copyWith(velocitySmoothingFactor: value),
                        ),
                      );
                },
              ),

              // Min confidence slider
              _SliderRow(
                label: 'Min Confidence',
                value: config.minConfidence,
                min: 0.0,
                max: 0.8,
                decimals: 2,
                onChanged: (value) {
                  context.read<PlaygroundBloc>().add(
                        UpdateMotionConfigEvent(
                          config.copyWith(minConfidence: value),
                        ),
                      );
                },
              ),

              const SizedBox(height: PlaygroundTheme.spacingMd),

              // Reset button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<PlaygroundBloc>().add(
                          const ResetMotionAnalysisEvent(),
                        );
                  },
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Reset Analysis'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PlaygroundTheme.textSecondary,
                    side: const BorderSide(color: PlaygroundTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
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
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
