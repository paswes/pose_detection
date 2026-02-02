/// Time-based rolling window for chart data
/// Stores samples with timestamps for time-series visualization
class RollingWindow<T> {
  final Duration windowDuration;
  final List<({T value, int timestampMicros})> _samples = [];

  RollingWindow({required this.windowDuration});

  /// Add a sample with its timestamp
  void add(T value, int timestampMicros) {
    _samples.add((value: value, timestampMicros: timestampMicros));
    _pruneOldSamples(timestampMicros);
  }

  /// Get all samples within the window
  List<({T value, int timestampMicros})> get samples =>
      List.unmodifiable(_samples);

  /// Get just the values (without timestamps)
  List<T> get values => _samples.map((s) => s.value).toList();

  /// Number of samples in window
  int get length => _samples.length;

  /// Check if window is empty
  bool get isEmpty => _samples.isEmpty;

  /// Check if window has samples
  bool get isNotEmpty => _samples.isNotEmpty;

  /// Most recent value (or null if empty)
  T? get latest => _samples.isNotEmpty ? _samples.last.value : null;

  /// Oldest value in window (or null if empty)
  T? get oldest => _samples.isNotEmpty ? _samples.first.value : null;

  /// Clear all samples
  void clear() => _samples.clear();

  /// Remove samples older than window duration
  void _pruneOldSamples(int currentTimestampMicros) {
    final cutoff = currentTimestampMicros - windowDuration.inMicroseconds;
    _samples.removeWhere((s) => s.timestampMicros < cutoff);
  }

  /// Get samples as normalized time series (0.0 = oldest, 1.0 = newest)
  /// Useful for chart rendering
  List<({double normalizedTime, T value})> getNormalizedTimeSeries() {
    if (_samples.isEmpty) return [];
    if (_samples.length == 1) {
      return [(normalizedTime: 1.0, value: _samples.first.value)];
    }

    final oldest = _samples.first.timestampMicros;
    final newest = _samples.last.timestampMicros;
    final range = newest - oldest;

    if (range == 0) {
      return _samples.map((s) => (normalizedTime: 1.0, value: s.value)).toList();
    }

    return _samples.map((s) {
      final normalizedTime = (s.timestampMicros - oldest) / range;
      return (normalizedTime: normalizedTime, value: s.value);
    }).toList();
  }

  /// Calculate average (only works for numeric types)
  double average() {
    if (_samples.isEmpty) return 0;
    if (T == double) {
      final sum = _samples.fold(0.0, (acc, s) => acc + (s.value as double));
      return sum / _samples.length;
    }
    if (T == int) {
      final sum = _samples.fold(0, (acc, s) => acc + (s.value as int));
      return sum / _samples.length;
    }
    return 0;
  }

}

/// Specialized rolling window for double values with statistics
class RollingDoubleWindow extends RollingWindow<double> {
  RollingDoubleWindow({required super.windowDuration});

  /// Get minimum value in window
  double? get min {
    if (isEmpty) return null;
    return values.reduce((a, b) => a < b ? a : b);
  }

  /// Get maximum value in window
  double? get max {
    if (isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }
}
