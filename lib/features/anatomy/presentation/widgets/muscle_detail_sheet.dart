import 'package:flutter/material.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';
import 'package:pose_detection/features/anatomy/domain/entities/muscle_status.dart';

/// Shows the muscle detail bottom sheet using wolt_modal_sheet.
void showMuscleDetailSheet({
  required BuildContext context,
  required MuscleGroup muscle,
  required ValueChanged<MuscleStatus> onStatusChanged,
  required VoidCallback onDismissed,
}) {
  WoltModalSheet.show(
    context: context,
    pageListBuilder: (bottomSheetContext) => [
      _buildPage(bottomSheetContext, muscle, onStatusChanged),
    ],
    onModalDismissedWithBarrierTap: onDismissed,
    onModalDismissedWithDrag: onDismissed,
    modalBarrierColor: Colors.black54,
  );
}

SliverWoltModalSheetPage _buildPage(
  BuildContext context,
  MuscleGroup muscle,
  ValueChanged<MuscleStatus> onStatusChanged,
) {
  return SliverWoltModalSheetPage(
    backgroundColor: const Color(0xFF1E1E1E),
    surfaceTintColor: Colors.transparent,
    hasSabGradient: false,
    topBarTitle: Text(
      muscle.nameDE,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    isTopBarLayerAlwaysVisible: true,
    trailingNavBarWidget: Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: const Icon(Icons.close, color: Color(0xFF888888)),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    mainContentSliversBuilder: (context) => [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        sliver: SliverList.list(
          children: [
            // Latin name
            Text(
              muscle.nameLatin,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 20),

            // Status toggles
            _StatusSelector(
              currentStatus: muscle.status,
              onChanged: (status) {
                onStatusChanged(status);
                Navigator.of(context).pop();
              },
            ),

            const SizedBox(height: 24),

            // Anatomy section
            const _SectionHeader(title: 'ANATOMIE'),
            const SizedBox(height: 12),
            _InfoRow(label: 'Ursprung', value: muscle.origin),
            const SizedBox(height: 8),
            _InfoRow(label: 'Ansatz', value: muscle.insertion),
            const SizedBox(height: 8),
            _InfoRow(label: 'Funktion', value: muscle.function),

            const SizedBox(height: 24),

            // Exercises section
            const _SectionHeader(title: 'UEBUNGEN'),
            const SizedBox(height: 12),
            ...muscle.exercises.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fitness_center_rounded,
                      color: Color(0xFF666666),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.nameDE,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e.equipment,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ── Private widgets ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF666666),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFFCCCCCC),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusSelector extends StatelessWidget {
  final MuscleStatus currentStatus;
  final ValueChanged<MuscleStatus> onChanged;

  const _StatusSelector({
    required this.currentStatus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusChip(
          label: 'Normal',
          color: const Color(0xFF888888),
          isSelected: currentStatus is NormalStatus,
          onTap: () => onChanged(const NormalStatus()),
        ),
        const SizedBox(width: 8),
        _StatusChip(
          label: 'Trainiert',
          color: const Color(0xFF4CAF50),
          isSelected: currentStatus is TrainedStatus,
          onTap: () => onChanged(TrainedStatus(trainedAt: DateTime.now())),
        ),
        const SizedBox(width: 8),
        _StatusChip(
          label: 'Beschwerde',
          color: const Color(0xFFFF5252),
          isSelected: currentStatus is ComplaintStatus,
          onTap: () => onChanged(const ComplaintStatus()),
        ),
        const SizedBox(width: 8),
        _StatusChip(
          label: 'Schwach',
          color: const Color(0xFFFFEB3B),
          isSelected: currentStatus is WeakStatus,
          onTap: () => onChanged(const WeakStatus()),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : const Color(0xFF888888),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
