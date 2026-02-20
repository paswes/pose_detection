import 'package:pose_detection/core/config/pose_detection_config.dart';

/// Tracks consecutive errors for circuit breaker pattern.
/// Stops capture after too many consecutive failures.
class ErrorTracker {
  final int _maxConsecutiveErrors;
  int _consecutiveErrors = 0;

  ErrorTracker({required PoseDetectionConfig config})
    : _maxConsecutiveErrors = config.maxConsecutiveErrors;

  /// Current consecutive error count
  int get consecutiveErrors => _consecutiveErrors;

  /// Maximum allowed consecutive errors
  int get maxConsecutiveErrors => _maxConsecutiveErrors;

  /// Whether error threshold has been exceeded
  bool get hasExceededThreshold => _consecutiveErrors >= _maxConsecutiveErrors;

  /// Record an error
  void recordError() {
    _consecutiveErrors++;
  }

  /// Record a success (resets counter)
  void recordSuccess() {
    _consecutiveErrors = 0;
  }

  /// Reset error counter
  void reset() {
    _consecutiveErrors = 0;
  }
}
