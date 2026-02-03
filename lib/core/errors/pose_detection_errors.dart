/// Enumeration of all possible pose detection error types.
/// Provides structured error handling instead of string-based errors.
enum PoseDetectionErrorCode {
  /// Camera failed to initialize
  cameraInitFailed,

  /// Camera controller is null or not initialized
  cameraNotInitialized,

  /// Failed to start camera image stream
  streamStartFailed,

  /// Failed to switch camera
  cameraSwitchFailed,

  /// ML Kit pose detection failed
  mlKitDetectionFailed,

  /// Image conversion failed (e.g., format not supported)
  imageConversionFailed,

  /// Too many consecutive errors occurred
  tooManyConsecutiveErrors,

  /// Frame processing timed out
  processingTimeout,

  /// Unknown or unspecified error
  unknown,
}

/// Structured error for pose detection failures.
/// Contains error code, human-readable message, and optional details.
class PoseDetectionException implements Exception {
  /// The error code for programmatic handling
  final PoseDetectionErrorCode code;

  /// Human-readable error message
  final String message;

  /// Optional original error that caused this exception
  final Object? cause;

  /// Optional stack trace from the original error
  final StackTrace? stackTrace;

  /// Timestamp when the error occurred (set at creation time)
  final DateTime timestamp;

  PoseDetectionException({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Factory for camera initialization errors
  factory PoseDetectionException.cameraInitFailed([Object? cause]) {
    return PoseDetectionException(
      code: PoseDetectionErrorCode.cameraInitFailed,
      message: 'Failed to initialize camera',
      cause: cause,
    );
  }

  /// Factory for camera not initialized errors
  factory PoseDetectionException.cameraNotInitialized() {
    return PoseDetectionException(
      code: PoseDetectionErrorCode.cameraNotInitialized,
      message: 'Camera controller is not initialized',
    );
  }

  /// Factory for stream start failures
  factory PoseDetectionException.streamStartFailed([Object? cause]) {
    return PoseDetectionException(
      code: PoseDetectionErrorCode.streamStartFailed,
      message: 'Failed to start camera image stream',
      cause: cause,
    );
  }

  /// Factory for camera switch failures
  factory PoseDetectionException.cameraSwitchFailed([Object? cause]) {
    return PoseDetectionException(
      code: PoseDetectionErrorCode.cameraSwitchFailed,
      message: 'Failed to switch camera',
      cause: cause,
    );
  }

  /// Factory for ML Kit detection errors
  factory PoseDetectionException.mlKitDetectionFailed([Object? cause]) {
    return PoseDetectionException(
      code: PoseDetectionErrorCode.mlKitDetectionFailed,
      message: 'ML Kit pose detection failed',
      cause: cause,
    );
  }

  /// Factory for image conversion errors
  factory PoseDetectionException.imageConversionFailed([Object? cause]) {
    return PoseDetectionException(
      code: PoseDetectionErrorCode.imageConversionFailed,
      message: 'Failed to convert camera image',
      cause: cause,
    );
  }

  /// Factory for too many consecutive errors
  factory PoseDetectionException.tooManyErrors(int count, [Object? lastError]) {
    return PoseDetectionException(
      code: PoseDetectionErrorCode.tooManyConsecutiveErrors,
      message: 'Too many consecutive errors ($count)',
      cause: lastError,
    );
  }

  /// Factory for processing timeout
  factory PoseDetectionException.processingTimeout(Duration duration) {
    return PoseDetectionException(
      code: PoseDetectionErrorCode.processingTimeout,
      message: 'Frame processing timed out after ${duration.inMilliseconds}ms',
    );
  }

  /// Factory for unknown errors
  factory PoseDetectionException.unknown([Object? cause]) {
    return PoseDetectionException(
      code: PoseDetectionErrorCode.unknown,
      message: 'An unknown error occurred',
      cause: cause,
    );
  }

  /// Check if this error is recoverable (can retry)
  bool get isRecoverable {
    switch (code) {
      case PoseDetectionErrorCode.mlKitDetectionFailed:
      case PoseDetectionErrorCode.processingTimeout:
      case PoseDetectionErrorCode.unknown:
        return true;
      case PoseDetectionErrorCode.cameraInitFailed:
      case PoseDetectionErrorCode.cameraNotInitialized:
      case PoseDetectionErrorCode.streamStartFailed:
      case PoseDetectionErrorCode.cameraSwitchFailed:
      case PoseDetectionErrorCode.imageConversionFailed:
      case PoseDetectionErrorCode.tooManyConsecutiveErrors:
        return false;
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer('PoseDetectionException: $message');
    if (cause != null) {
      buffer.write(' (caused by: $cause)');
    }
    return buffer.toString();
  }
}
