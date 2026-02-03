import 'dart:math' as math;

/// Implementation of the 1€ Filter for noise reduction.
///
/// Based on the paper: "1€ Filter: A Simple Speed-based Low-pass Filter
/// for Noisy Input in Interactive Systems" by Géry Casiez, Nicolas Roussel,
/// and Daniel Vogel (CHI 2012).
///
/// The filter adapts its cutoff frequency based on signal speed:
/// - Slow movements → low cutoff → more smoothing
/// - Fast movements → high cutoff → less lag
///
/// This makes it ideal for real-time tracking where both jitter reduction
/// and responsiveness are important.
class OneEuroFilter {
  /// Minimum cutoff frequency (Hz).
  /// Lower = more smoothing, but more lag.
  final double minCutoff;

  /// Speed coefficient.
  /// Higher = less lag during fast movements.
  final double beta;

  /// Derivative cutoff frequency (Hz).
  /// Controls smoothing of the speed estimation.
  final double dCutoff;

  // Internal state
  double? _x;
  double? _dx;
  double? _lastTime;

  /// Creates a new OneEuroFilter.
  ///
  /// [minCutoff] - Minimum cutoff frequency. Default: 1.0
  /// [beta] - Speed coefficient. Default: 0.007
  /// [dCutoff] - Derivative cutoff frequency. Default: 1.0
  OneEuroFilter({
    this.minCutoff = 1.0,
    this.beta = 0.007,
    this.dCutoff = 1.0,
  });

  /// Filter a value at the given timestamp.
  ///
  /// [value] - The raw input value
  /// [timestamp] - Time in seconds (must be monotonically increasing)
  ///
  /// Returns the filtered value.
  double filter(double value, double timestamp) {
    if (_lastTime == null || _x == null) {
      // First sample - initialize
      _x = value;
      _dx = 0.0;
      _lastTime = timestamp;
      return value;
    }

    // Calculate time delta
    final dt = timestamp - _lastTime!;
    if (dt <= 0) {
      // Same or earlier timestamp - return last value
      return _x!;
    }
    _lastTime = timestamp;

    // Calculate frequency from time delta
    final freq = 1.0 / dt;

    // Estimate derivative (speed) of the signal
    final dx = (value - _x!) / dt;

    // Filter the derivative
    final alphaDx = _calculateAlpha(freq, dCutoff);
    _dx = _lowPassFilter(dx, _dx!, alphaDx);

    // Calculate adaptive cutoff based on filtered speed
    final cutoff = minCutoff + beta * _dx!.abs();

    // Filter the value with adaptive cutoff
    final alpha = _calculateAlpha(freq, cutoff);
    _x = _lowPassFilter(value, _x!, alpha);

    return _x!;
  }

  /// Reset the filter state.
  /// Call this when there's a discontinuity in the input
  /// (e.g., new tracking session, lost tracking).
  void reset() {
    _x = null;
    _dx = null;
    _lastTime = null;
  }

  /// Check if the filter has been initialized with at least one sample.
  bool get isInitialized => _x != null;

  /// Get the last filtered value, or null if not initialized.
  double? get lastValue => _x;

  /// Get the last estimated derivative (speed).
  double? get lastDerivative => _dx;

  /// Calculate smoothing factor alpha for given frequency and cutoff.
  double _calculateAlpha(double freq, double cutoff) {
    final tau = 1.0 / (2.0 * math.pi * cutoff);
    final te = 1.0 / freq;
    return 1.0 / (1.0 + tau / te);
  }

  /// Simple exponential low-pass filter.
  double _lowPassFilter(double x, double xPrev, double alpha) {
    return alpha * x + (1.0 - alpha) * xPrev;
  }
}

/// A set of OneEuroFilters for 3D coordinates.
/// Convenient for filtering landmark positions.
class OneEuroFilter3D {
  final OneEuroFilter _xFilter;
  final OneEuroFilter _yFilter;
  final OneEuroFilter _zFilter;

  OneEuroFilter3D({
    double minCutoff = 1.0,
    double beta = 0.007,
    double dCutoff = 1.0,
  })  : _xFilter = OneEuroFilter(
          minCutoff: minCutoff,
          beta: beta,
          dCutoff: dCutoff,
        ),
        _yFilter = OneEuroFilter(
          minCutoff: minCutoff,
          beta: beta,
          dCutoff: dCutoff,
        ),
        _zFilter = OneEuroFilter(
          minCutoff: minCutoff,
          beta: beta,
          dCutoff: dCutoff,
        );

  /// Filter 3D coordinates at the given timestamp.
  ///
  /// Returns a record with filtered (x, y, z) values.
  ({double x, double y, double z}) filter(
    double x,
    double y,
    double z,
    double timestamp,
  ) {
    return (
      x: _xFilter.filter(x, timestamp),
      y: _yFilter.filter(y, timestamp),
      z: _zFilter.filter(z, timestamp),
    );
  }

  /// Reset all filter states.
  void reset() {
    _xFilter.reset();
    _yFilter.reset();
    _zFilter.reset();
  }

  /// Check if filters have been initialized.
  bool get isInitialized => _xFilter.isInitialized;
}
