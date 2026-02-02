/// Generic ring buffer implementation with O(1) add operations.
/// Automatically evicts oldest items when capacity is reached.
class RingBuffer<T> {
  final int _capacity;
  final List<T?> _buffer;
  int _head = 0; // Next write position
  int _length = 0;

  RingBuffer(int capacity)
      : _capacity = capacity,
        _buffer = List<T?>.filled(capacity, null) {
    if (capacity <= 0) {
      throw ArgumentError('Capacity must be positive');
    }
  }

  /// Maximum capacity
  int get capacity => _capacity;

  /// Current number of items
  int get length => _length;

  /// Whether buffer is empty
  bool get isEmpty => _length == 0;

  /// Whether buffer is at capacity
  bool get isFull => _length >= _capacity;

  /// Get all items in chronological order (oldest first)
  List<T> get items {
    if (_length == 0) return [];

    final result = <T>[];
    final start = isFull ? _head : 0;

    for (int i = 0; i < _length; i++) {
      final index = (start + i) % _capacity;
      result.add(_buffer[index] as T);
    }

    return result;
  }

  /// Get most recent item
  T? get latest {
    if (_length == 0) return null;
    final index = (_head - 1 + _capacity) % _capacity;
    return _buffer[index];
  }

  /// Get oldest item
  T? get oldest {
    if (_length == 0) return null;
    final index = isFull ? _head : 0;
    return _buffer[index];
  }

  /// Add item to buffer. O(1) operation.
  void add(T item) {
    _buffer[_head] = item;
    _head = (_head + 1) % _capacity;
    if (_length < _capacity) {
      _length++;
    }
  }

  /// Clear all items
  void clear() {
    for (int i = 0; i < _capacity; i++) {
      _buffer[i] = null;
    }
    _head = 0;
    _length = 0;
  }

  /// Access item by index (0 = oldest)
  T? operator [](int index) {
    if (index < 0 || index >= _length) return null;
    final start = isFull ? _head : 0;
    final actualIndex = (start + index) % _capacity;
    return _buffer[actualIndex];
  }
}
