import 'dart:ui';

import 'package:pose_detection/features/anatomy/domain/entities/muscle_group.dart';

/// Path segment types for building muscle shapes.
sealed class PathSegment {
  const PathSegment();
}

class MoveTo extends PathSegment {
  final double x, y;
  const MoveTo(this.x, this.y);
}

class LineTo extends PathSegment {
  final double x, y;
  const LineTo(this.x, this.y);
}

class CubicTo extends PathSegment {
  final double x1, y1, x2, y2, x3, y3;
  const CubicTo(this.x1, this.y1, this.x2, this.y2, this.x3, this.y3);
}

/// Normalized path definition for a muscle region.
///
/// All coordinates are in 0.0–1.0 space, scaled to widget size at paint time.
class MusclePathDefinition {
  final String muscleId;
  final BodyView view;
  final List<PathSegment> segments;

  const MusclePathDefinition({
    required this.muscleId,
    required this.view,
    required this.segments,
  });

  /// Build a Flutter [Path] scaled to [size].
  Path buildPath(Size size) {
    final path = Path();
    for (final seg in segments) {
      switch (seg) {
        case MoveTo(:final x, :final y):
          path.moveTo(x * size.width, y * size.height);
        case LineTo(:final x, :final y):
          path.lineTo(x * size.width, y * size.height);
        case CubicTo(:final x1, :final y1, :final x2, :final y2, :final x3, :final y3):
          path.cubicTo(
            x1 * size.width, y1 * size.height,
            x2 * size.width, y2 * size.height,
            x3 * size.width, y3 * size.height,
          );
      }
    }
    path.close();
    return path;
  }

  /// Create a mirrored copy (left↔right) by reflecting x-coordinates.
  MusclePathDefinition mirrored(String newMuscleId) {
    return MusclePathDefinition(
      muscleId: newMuscleId,
      view: view,
      segments: segments.map((seg) {
        return switch (seg) {
          MoveTo(:final x, :final y) => MoveTo(1.0 - x, y),
          LineTo(:final x, :final y) => LineTo(1.0 - x, y),
          CubicTo(:final x1, :final y1, :final x2, :final y2, :final x3, :final y3) =>
            CubicTo(1.0 - x1, y1, 1.0 - x2, y2, 1.0 - x3, y3),
        };
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BODY SILHOUETTE — outline providing anatomical context
// ═══════════════════════════════════════════════════════════════════

/// Front body silhouette outline (normalized 0–1).
const frontSilhouette = [
  // Head
  MoveTo(0.50, 0.000),
  CubicTo(0.44, 0.000, 0.39, 0.015, 0.39, 0.045),
  CubicTo(0.39, 0.075, 0.42, 0.090, 0.42, 0.090),
  // Neck left
  LineTo(0.43, 0.110),
  // Left shoulder
  CubicTo(0.38, 0.120, 0.28, 0.135, 0.23, 0.160),
  CubicTo(0.18, 0.180, 0.16, 0.195, 0.16, 0.195),
  // Left arm
  CubicTo(0.14, 0.220, 0.13, 0.260, 0.13, 0.290),
  CubicTo(0.13, 0.320, 0.12, 0.350, 0.12, 0.370),
  // Left elbow
  CubicTo(0.12, 0.390, 0.11, 0.400, 0.11, 0.410),
  // Left forearm
  CubicTo(0.11, 0.430, 0.10, 0.460, 0.10, 0.490),
  // Left hand
  CubicTo(0.10, 0.510, 0.09, 0.530, 0.09, 0.540),
  CubicTo(0.09, 0.550, 0.10, 0.555, 0.11, 0.550),
  CubicTo(0.12, 0.545, 0.13, 0.530, 0.13, 0.510),
  CubicTo(0.14, 0.490, 0.14, 0.470, 0.15, 0.450),
  // Left torso
  CubicTo(0.17, 0.430, 0.20, 0.420, 0.22, 0.410),
  CubicTo(0.24, 0.400, 0.26, 0.395, 0.28, 0.395),
  // Left hip
  CubicTo(0.28, 0.410, 0.27, 0.440, 0.27, 0.460),
  CubicTo(0.27, 0.480, 0.27, 0.495, 0.28, 0.510),
  // Left upper leg
  CubicTo(0.28, 0.540, 0.27, 0.580, 0.27, 0.620),
  CubicTo(0.27, 0.660, 0.27, 0.700, 0.28, 0.730),
  // Left knee
  CubicTo(0.28, 0.745, 0.28, 0.755, 0.28, 0.770),
  // Left lower leg
  CubicTo(0.28, 0.800, 0.27, 0.840, 0.27, 0.880),
  // Left ankle/foot
  CubicTo(0.27, 0.910, 0.26, 0.940, 0.25, 0.960),
  CubicTo(0.25, 0.975, 0.26, 0.990, 0.28, 0.995),
  CubicTo(0.30, 1.000, 0.33, 0.995, 0.34, 0.985),
  CubicTo(0.35, 0.975, 0.35, 0.960, 0.34, 0.945),
  // Inner left leg going up
  CubicTo(0.34, 0.910, 0.35, 0.870, 0.35, 0.830),
  CubicTo(0.35, 0.790, 0.35, 0.760, 0.36, 0.730),
  CubicTo(0.37, 0.700, 0.38, 0.660, 0.38, 0.620),
  CubicTo(0.38, 0.580, 0.39, 0.540, 0.40, 0.510),
  // Crotch
  CubicTo(0.42, 0.500, 0.46, 0.495, 0.50, 0.495),
  // Right inner leg going down (mirror)
  CubicTo(0.54, 0.495, 0.58, 0.500, 0.60, 0.510),
  CubicTo(0.61, 0.540, 0.62, 0.580, 0.62, 0.620),
  CubicTo(0.62, 0.660, 0.63, 0.700, 0.64, 0.730),
  CubicTo(0.65, 0.760, 0.65, 0.790, 0.65, 0.830),
  CubicTo(0.65, 0.870, 0.66, 0.910, 0.66, 0.945),
  // Right ankle/foot
  CubicTo(0.65, 0.960, 0.65, 0.975, 0.66, 0.985),
  CubicTo(0.67, 0.995, 0.70, 1.000, 0.72, 0.995),
  CubicTo(0.74, 0.990, 0.75, 0.975, 0.75, 0.960),
  CubicTo(0.74, 0.940, 0.73, 0.910, 0.73, 0.880),
  // Right lower leg
  CubicTo(0.73, 0.840, 0.72, 0.800, 0.72, 0.770),
  // Right knee
  CubicTo(0.72, 0.755, 0.72, 0.745, 0.72, 0.730),
  // Right upper leg
  CubicTo(0.73, 0.700, 0.73, 0.660, 0.73, 0.620),
  CubicTo(0.73, 0.580, 0.72, 0.540, 0.72, 0.510),
  // Right hip
  CubicTo(0.73, 0.495, 0.73, 0.480, 0.73, 0.460),
  CubicTo(0.73, 0.440, 0.72, 0.410, 0.72, 0.395),
  // Right torso
  CubicTo(0.74, 0.395, 0.76, 0.400, 0.78, 0.410),
  CubicTo(0.80, 0.420, 0.83, 0.430, 0.85, 0.450),
  // Right forearm going up
  CubicTo(0.86, 0.470, 0.86, 0.490, 0.87, 0.510),
  CubicTo(0.87, 0.530, 0.88, 0.545, 0.89, 0.550),
  CubicTo(0.90, 0.555, 0.91, 0.550, 0.91, 0.540),
  CubicTo(0.91, 0.530, 0.90, 0.510, 0.90, 0.490),
  // Right forearm
  CubicTo(0.90, 0.460, 0.89, 0.430, 0.89, 0.410),
  // Right elbow
  CubicTo(0.89, 0.400, 0.88, 0.390, 0.88, 0.370),
  // Right upper arm
  CubicTo(0.88, 0.350, 0.87, 0.320, 0.87, 0.290),
  CubicTo(0.87, 0.260, 0.86, 0.220, 0.84, 0.195),
  // Right shoulder
  CubicTo(0.84, 0.195, 0.82, 0.180, 0.77, 0.160),
  CubicTo(0.72, 0.135, 0.62, 0.120, 0.57, 0.110),
  // Neck right
  LineTo(0.58, 0.090),
  CubicTo(0.58, 0.090, 0.61, 0.075, 0.61, 0.045),
  CubicTo(0.61, 0.015, 0.56, 0.000, 0.50, 0.000),
];

/// Back body silhouette outline (normalized 0–1).
/// Same proportions as front — symmetric body shape.
const backSilhouette = frontSilhouette;

// ═══════════════════════════════════════════════════════════════════
// FRONT MUSCLE PATHS
// ═══════════════════════════════════════════════════════════════════

/// Left pectoral muscle.
const _chestLeftPath = MusclePathDefinition(
  muscleId: 'chest',
  view: BodyView.front,
  segments: [
    // Upper chest near clavicle
    MoveTo(0.44, 0.145),
    CubicTo(0.40, 0.150, 0.33, 0.165, 0.28, 0.180),
    // Outer edge down along shoulder/arm
    CubicTo(0.25, 0.195, 0.23, 0.215, 0.22, 0.240),
    // Lower edge of pec
    CubicTo(0.23, 0.265, 0.28, 0.280, 0.34, 0.280),
    // Inner edge along sternum
    CubicTo(0.38, 0.275, 0.42, 0.250, 0.44, 0.220),
    // Back up to start
    CubicTo(0.44, 0.195, 0.44, 0.170, 0.44, 0.145),
  ],
);

/// Right pectoral (mirrored).
final _chestRightPath = _chestLeftPath.mirrored('chest');

/// Left deltoid (shoulder), front view.
const _shoulderLeftFrontPath = MusclePathDefinition(
  muscleId: 'shoulders',
  view: BodyView.front,
  segments: [
    MoveTo(0.28, 0.150),
    CubicTo(0.24, 0.160, 0.20, 0.175, 0.18, 0.195),
    CubicTo(0.16, 0.215, 0.16, 0.240, 0.17, 0.260),
    CubicTo(0.18, 0.270, 0.20, 0.265, 0.22, 0.250),
    CubicTo(0.24, 0.235, 0.26, 0.210, 0.27, 0.190),
    CubicTo(0.28, 0.175, 0.28, 0.160, 0.28, 0.150),
  ],
);

/// Right deltoid (mirrored).
final _shoulderRightFrontPath = _shoulderLeftFrontPath.mirrored('shoulders');

/// Left biceps.
const _bicepsLeftPath = MusclePathDefinition(
  muscleId: 'biceps',
  view: BodyView.front,
  segments: [
    MoveTo(0.17, 0.260),
    CubicTo(0.16, 0.280, 0.15, 0.310, 0.14, 0.340),
    CubicTo(0.14, 0.360, 0.13, 0.380, 0.13, 0.395),
    CubicTo(0.15, 0.395, 0.17, 0.385, 0.19, 0.370),
    CubicTo(0.20, 0.345, 0.20, 0.310, 0.20, 0.280),
    CubicTo(0.19, 0.270, 0.18, 0.265, 0.17, 0.260),
  ],
);

/// Right biceps (mirrored).
final _bicepsRightPath = _bicepsLeftPath.mirrored('biceps');

/// Left forearm, front view.
const _forearmLeftPath = MusclePathDefinition(
  muscleId: 'forearms',
  view: BodyView.front,
  segments: [
    MoveTo(0.13, 0.400),
    CubicTo(0.12, 0.420, 0.12, 0.445, 0.11, 0.470),
    CubicTo(0.11, 0.490, 0.10, 0.510, 0.10, 0.520),
    CubicTo(0.12, 0.520, 0.13, 0.510, 0.14, 0.490),
    CubicTo(0.15, 0.465, 0.16, 0.440, 0.16, 0.420),
    CubicTo(0.16, 0.410, 0.15, 0.400, 0.13, 0.400),
  ],
);

/// Right forearm (mirrored).
final _forearmRightPath = _forearmLeftPath.mirrored('forearms');

/// Rectus abdominis (center).
const _absPath = MusclePathDefinition(
  muscleId: 'abs',
  view: BodyView.front,
  segments: [
    MoveTo(0.43, 0.260),
    CubicTo(0.42, 0.290, 0.41, 0.330, 0.40, 0.370),
    CubicTo(0.39, 0.400, 0.38, 0.430, 0.38, 0.460),
    // Bottom
    CubicTo(0.40, 0.475, 0.46, 0.485, 0.50, 0.485),
    CubicTo(0.54, 0.485, 0.60, 0.475, 0.62, 0.460),
    // Right side going up
    CubicTo(0.62, 0.430, 0.61, 0.400, 0.60, 0.370),
    CubicTo(0.59, 0.330, 0.58, 0.290, 0.57, 0.260),
    // Top
    CubicTo(0.55, 0.255, 0.52, 0.250, 0.50, 0.250),
    CubicTo(0.48, 0.250, 0.45, 0.255, 0.43, 0.260),
  ],
);

/// Left obliques.
const _obliquesLeftPath = MusclePathDefinition(
  muscleId: 'obliques',
  view: BodyView.front,
  segments: [
    MoveTo(0.28, 0.290),
    CubicTo(0.26, 0.320, 0.25, 0.360, 0.25, 0.390),
    CubicTo(0.26, 0.420, 0.27, 0.440, 0.29, 0.460),
    CubicTo(0.32, 0.475, 0.35, 0.480, 0.38, 0.470),
    CubicTo(0.38, 0.440, 0.39, 0.400, 0.40, 0.370),
    CubicTo(0.40, 0.340, 0.41, 0.310, 0.41, 0.280),
    CubicTo(0.38, 0.275, 0.33, 0.280, 0.28, 0.290),
  ],
);

/// Right obliques (mirrored).
final _obliquesRightPath = _obliquesLeftPath.mirrored('obliques');

/// Left quadriceps.
const _quadsLeftPath = MusclePathDefinition(
  muscleId: 'quads',
  view: BodyView.front,
  segments: [
    MoveTo(0.30, 0.500),
    CubicTo(0.29, 0.530, 0.28, 0.570, 0.28, 0.610),
    CubicTo(0.28, 0.650, 0.28, 0.690, 0.29, 0.720),
    // Knee area
    CubicTo(0.30, 0.735, 0.33, 0.740, 0.36, 0.735),
    // Inner edge going up
    CubicTo(0.37, 0.710, 0.38, 0.670, 0.38, 0.630),
    CubicTo(0.38, 0.590, 0.39, 0.550, 0.40, 0.510),
    // Hip area
    CubicTo(0.38, 0.500, 0.34, 0.495, 0.30, 0.500),
  ],
);

/// Right quadriceps (mirrored).
final _quadsRightPath = _quadsLeftPath.mirrored('quads');

// ═══════════════════════════════════════════════════════════════════
// BACK MUSCLE PATHS
// ═══════════════════════════════════════════════════════════════════

/// Trapezius (center, upper back).
const _trapsPath = MusclePathDefinition(
  muscleId: 'traps',
  view: BodyView.back,
  segments: [
    // Top center (neck)
    MoveTo(0.46, 0.100),
    CubicTo(0.44, 0.110, 0.40, 0.120, 0.35, 0.135),
    // Out to left shoulder
    CubicTo(0.30, 0.150, 0.26, 0.160, 0.24, 0.170),
    // Down along shoulder blade
    CubicTo(0.27, 0.195, 0.32, 0.215, 0.38, 0.230),
    // Lower trap to spine
    CubicTo(0.42, 0.240, 0.46, 0.260, 0.50, 0.270),
    // Mirror right side
    CubicTo(0.54, 0.260, 0.58, 0.240, 0.62, 0.230),
    CubicTo(0.68, 0.215, 0.73, 0.195, 0.76, 0.170),
    // Right shoulder
    CubicTo(0.74, 0.160, 0.70, 0.150, 0.65, 0.135),
    CubicTo(0.60, 0.120, 0.56, 0.110, 0.54, 0.100),
    // Back to top
    CubicTo(0.52, 0.098, 0.48, 0.098, 0.46, 0.100),
  ],
);

/// Left latissimus dorsi.
const _latsLeftPath = MusclePathDefinition(
  muscleId: 'lats',
  view: BodyView.back,
  segments: [
    // Upper connection near armpit
    MoveTo(0.24, 0.200),
    CubicTo(0.22, 0.230, 0.21, 0.270, 0.22, 0.310),
    CubicTo(0.23, 0.340, 0.25, 0.370, 0.28, 0.390),
    // Lower lat going inward
    CubicTo(0.32, 0.400, 0.37, 0.395, 0.42, 0.380),
    // Inner edge along spine going up
    CubicTo(0.42, 0.340, 0.41, 0.300, 0.40, 0.260),
    CubicTo(0.37, 0.240, 0.32, 0.220, 0.28, 0.210),
    CubicTo(0.26, 0.205, 0.25, 0.202, 0.24, 0.200),
  ],
);

/// Right latissimus (mirrored).
final _latsRightPath = _latsLeftPath.mirrored('lats');

/// Left triceps (back view).
const _tricepsLeftPath = MusclePathDefinition(
  muscleId: 'triceps',
  view: BodyView.back,
  segments: [
    MoveTo(0.17, 0.260),
    CubicTo(0.16, 0.280, 0.15, 0.310, 0.14, 0.340),
    CubicTo(0.14, 0.360, 0.13, 0.380, 0.13, 0.395),
    CubicTo(0.15, 0.395, 0.17, 0.385, 0.19, 0.370),
    CubicTo(0.20, 0.345, 0.20, 0.310, 0.20, 0.280),
    CubicTo(0.19, 0.270, 0.18, 0.265, 0.17, 0.260),
  ],
);

/// Right triceps (mirrored).
final _tricepsRightPath = _tricepsLeftPath.mirrored('triceps');

/// Lower back (erector spinae).
const _lowerBackPath = MusclePathDefinition(
  muscleId: 'lower_back',
  view: BodyView.back,
  segments: [
    MoveTo(0.38, 0.330),
    CubicTo(0.36, 0.360, 0.34, 0.390, 0.33, 0.420),
    CubicTo(0.34, 0.450, 0.38, 0.470, 0.44, 0.475),
    // Center bottom
    CubicTo(0.47, 0.478, 0.50, 0.480, 0.53, 0.478),
    CubicTo(0.56, 0.475, 0.62, 0.470, 0.66, 0.450),
    CubicTo(0.67, 0.420, 0.66, 0.390, 0.64, 0.360),
    // Top center
    CubicTo(0.62, 0.330, 0.58, 0.310, 0.50, 0.300),
    CubicTo(0.42, 0.310, 0.40, 0.320, 0.38, 0.330),
  ],
);

/// Left gluteus.
const _glutesLeftPath = MusclePathDefinition(
  muscleId: 'glutes',
  view: BodyView.back,
  segments: [
    MoveTo(0.30, 0.460),
    CubicTo(0.28, 0.480, 0.27, 0.505, 0.28, 0.530),
    CubicTo(0.29, 0.555, 0.33, 0.570, 0.38, 0.565),
    CubicTo(0.42, 0.560, 0.46, 0.540, 0.48, 0.510),
    CubicTo(0.48, 0.490, 0.46, 0.475, 0.42, 0.465),
    CubicTo(0.38, 0.458, 0.34, 0.458, 0.30, 0.460),
  ],
);

/// Right gluteus (mirrored).
final _glutesRightPath = _glutesLeftPath.mirrored('glutes');

/// Left hamstring.
const _hamstringsLeftPath = MusclePathDefinition(
  muscleId: 'hamstrings',
  view: BodyView.back,
  segments: [
    MoveTo(0.29, 0.545),
    CubicTo(0.28, 0.580, 0.28, 0.620, 0.28, 0.660),
    CubicTo(0.28, 0.690, 0.29, 0.720, 0.30, 0.740),
    CubicTo(0.33, 0.745, 0.35, 0.740, 0.37, 0.730),
    CubicTo(0.38, 0.700, 0.38, 0.660, 0.38, 0.620),
    CubicTo(0.38, 0.590, 0.38, 0.565, 0.37, 0.550),
    CubicTo(0.35, 0.545, 0.32, 0.543, 0.29, 0.545),
  ],
);

/// Right hamstring (mirrored).
final _hamstringsRightPath = _hamstringsLeftPath.mirrored('hamstrings');

/// Left calf.
const _calvesLeftPath = MusclePathDefinition(
  muscleId: 'calves',
  view: BodyView.back,
  segments: [
    MoveTo(0.29, 0.770),
    CubicTo(0.28, 0.800, 0.28, 0.835, 0.28, 0.860),
    CubicTo(0.28, 0.880, 0.29, 0.895, 0.30, 0.900),
    CubicTo(0.32, 0.900, 0.34, 0.895, 0.35, 0.880),
    CubicTo(0.35, 0.855, 0.35, 0.825, 0.35, 0.795),
    CubicTo(0.35, 0.780, 0.34, 0.770, 0.32, 0.768),
    CubicTo(0.31, 0.768, 0.30, 0.769, 0.29, 0.770),
  ],
);

/// Right calf (mirrored).
final _calvesRightPath = _calvesLeftPath.mirrored('calves');

/// Back-view shoulder (deltoid posterior).
const _shoulderLeftBackPath = MusclePathDefinition(
  muscleId: 'shoulders',
  view: BodyView.back,
  segments: [
    MoveTo(0.28, 0.150),
    CubicTo(0.24, 0.160, 0.20, 0.175, 0.18, 0.195),
    CubicTo(0.16, 0.215, 0.16, 0.240, 0.17, 0.260),
    CubicTo(0.18, 0.270, 0.20, 0.265, 0.22, 0.250),
    CubicTo(0.24, 0.235, 0.26, 0.210, 0.27, 0.190),
    CubicTo(0.28, 0.175, 0.28, 0.160, 0.28, 0.150),
  ],
);

/// Right shoulder back (mirrored).
final _shoulderRightBackPath = _shoulderLeftBackPath.mirrored('shoulders');

// ═══════════════════════════════════════════════════════════════════
// PUBLIC API — All path definitions grouped by view
// ═══════════════════════════════════════════════════════════════════

/// All muscle path definitions for the front body view.
final List<MusclePathDefinition> frontMusclePaths = [
  _chestLeftPath,
  _chestRightPath,
  _shoulderLeftFrontPath,
  _shoulderRightFrontPath,
  _bicepsLeftPath,
  _bicepsRightPath,
  _forearmLeftPath,
  _forearmRightPath,
  _absPath,
  _obliquesLeftPath,
  _obliquesRightPath,
  _quadsLeftPath,
  _quadsRightPath,
];

/// All muscle path definitions for the back body view.
final List<MusclePathDefinition> backMusclePaths = [
  _trapsPath,
  _latsLeftPath,
  _latsRightPath,
  _tricepsLeftPath,
  _tricepsRightPath,
  _shoulderLeftBackPath,
  _shoulderRightBackPath,
  _lowerBackPath,
  _glutesLeftPath,
  _glutesRightPath,
  _hamstringsLeftPath,
  _hamstringsRightPath,
  _calvesLeftPath,
  _calvesRightPath,
];

/// Get muscle paths for a given body view.
List<MusclePathDefinition> getMusclePathsForView(BodyView view) {
  return switch (view) {
    BodyView.front => frontMusclePaths,
    BodyView.back => backMusclePaths,
  };
}

/// Get the body silhouette segments for a given body view.
List<PathSegment> getSilhouetteForView(BodyView view) {
  return switch (view) {
    BodyView.front => frontSilhouette,
    BodyView.back => backSilhouette,
  };
}

/// Build a silhouette [Path] scaled to [size].
Path buildSilhouettePath(List<PathSegment> segments, Size size) {
  final path = Path();
  for (final seg in segments) {
    switch (seg) {
      case MoveTo(:final x, :final y):
        path.moveTo(x * size.width, y * size.height);
      case LineTo(:final x, :final y):
        path.lineTo(x * size.width, y * size.height);
      case CubicTo(:final x1, :final y1, :final x2, :final y2, :final x3, :final y3):
        path.cubicTo(
          x1 * size.width, y1 * size.height,
          x2 * size.width, y2 * size.height,
          x3 * size.width, y3 * size.height,
        );
    }
  }
  path.close();
  return path;
}
