import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_event.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_state.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';

/// Row of preset buttons for quick configuration switching.
class PresetButtonRow extends StatelessWidget {
  const PresetButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundBloc, PlaygroundState>(
      buildWhen: (prev, curr) => prev.activePreset != curr.activePreset,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'POSE PRESETS',
              style: PlaygroundTheme.labelStyle,
            ),
            const SizedBox(height: PlaygroundTheme.spacingSm),
            Wrap(
              spacing: PlaygroundTheme.spacingXs,
              runSpacing: PlaygroundTheme.spacingXs,
              children: [
                _PresetButton(
                  label: 'Default',
                  preset: ConfigPreset.defaultConfig,
                  isSelected: state.activePreset == ConfigPreset.defaultConfig,
                ),
                _PresetButton(
                  label: 'Smooth',
                  preset: ConfigPreset.smoothVisuals,
                  isSelected: state.activePreset == ConfigPreset.smoothVisuals,
                ),
                _PresetButton(
                  label: 'Responsive',
                  preset: ConfigPreset.responsive,
                  isSelected: state.activePreset == ConfigPreset.responsive,
                ),
                _PresetButton(
                  label: 'Raw',
                  preset: ConfigPreset.raw,
                  isSelected: state.activePreset == ConfigPreset.raw,
                ),
                _PresetButton(
                  label: 'Hi-Prec',
                  preset: ConfigPreset.highPrecision,
                  isSelected: state.activePreset == ConfigPreset.highPrecision,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final ConfigPreset preset;
  final bool isSelected;

  const _PresetButton({
    required this.label,
    required this.preset,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ElevatedButton(
        onPressed: () {
          context.read<PlaygroundBloc>().add(ApplyPresetEvent(preset));
        },
        style: PlaygroundTheme.presetButtonStyle(isSelected: isSelected),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Motion analyzer preset buttons
class MotionPresetButtonRow extends StatelessWidget {
  const MotionPresetButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundBloc, PlaygroundState>(
      buildWhen: (prev, curr) => prev.activePreset != curr.activePreset,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MOTION PRESETS',
              style: PlaygroundTheme.labelStyle,
            ),
            const SizedBox(height: PlaygroundTheme.spacingSm),
            Wrap(
              spacing: PlaygroundTheme.spacingXs,
              runSpacing: PlaygroundTheme.spacingXs,
              children: [
                _PresetButton(
                  label: 'Full',
                  preset: ConfigPreset.motionFull,
                  isSelected: state.activePreset == ConfigPreset.motionFull,
                ),
                _PresetButton(
                  label: 'Minimal',
                  preset: ConfigPreset.motionMinimal,
                  isSelected: state.activePreset == ConfigPreset.motionMinimal,
                ),
                _PresetButton(
                  label: 'ROM',
                  preset: ConfigPreset.motionRomFocused,
                  isSelected: state.activePreset == ConfigPreset.motionRomFocused,
                ),
                _PresetButton(
                  label: 'Velocity',
                  preset: ConfigPreset.motionVelocityFocused,
                  isSelected: state.activePreset == ConfigPreset.motionVelocityFocused,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
