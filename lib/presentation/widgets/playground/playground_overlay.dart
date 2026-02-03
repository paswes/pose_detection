import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_bloc.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_event.dart';
import 'package:pose_detection/presentation/bloc/playground/playground_state.dart';
import 'package:pose_detection/presentation/theme/playground_theme.dart';
import 'package:pose_detection/presentation/widgets/playground/config_panel/config_panel.dart';
import 'package:pose_detection/presentation/widgets/playground/data_panel/data_visualization_panel.dart';
import 'package:pose_detection/presentation/widgets/playground/top_metrics_bar.dart';

/// Main overlay for the playground UI.
///
/// Contains:
/// - Top metrics bar
/// - Config panel (left)
/// - Data panel (right)
/// - Bottom controls
class PlaygroundOverlay extends StatelessWidget {
  const PlaygroundOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top metrics bar
        const TopMetricsBar(),

        // Middle section with panels
        Expanded(
          child: Row(
            children: [
              // Config panel (left)
              const ConfigPanel(),

              // Spacer for camera view
              const Spacer(),

              // Data panel (right)
              const DataVisualizationPanel(),
            ],
          ),
        ),

        // Bottom controls
        const _BottomControls(),
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PlaygroundTheme.surface.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: PlaygroundTheme.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PlaygroundTheme.spacingLg,
            vertical: PlaygroundTheme.spacingMd,
          ),
          child: BlocBuilder<PlaygroundBloc, PlaygroundState>(
            buildWhen: (prev, curr) =>
                prev.isDetecting != curr.isDetecting ||
                prev.canSwitchCamera != curr.canSwitchCamera ||
                prev.isCameraReady != curr.isCameraReady,
            builder: (context, state) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Camera switch button
                  _CameraSwitchButton(
                    enabled: state.canSwitchCamera,
                    onPressed: () {
                      context.read<PlaygroundBloc>().add(const SwitchCameraEvent());
                    },
                  ),

                  // Start/Stop button
                  _MainActionButton(
                    isDetecting: state.isDetecting,
                    enabled: state.isCameraReady || state.isDetecting,
                    onPressed: () {
                      if (state.isDetecting) {
                        context.read<PlaygroundBloc>().add(const StopCaptureEvent());
                      } else {
                        context.read<PlaygroundBloc>().add(const StartCaptureEvent());
                      }
                    },
                  ),

                  // Panel toggle buttons
                  _PanelToggleButtons(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CameraSwitchButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _CameraSwitchButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          backgroundColor: enabled
              ? PlaygroundTheme.surfaceLight
              : PlaygroundTheme.surfaceLight.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PlaygroundTheme.radiusCircle),
            side: BorderSide(
              color: enabled ? PlaygroundTheme.border : PlaygroundTheme.border.withValues(alpha: 0.5),
            ),
          ),
        ),
        icon: Icon(
          Icons.flip_camera_ios,
          color: enabled
              ? PlaygroundTheme.textSecondary
              : PlaygroundTheme.textMuted.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final bool isDetecting;
  final bool enabled;
  final VoidCallback onPressed;

  const _MainActionButton({
    required this.isDetecting,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDetecting ? PlaygroundTheme.error : PlaygroundTheme.success;
    final icon = isDetecting ? Icons.stop : Icons.play_arrow;

    return SizedBox(
      width: 64,
      height: 64,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : color.withValues(alpha: 0.5),
          foregroundColor: PlaygroundTheme.textPrimary,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PlaygroundTheme.radiusCircle),
          ),
        ),
        child: Icon(icon, size: 32),
      ),
    );
  }
}

class _PanelToggleButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundBloc, PlaygroundState>(
      buildWhen: (prev, curr) =>
          prev.configPanelExpanded != curr.configPanelExpanded ||
          prev.dataPanelExpanded != curr.dataPanelExpanded,
      builder: (context, state) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PanelToggle(
              icon: Icons.tune,
              isActive: state.configPanelExpanded,
              onPressed: () {
                context.read<PlaygroundBloc>().add(const TogglePanelEvent(PanelType.config));
              },
            ),
            const SizedBox(width: PlaygroundTheme.spacingSm),
            _PanelToggle(
              icon: Icons.analytics,
              isActive: state.dataPanelExpanded,
              onPressed: () {
                context.read<PlaygroundBloc>().add(const TogglePanelEvent(PanelType.data));
              },
            ),
          ],
        );
      },
    );
  }
}

class _PanelToggle extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  const _PanelToggle({
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: isActive
              ? PlaygroundTheme.accent.withValues(alpha: 0.2)
              : PlaygroundTheme.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PlaygroundTheme.radiusSm),
            side: BorderSide(
              color: isActive ? PlaygroundTheme.accent : PlaygroundTheme.border,
            ),
          ),
        ),
        icon: Icon(
          icon,
          size: 18,
          color: isActive ? PlaygroundTheme.accent : PlaygroundTheme.textSecondary,
        ),
      ),
    );
  }
}
