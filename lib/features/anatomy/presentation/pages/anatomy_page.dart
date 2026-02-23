import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:pose_detection/core/di/service_locator.dart';
import 'package:pose_detection/features/anatomy/presentation/cubit/anatomy_cubit.dart';
import 'package:pose_detection/features/anatomy/presentation/cubit/anatomy_state.dart';
import 'package:pose_detection/features/anatomy/presentation/widgets/anatomy_body_view.dart';
import 'package:pose_detection/features/anatomy/presentation/widgets/anatomy_legend.dart';
import 'package:pose_detection/features/anatomy/presentation/widgets/muscle_detail_sheet.dart';

/// Interactive anatomy avatar page for the demo.
class AnatomyPage extends StatefulWidget {
  const AnatomyPage({super.key});

  @override
  State<AnatomyPage> createState() => _AnatomyPageState();
}

class _AnatomyPageState extends State<AnatomyPage> {
  late final AnatomyCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<AnatomyCubit>();
    _cubit.loadMuscles();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _handleMuscleSelected(String muscleId) {
    _cubit.selectMuscle(muscleId);

    final state = _cubit.state;
    if (state is! AnatomyLoaded) return;

    final muscle = state.muscleById(muscleId);
    if (muscle == null) return;

    showMuscleDetailSheet(
      context: context,
      muscle: muscle,
      onStatusChanged: (status) {
        _cubit.updateStatus(muscleId, status);
        _cubit.clearSelection();
      },
      onDismissed: _cubit.clearSelection,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Anatomie',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        body: BlocBuilder<AnatomyCubit, AnatomyState>(
          builder: (context, state) {
            return switch (state) {
              AnatomyLoading() => const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF888888),
                  ),
                ),
              AnatomyError(:final message) => Center(
                  child: Text(
                    message,
                    style: const TextStyle(color: Color(0xFFFF5252)),
                  ),
                ),
              AnatomyLoaded() => _AnatomyLoadedView(
                  state: state,
                  onMuscleSelected: _handleMuscleSelected,
                  onDemoTraining: _cubit.applyDemoTraining,
                  onReset: _cubit.resetAll,
                ),
            };
          },
        ),
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────

class _AnatomyLoadedView extends StatelessWidget {
  final AnatomyLoaded state;
  final ValueChanged<String> onMuscleSelected;
  final VoidCallback onDemoTraining;
  final VoidCallback onReset;

  const _AnatomyLoadedView({
    required this.state,
    required this.onMuscleSelected,
    required this.onDemoTraining,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Body view (takes available space)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AnatomyBodyView(
                muscles: state.muscles,
                selectedMuscleId: state.selectedMuscleId,
                onMuscleSelected: onMuscleSelected,
              ),
            ),
          ),

          // Legend
          AnatomyLegend(
            trainedCount: state.trainedCount,
            complaintCount: state.complaintCount,
            weakCount: state.weakCount,
          ),

          const SizedBox(height: 12),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onDemoTraining,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Demo: Training anwenden',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onReset,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF888888),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
