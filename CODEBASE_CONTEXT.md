# Human Motion Tracking - Codebase Context

> **Zweck**: Dieses Dokument dient als vollständiger Kontext für Claude Code Sessions.
> **Stand**: 2026-02-03 | **Branch**: `agnostic_motion_tracking`

---

## 1. Projekt-Übersicht

**Flutter-basiertes Human Motion Tracking System** mit folgenden Eigenschaften:

- **Provider-agnostisch**: Abstrahiert von ML Kit, kann auf MediaPipe etc. wechseln
- **Exercise-agnostisch**: Keine hardcodierten Übungen, nur geometrische Berechnungen
- **iOS-only**: Android-Support ist nicht im Scope
- **Clean Architecture**: Core → Domain → Presentation Layer

**Tech Stack:**
- Flutter/Dart 3
- BLoC Pattern (flutter_bloc)
- GetIt (Dependency Injection)
- Equatable (Value Equality)
- ML Kit Pose Detection (33 Landmarks)

---

## 2. Architektur & Verzeichnisstruktur

```
lib/
├── main.dart                              # App Entry Point
├── core/                                  # Infrastructure Layer
│   ├── config/
│   │   ├── pose_detection_config.dart     # Zentrale Config (Factory Constructors)
│   │   └── landmark_schema.dart           # ML Kit Schema Definition
│   ├── di/
│   │   └── service_locator.dart           # GetIt DI Setup
│   ├── errors/
│   │   └── pose_detection_errors.dart     # Enum-basierte Errors
│   ├── filters/
│   │   └── one_euro_filter.dart           # Jitter-Reduktion Filter
│   ├── interfaces/
│   │   ├── camera_service_interface.dart  # ICameraService
│   │   └── pose_detector_interface.dart   # IPoseDetector
│   ├── services/
│   │   ├── camera_service.dart            # Kamera-Steuerung
│   │   ├── pose_detection_service.dart    # ML Kit Wrapper
│   │   ├── pose_smoother.dart             # OneEuroFilter Anwendung
│   │   ├── frame_processor.dart           # Frame Pipeline
│   │   └── error_tracker.dart             # Circuit Breaker
│   ├── data_structures/
│   │   └── ring_buffer.dart               # O(1) FPS Berechnung
│   └── utils/
│       ├── coordinate_translator.dart     # Koordinaten-Transformation
│       ├── transform_calculator.dart      # Matrix-Berechnungen
│       └── logger.dart                    # Debug Logging
│
├── domain/                                # Domain Layer
│   ├── models/
│   │   ├── landmark.dart                  # Basis-Landmark Model
│   │   ├── landmark_type.dart             # 33 ML Kit Landmarks (Enum)
│   │   ├── body_joint.dart                # Semantische Gelenke (Enum)
│   │   ├── detected_pose.dart             # Pose Container
│   │   └── detection_metrics.dart         # FPS, Latency
│   └── motion/                            # Motion Analysis Sub-Domain
│       ├── motion.dart                    # Barrel Export
│       ├── models/
│       │   ├── joint_angle.dart           # Winkel-Model (Equatable)
│       │   ├── velocity.dart              # Geschwindigkeit (Equatable)
│       │   ├── range_of_motion.dart       # ROM Tracking (Equatable)
│       │   ├── vector3.dart               # 3D Vektor Mathematik
│       │   └── pose_sequence.dart         # Temporal Pose History
│       └── services/
│           ├── motion_analyzer.dart       # Facade Service
│           ├── angle_calculator.dart      # Winkelberechnungen
│           ├── velocity_tracker.dart      # Geschwindigkeits-Tracking
│           └── range_of_motion_analyzer.dart  # ROM Analyse
│
└── presentation/                          # UI Layer
    ├── bloc/
    │   ├── pose_detection_bloc.dart       # Haupt-BLoC
    │   ├── pose_detection_event.dart      # BLoC Events
    │   └── pose_detection_state.dart      # BLoC States
    ├── pages/
    │   └── capture_page.dart              # Kamera-Seite
    └── widgets/
        ├── camera_preview_widget.dart     # Kamera Preview
        └── pose_painter.dart              # Skeleton Overlay
```

---

## 3. Schlüssel-Konzepte

### 3.1 Config System (Factory Constructors)

```dart
// lib/core/config/pose_detection_config.dart
PoseDetectionConfig.defaultConfig()    // Standard-Einstellungen
PoseDetectionConfig.smoothVisuals()    // Mehr Smoothing
PoseDetectionConfig.responsive()       // Weniger Smoothing
PoseDetectionConfig.raw()              // Kein Smoothing

// lib/domain/motion/services/motion_analyzer.dart
MotionAnalyzerConfig.defaultConfig()   // Alle Features
MotionAnalyzerConfig.minimal()         // Nur Winkel
MotionAnalyzerConfig.fullAnalysis()    // Extended History
MotionAnalyzerConfig.romFocused()      // ROM Tracking
MotionAnalyzerConfig.velocityFocused() // Velocity Tracking
```

### 3.2 Semantische Enums

```dart
// lib/domain/models/landmark_type.dart - 33 ML Kit Landmarks
enum LandmarkType {
  nose(0), leftEyeInner(1), leftEye(2), leftEyeOuter(3),
  rightEyeInner(4), rightEye(5), rightEyeOuter(6),
  leftEar(7), rightEar(8), mouthLeft(9), mouthRight(10),
  leftShoulder(11), rightShoulder(12),
  leftElbow(13), rightElbow(14),
  leftWrist(15), rightWrist(16),
  leftPinky(17), rightPinky(18),
  leftIndex(19), rightIndex(20),
  leftThumb(21), rightThumb(22),
  leftHip(23), rightHip(24),
  leftKnee(25), rightKnee(26),
  leftAnkle(27), rightAnkle(28),
  leftHeel(29), rightHeel(30),
  leftFootIndex(31), rightFootIndex(32);

  final int id;
  static LandmarkType? fromId(int id);
}

// lib/domain/models/body_joint.dart - Semantische Gelenke
enum BodyJoint {
  leftElbow(first: LandmarkType.leftShoulder, vertex: LandmarkType.leftElbow, third: LandmarkType.leftWrist),
  rightElbow(...),
  leftShoulder(...),
  rightShoulder(...),
  leftHip(...),
  rightHip(...),
  leftKnee(...),
  rightKnee(...),
  leftAnkle(...),
  rightAnkle(...);

  static List<BodyJoint> get primaryJoints => [leftElbow, rightElbow, leftKnee, rightKnee, leftHip, rightHip];
}
```

### 3.3 Motion Analysis API

```dart
// Verwendung
final analyzer = MotionAnalyzer(config: MotionAnalyzerConfig.defaultConfig());
analyzer.startSession();

// Pro Frame
final result = analyzer.analyze(detectedPose);

// Zugriff auf Daten
result.angles['leftElbow']?.degrees           // Winkel in Grad
result.velocities[LandmarkType.leftWrist.id]  // Handgeschwindigkeit
result.rangeOfMotion['leftKnee']?.rangeDegrees // ROM in Grad

// Mit BodyJoint
final angle = angleCalculator.calculateFromBodyJoint(
  pose: pose,
  joint: BodyJoint.leftElbow,
);
```

### 3.4 Jitter-Reduktion (OneEuroFilter)

```dart
// Automatisch via PoseSmoother angewandt wenn smoothingEnabled: true
// Config in pose_detection_config.dart:
smoothingEnabled: true,           // Default: true
smoothingMinCutoff: 1.0,          // Frequenz-Cutoff
smoothingBeta: 0.007,             // Speed Coefficient
smoothingDerivativeCutoff: 1.0,   // Derivative Cutoff
```

### 3.5 Error Handling

```dart
// lib/core/errors/pose_detection_errors.dart
enum PoseDetectionErrorCode {
  cameraInitFailed,
  cameraNotInitialized,
  streamStartFailed,
  cameraSwitchFailed,
  mlKitDetectionFailed,
  imageConversionFailed,
  tooManyConsecutiveErrors,
  processingTimeout,
  unknown,
}

// Factory Methods
PoseDetectionException.cameraInitFailed(cause);
PoseDetectionException.mlKitDetectionFailed(cause);
exception.isRecoverable; // bool
```

---

## 4. Data Flow Pipeline

```
CameraService.startImageStream()
    ↓ 30 FPS
PoseDetectionBloc (droppable transformer)
    ↓
FrameProcessor.processFrame()
    ↓
PoseDetectionService.detectPose()  [ML Kit: 30-50ms]
    ↓
PoseSmoother.smooth()              [OneEuroFilter]
    ↓
MotionAnalyzer.analyze()           [Angles, Velocity, ROM]
    ↓
State Emission → UI
```

---

## 5. Dependency Injection

```dart
// lib/core/di/service_locator.dart
await initializeDependencies(
  config: PoseDetectionConfig.defaultConfig(),
  schema: LandmarkSchema.mlKit33,
  motionConfig: MotionAnalyzerConfig.defaultConfig(),
);

// Zugriff
sl<PoseDetectionBloc>()
sl<MotionAnalyzer>()
sl<PoseSmoother>()
```

---

## 6. Abgeschlossene Refactorings (Stand 2026-02-03)

| Änderung | Status | Dateien |
|----------|--------|---------|
| Factory Constructors statt static vars | ✅ | `pose_detection_config.dart`, `motion_analyzer.dart` |
| LandmarkType Enum (33 Landmarks) | ✅ | `landmark_type.dart` |
| BodyJoint Enum (semantische Gelenke) | ✅ | `body_joint.dart` |
| Equatable für Domain Models | ✅ | `joint_angle.dart`, `velocity.dart`, `range_of_motion.dart` |
| Error Handling mit Enum Codes | ✅ | `pose_detection_errors.dart` |
| OneEuroFilter Smoothing | ✅ | `one_euro_filter.dart`, `pose_smoother.dart` |
| RingBuffer für FPS | ✅ | `ring_buffer.dart`, `pose_detection_bloc.dart` |
| AngleCalculator mit BodyJoint | ✅ | `angle_calculator.dart` |

---

## 7. Nächste Schritte / Offene Punkte

- [ ] Konkrete Use Cases / Features planen
- [ ] UI für Motion Feedback
- [ ] Persistenz für ROM-Daten
- [ ] Unit Tests für Domain Layer

---

## 8. Wichtige Code-Referenzen

| Konzept | Datei:Zeile |
|---------|-------------|
| BLoC Frame Processing | `pose_detection_bloc.dart:110-123` |
| Smoothing Integration | `pose_detection_bloc.dart:180-190` |
| Angle Calculation | `angle_calculator.dart:86-157` |
| Velocity Tracking | `velocity_tracker.dart:40-80` |
| ROM Update | `range_of_motion.dart:104-123` |
| DI Setup | `service_locator.dart:14-74` |
| Config Factory | `pose_detection_config.dart:50-90` |

---

## 9. Build Status

```bash
flutter analyze  # ✅ No issues found
```

**Letzter erfolgreicher Build**: 2026-02-03
