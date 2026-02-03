import 'package:pose_detection/domain/motion/models/joint_angle.dart';
import 'package:pose_detection/domain/motion/models/range_of_motion.dart';

/// Service for tracking and analyzing range of motion for joints.
///
/// Accumulates angle measurements over time to determine the ROM
/// for each tracked joint. Exercise-agnostic - measures movement
/// range without knowledge of specific exercises.
class RangeOfMotionAnalyzer {
  /// Current ROM tracking for each joint
  final Map<String, RangeOfMotion> _romData = {};

  /// Whether to auto-reset ROM tracking on large time gaps
  final bool autoResetOnGap;

  /// Maximum gap before auto-reset (microseconds)
  final int maxGapMicros;

  /// Minimum confidence required to update ROM
  final double minConfidence;

  /// Last update timestamp for gap detection
  int? _lastUpdateMicros;

  RangeOfMotionAnalyzer({
    this.autoResetOnGap = true,
    this.maxGapMicros = 2000000, // 2 seconds
    this.minConfidence = 0.5,
  });

  /// Update ROM tracking with new joint angles.
  ///
  /// [angles] - Map of joint IDs to their current angles
  ///
  /// Returns the updated ROM data for all tracked joints.
  Map<String, RangeOfMotion> updateAngles(Map<String, JointAngle> angles) {
    if (angles.isEmpty) return Map.unmodifiable(_romData);

    // Check for time gap (session break detection)
    final now = angles.values.first.timestampMicros;
    if (autoResetOnGap && _lastUpdateMicros != null) {
      final gap = now - _lastUpdateMicros!;
      if (gap > maxGapMicros || gap < 0) {
        reset();
      }
    }
    _lastUpdateMicros = now;

    // Update ROM for each angle
    for (final entry in angles.entries) {
      final jointId = entry.key;
      final angle = entry.value;

      // Skip low confidence angles
      if (angle.confidence < minConfidence) continue;

      final existingRom = _romData[jointId];
      if (existingRom == null) {
        // First measurement for this joint
        _romData[jointId] = RangeOfMotion.initial(
          jointId: jointId,
          radians: angle.radians,
          timestampMicros: angle.timestampMicros,
          confidence: angle.confidence,
        );
      } else {
        // Update existing ROM
        _romData[jointId] = existingRom.update(
          radians: angle.radians,
          timestampMicros: angle.timestampMicros,
          confidence: angle.confidence,
        );
      }
    }

    return Map.unmodifiable(_romData);
  }

  /// Get ROM for a specific joint
  RangeOfMotion? getRom(String jointId) => _romData[jointId];

  /// Get all current ROM data
  Map<String, RangeOfMotion> get allRom => Map.unmodifiable(_romData);

  /// Get ROM data only for joints with meaningful movement
  Map<String, RangeOfMotion> get meaningfulRom {
    return Map.fromEntries(
      _romData.entries.where((e) => e.value.hasMeaningfulData),
    );
  }

  /// Get the joint with the largest ROM
  RangeOfMotion? get largestRom {
    if (_romData.isEmpty) return null;

    RangeOfMotion? largest;
    double maxRange = 0;

    for (final rom in _romData.values) {
      if (rom.rangeRadians > maxRange) {
        maxRange = rom.rangeRadians;
        largest = rom;
      }
    }

    return largest;
  }

  /// Get the joint with the smallest meaningful ROM
  RangeOfMotion? get smallestMeaningfulRom {
    final meaningful = meaningfulRom.values.toList();
    if (meaningful.isEmpty) return null;

    RangeOfMotion? smallest;
    double minRange = double.infinity;

    for (final rom in meaningful) {
      if (rom.rangeRadians < minRange) {
        minRange = rom.rangeRadians;
        smallest = rom;
      }
    }

    return smallest;
  }

  /// Get average ROM across all tracked joints
  double get averageRomRadians {
    if (_romData.isEmpty) return 0;

    double total = 0;
    for (final rom in _romData.values) {
      total += rom.rangeRadians;
    }

    return total / _romData.length;
  }

  /// Get average ROM in degrees
  double get averageRomDegrees => averageRomRadians * 180 / 3.14159265359;

  /// Check if a joint has reached a minimum ROM threshold
  bool hasReachedRom(String jointId, double minRadians) {
    final rom = _romData[jointId];
    if (rom == null) return false;
    return rom.rangeRadians >= minRadians;
  }

  /// Get ROM categorization for a joint
  RangeOfMotionCategory? getRomCategory(String jointId) {
    return _romData[jointId]?.category;
  }

  /// Get summary statistics
  RomSummary getSummary() {
    final roms = _romData.values.toList();
    if (roms.isEmpty) {
      return const RomSummary(
        jointCount: 0,
        averageRomDegrees: 0,
        minRomDegrees: 0,
        maxRomDegrees: 0,
        totalSamples: 0,
        durationSeconds: 0,
      );
    }

    double totalRom = 0;
    double minRom = double.infinity;
    double maxRom = 0;
    int totalSamples = 0;
    int earliestStart = roms.first.startTimestampMicros;
    int latestEnd = roms.first.lastUpdateTimestampMicros;

    for (final rom in roms) {
      totalRom += rom.rangeDegrees;
      if (rom.rangeDegrees < minRom) minRom = rom.rangeDegrees;
      if (rom.rangeDegrees > maxRom) maxRom = rom.rangeDegrees;
      totalSamples += rom.sampleCount;
      if (rom.startTimestampMicros < earliestStart) {
        earliestStart = rom.startTimestampMicros;
      }
      if (rom.lastUpdateTimestampMicros > latestEnd) {
        latestEnd = rom.lastUpdateTimestampMicros;
      }
    }

    return RomSummary(
      jointCount: roms.length,
      averageRomDegrees: totalRom / roms.length,
      minRomDegrees: minRom == double.infinity ? 0 : minRom,
      maxRomDegrees: maxRom,
      totalSamples: totalSamples,
      durationSeconds: (latestEnd - earliestStart) / 1000000.0,
    );
  }

  /// Reset all ROM tracking
  void reset() {
    _romData.clear();
    _lastUpdateMicros = null;
  }

  /// Reset ROM tracking for a specific joint
  void resetJoint(String jointId) {
    _romData.remove(jointId);
  }

  /// Start a new tracking session (resets all data)
  void startNewSession() {
    reset();
  }
}

/// Summary statistics for ROM analysis
class RomSummary {
  /// Number of joints being tracked
  final int jointCount;

  /// Average ROM across all joints (degrees)
  final double averageRomDegrees;

  /// Minimum ROM across all joints (degrees)
  final double minRomDegrees;

  /// Maximum ROM across all joints (degrees)
  final double maxRomDegrees;

  /// Total number of angle samples across all joints
  final int totalSamples;

  /// Duration of tracking (seconds)
  final double durationSeconds;

  const RomSummary({
    required this.jointCount,
    required this.averageRomDegrees,
    required this.minRomDegrees,
    required this.maxRomDegrees,
    required this.totalSamples,
    required this.durationSeconds,
  });

  @override
  String toString() =>
      'RomSummary(joints: $jointCount, avg: ${averageRomDegrees.toStringAsFixed(1)}°, range: ${minRomDegrees.toStringAsFixed(1)}°-${maxRomDegrees.toStringAsFixed(1)}°)';
}

/// Interface for ROM analysis
abstract class IRangeOfMotionAnalyzer {
  Map<String, RangeOfMotion> updateAngles(Map<String, JointAngle> angles);
  RangeOfMotion? getRom(String jointId);
  Map<String, RangeOfMotion> get allRom;
  RomSummary getSummary();
  void reset();
}
