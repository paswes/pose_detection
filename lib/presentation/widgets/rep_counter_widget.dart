import 'package:flutter/material.dart';
import 'package:pose_detection/domain/models/squat_rep.dart';

/// Animated rep counter widget that pulses on completion
class RepCounterWidget extends StatefulWidget {
  /// Current rep count
  final int repCount;

  /// Last completed rep (triggers animation when non-null)
  final SquatRep? lastCompletedRep;

  /// Size of the counter circle
  final double size;

  const RepCounterWidget({
    super.key,
    required this.repCount,
    this.lastCompletedRep,
    this.size = 80,
  });

  @override
  State<RepCounterWidget> createState() => _RepCounterWidgetState();
}

class _RepCounterWidgetState extends State<RepCounterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  int? _lastAnimatedRep;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 70,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(RepCounterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger animation when a new rep is completed
    if (widget.lastCompletedRep != null &&
        widget.lastCompletedRep!.repNumber != _lastAnimatedRep) {
      _lastAnimatedRep = widget.lastCompletedRep!.repNumber;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.7),
              border: Border.all(
                color: Colors.cyanAccent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: _glowAnimation.value * 0.8),
                  blurRadius: 20 * _glowAnimation.value,
                  spreadRadius: 5 * _glowAnimation.value,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.repCount}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.size * 0.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'REPS',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: widget.size * 0.12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
