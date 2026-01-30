import 'package:flutter/material.dart';

/// Vertical bar indicator showing squat depth
class DepthIndicator extends StatelessWidget {
  /// Current knee angle (170° = standing, 90° = parallel)
  final double currentKneeAngle;

  /// Target angle for parallel (default 90°)
  final double parallelAngle;

  /// Standing angle (default 170°)
  final double standingAngle;

  /// Width of the indicator bar
  final double width;

  /// Height of the indicator bar
  final double height;

  const DepthIndicator({
    super.key,
    required this.currentKneeAngle,
    this.parallelAngle = 90.0,
    this.standingAngle = 170.0,
    this.width = 30,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate fill percentage (0 = standing, 1 = parallel or below)
    final range = standingAngle - parallelAngle;
    final progress = ((standingAngle - currentKneeAngle) / range).clamp(0.0, 1.5);

    // Parallel marker position (at 100% / 1.0)
    const parallelPosition = 1.0;

    // Color based on depth
    final fillColor = _getDepthColor(progress);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(width / 2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Fill bar (grows from bottom)
          Positioned(
            left: 2,
            right: 2,
            bottom: 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              height: ((height - 4) * progress / 1.5).clamp(0.0, height - 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    fillColor.withValues(alpha: 0.8),
                    fillColor,
                  ],
                ),
                borderRadius: BorderRadius.circular((width - 4) / 2),
                boxShadow: [
                  BoxShadow(
                    color: fillColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          // Parallel marker line
          Positioned(
            left: 0,
            right: 0,
            bottom: (height - 4) * parallelPosition / 1.5,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // Parallel label
          Positioned(
            left: width + 4,
            bottom: (height - 4) * parallelPosition / 1.5 - 8,
            child: Text(
              '||',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Depth percentage label
          Positioned(
            left: 0,
            right: 0,
            top: 8,
            child: Text(
              '${(progress * 100).round()}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDepthColor(double progress) {
    if (progress >= 1.0) return Colors.greenAccent; // At or below parallel
    if (progress >= 0.8) return Colors.lightGreenAccent; // Almost there
    if (progress >= 0.5) return Colors.yellowAccent; // Half squat
    if (progress >= 0.25) return Colors.orangeAccent; // Quarter squat
    return Colors.redAccent; // Barely moving
  }
}

/// Compact horizontal depth indicator for top bar
class CompactDepthIndicator extends StatelessWidget {
  /// Current depth percentage (0-100+)
  final double depthPercentage;

  /// Width of the indicator
  final double width;

  const CompactDepthIndicator({
    super.key,
    required this.depthPercentage,
    this.width = 100,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (depthPercentage / 100).clamp(0.0, 1.5);
    final color = _getDepthColor(progress);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Depth',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: width,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // Fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: width * (progress / 1.5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Parallel marker
              Positioned(
                left: width * (1.0 / 1.5) - 1,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${depthPercentage.round()}%',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getDepthColor(double progress) {
    if (progress >= 1.0) return Colors.greenAccent;
    if (progress >= 0.8) return Colors.lightGreenAccent;
    if (progress >= 0.5) return Colors.yellowAccent;
    if (progress >= 0.25) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
