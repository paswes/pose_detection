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
├── main.dart                              # App Entry Point (→ HomePage)
├── core/                                  # Infrastructure Layer
│   ├── config/
│   │   ├── pose_detection_config.dart     # Zentrale Config (Factory Constructors)
│   │   └── landmark_schema.dart           # ML Kit Schema Definition
│   ├── di/
│   │   └── service_locator.dart           # GetIt DI Setup + Dynamic Config Updates
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
│           ├── motion_analyzer.dart       # Facade Service + MotionAnalyzerConfig
│           ├── angle_calculator.dart      # Winkelberechnungen
│           ├── velocity_tracker.dart      # Geschwindigkeits-Tracking
│           └── range_of_motion_analyzer.dart  # ROM Analyse
│
└── presentation/                          # UI Layer
    ├── theme/
    │   └── playground_theme.dart          # Theme Constants (Colors, Spacing, Styles)
    ├── bloc/
    │   ├── pose_detection_bloc.dart       # Basis-BLoC (Simple Capture)
    │   ├── pose_detection_event.dart      # BLoC Events
    │   ├── pose_detection_state.dart      # BLoC States
    │   └── playground/                    # Developer Playground BLoC
    │       ├── playground_bloc.dart       # Extended BLoC mit Motion Analysis
    │       ├── playground_event.dart      # Config Changes, Panel Toggles, Presets
    │       └── playground_state.dart      # PlaygroundState, PlaygroundMetrics
    ├── pages/
    │   ├── home_page.dart                 # Navigation Hub
    │   ├── capture_page.dart              # Simple Capture View
    │   ├── playground_page.dart           # Developer Playground
    │   └── documentation_page.dart        # Inline Developer Docs
    └── widgets/
        ├── camera_preview_widget.dart     # Kamera Preview
        ├── pose_painter.dart              # Skeleton Overlay
        └── playground/                    # Playground UI Components
            ├── playground_overlay.dart    # Main Overlay Container
            ├── top_metrics_bar.dart       # FPS, Latency, Confidence, Pose Count
            ├── config_panel/              # Left Panel - Configuration
            │   ├── config_panel.dart      # Collapsible Container
            │   ├── preset_button_row.dart # Quick Preset Switching
            │   ├── smoothing_sliders.dart # OneEuroFilter Parameters
            │   ├── confidence_sliders.dart# Confidence Thresholds
            │   └── motion_config_section.dart # Motion Analyzer Toggles
            ├── data_panel/                # Right Panel - Data Visualization
            │   ├── data_visualization_panel.dart # Collapsible Container
            │   ├── joint_angles_section.dart     # Angle Gauges Grid
            │   ├── velocities_section.dart       # Speed + Direction List
            │   └── rom_section.dart              # ROM Progress Bars
            └── visualizations/            # Reusable Visualization Widgets
                ├── angle_gauge.dart       # Semi-circular Angle Gauge
                ├── velocity_indicator.dart# Speed + Direction Arrow
                └── rom_progress_bar.dart  # Min/Max Range Bar
```

---

## 3. App Navigation

```
HomePage (Entry Point)
├── Developer Playground  → PlaygroundPage
│   ├── Real-time motion analysis
│   ├── Config presets & sliders
│   └── Performance metrics
├── Simple Capture        → CapturePage
│   ├── Skeleton overlay
│   └── Basic metrics
└── Documentation         → DocumentationPage
    ├── Configuration reference
    ├── Data model docs
    └── Usage examples
```

**Routes:**
- `/home` - HomePage
- `/playground` - PlaygroundPage
- `/capture` - CapturePage
- `/docs` - DocumentationPage

---

## 4. Schlüssel-Konzepte

### 4.1 Config System (Factory Constructors)

```dart
// lib/core/config/pose_detection_config.dart
PoseDetectionConfig.defaultConfig()    // Standard-Einstellungen
PoseDetectionConfig.smoothVisuals()    // Mehr Smoothing
PoseDetectionConfig.responsive()       // Weniger Smoothing
PoseDetectionConfig.raw()              // Kein Smoothing
PoseDetectionConfig.highPrecision()    // Strikte Confidence Filter

// lib/domain/motion/services/motion_analyzer.dart
MotionAnalyzerConfig.defaultConfig()   // Alle Features
MotionAnalyzerConfig.minimal()         // Nur Winkel
MotionAnalyzerConfig.fullAnalysis()    // Extended History
MotionAnalyzerConfig.romFocused()      // ROM Tracking
MotionAnalyzerConfig.velocityFocused() // Velocity Tracking
```

### 4.2 Semantische Enums

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
  leftElbow, rightElbow,       // Shoulder → Elbow → Wrist
  leftShoulder, rightShoulder, // Elbow → Shoulder → Hip
  leftHip, rightHip,           // Shoulder → Hip → Knee
  leftKnee, rightKnee,         // Hip → Knee → Ankle
  leftAnkle, rightAnkle,       // Knee → Ankle → Heel
  leftTorsoLean, rightTorsoLean, neckLean;

  static List<BodyJoint> get primaryJoints; // 8 wichtigste
  static List<(BodyJoint, BodyJoint)> get pairedJoints; // L/R Paare
}
```

### 4.3 Motion Analysis API

```dart
// Verwendung
final analyzer = MotionAnalyzer(config: MotionAnalyzerConfig.defaultConfig());
analyzer.startSession();

// Pro Frame
final result = analyzer.analyze(detectedPose);

// Zugriff auf Daten
result.angles['11_13_15']?.degrees           // Winkel in Grad
result.velocities[15]?.speed                 // Handgeschwindigkeit (px/s)
result.rangeOfMotion['23_25_27']?.rangeDegrees // ROM in Grad
result.isStationary                          // Body movement state

// Mit BodyJoint
final angle = angleCalculator.calculateFromBodyJoint(
  pose: pose,
  joint: BodyJoint.leftElbow,
);
```

### 4.4 OneEuroFilter (Jitter-Reduktion)

```dart
// Automatisch via PoseSmoother angewandt wenn smoothingEnabled: true
smoothingEnabled: true,           // Default: true
smoothingMinCutoff: 1.0,          // Frequenz-Cutoff (0.1-10.0)
smoothingBeta: 0.007,             // Speed Coefficient (0.0-1.0)
smoothingDerivativeCutoff: 1.0,   // Derivative Cutoff (0.1-10.0)
```

### 4.5 Error Handling

```dart
enum PoseDetectionErrorCode {
  cameraInitFailed, cameraNotInitialized, streamStartFailed,
  cameraSwitchFailed, mlKitDetectionFailed, imageConversionFailed,
  tooManyConsecutiveErrors, processingTimeout, unknown;
}

exception.isRecoverable; // bool
```

---

## 5. Developer Playground UI

### 5.1 Layout

```
┌────────────────────────────────────────────────────────────┐
│              TOP METRICS BAR (FPS, Latency, Confidence)    │
├────────────────────────────────────────────────────────────┤
│ ┌──────┐                                    ┌──────────┐   │
│ │ CFG  │      CAMERA PREVIEW                │  DATA    │   │
│ │PANEL │      + POSE OVERLAY                │  PANEL   │   │
│ │  <   │                                    │    >     │   │
│ └──────┘                                    └──────────┘   │
├────────────────────────────────────────────────────────────┤
│  [Camera]  [Config Toggle]  [Start/Stop]  [Data Toggle]    │
└────────────────────────────────────────────────────────────┘
```

### 5.2 Config Panel (Links)

- **Pose Presets**: Default, Smooth, Responsive, Raw, High Precision
- **Motion Presets**: Full, Minimal, ROM, Velocity
- **Smoothing Sliders**: minCutoff, beta, derivativeCutoff, enabled toggle
- **Confidence Sliders**: high/low/min thresholds, filter toggle
- **Motion Config**: trackAngles, trackVelocities, trackRom, use3DAngles, historyCapacity

### 5.3 Data Panel (Rechts)

- **Joint Angles Section**: Semi-circular gauges mit Confidence-Coloring
- **Velocities Section**: Speed + Direction arrows, Category badges (STILL/SLOW/MOD/FAST/V.FAST)
- **ROM Section**: Progress bars mit Min/Max markers, Category badges

### 5.4 Top Metrics Bar

| Metric | Color Coding |
|--------|--------------|
| FPS | Green ≥25, Yellow ≥15, Red <15 |
| Latency | Green <50ms, Yellow <100ms, Orange <150ms, Red ≥150ms |
| Confidence | Green >0.8, Yellow >0.5, Red ≤0.5 |
| Pose Count | Total detections |
| Dropped | Skipped frames |
| Body State | Stationary/Moving icon |

### 5.5 PlaygroundBloc Events

```dart
// Lifecycle
InitializePlaygroundEvent, StartCaptureEvent, StopCaptureEvent
SwitchCameraEvent, DisposePlaygroundEvent, ProcessFrameEvent

// Configuration
ApplyPresetEvent(ConfigPreset)    // Quick preset switch
UpdatePoseConfigEvent(config)     // Custom pose config
UpdateMotionConfigEvent(config)   // Custom motion config

// UI State
TogglePanelEvent(PanelType)       // Expand/collapse panels
SelectJointsEvent(Set<BodyJoint>) // Filter displayed joints
ToggleAllVelocitiesEvent          // Show all vs key landmarks
ResetMotionAnalysisEvent          // Clear ROM/velocity data
```

---

## 6. Data Flow Pipeline

```
CameraService.startImageStream()
    ↓ 30 FPS
PlaygroundBloc (droppable transformer)
    ↓
FrameProcessor.processFrame()
    ↓
PoseDetectionService.detectPose()  [ML Kit: 30-50ms]
    ↓
PoseSmoother.smooth()              [OneEuroFilter]
    ↓
MotionAnalyzer.analyze()           [Angles, Velocity, ROM]
    ↓
PlaygroundState Emission → UI
    ↓
TopMetricsBar + DataVisualizationPanel + ConfigPanel
```

---

## 7. Dependency Injection

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

// Dynamic Config Updates (für Playground)
updatePoseConfig(newConfig);   // Recreates PoseSmoother
updateMotionConfig(newConfig); // Recreates MotionAnalyzer
```

---

## 8. Abgeschlossene Features

| Feature | Status | Key Files |
|---------|--------|-----------|
| Factory Constructors | ✅ | `pose_detection_config.dart`, `motion_analyzer.dart` |
| LandmarkType Enum | ✅ | `landmark_type.dart` |
| BodyJoint Enum | ✅ | `body_joint.dart` |
| Equatable Models | ✅ | `joint_angle.dart`, `velocity.dart`, `range_of_motion.dart` |
| Error Handling | ✅ | `pose_detection_errors.dart` |
| OneEuroFilter | ✅ | `one_euro_filter.dart`, `pose_smoother.dart` |
| RingBuffer FPS | ✅ | `ring_buffer.dart` |
| Developer Playground UI | ✅ | `playground/` (BLoC + Widgets) |
| HomePage Navigation | ✅ | `home_page.dart` |
| Documentation Page | ✅ | `documentation_page.dart` |
| Theme System | ✅ | `playground_theme.dart` |
| Dynamic Config Updates | ✅ | `service_locator.dart` |
| Visualization Widgets | ✅ | `angle_gauge.dart`, `velocity_indicator.dart`, `rom_progress_bar.dart` |

---

## 9. Nächste Schritte / Offene Punkte

- [ ] Persistenz für ROM-Daten
- [ ] Unit Tests für Domain Layer
- [ ] Export Motion Data (JSON/CSV)
- [ ] Custom Joint Selection UI
- [ ] Landscape Layout Support

---

## 10. Wichtige Code-Referenzen

| Konzept | Datei |
|---------|-------|
| App Entry Point | `main.dart` |
| Playground BLoC | `playground_bloc.dart` |
| Motion Analysis | `motion_analyzer.dart` |
| Angle Calculation | `angle_calculator.dart` |
| Velocity Tracking | `velocity_tracker.dart` |
| ROM Analysis | `range_of_motion_analyzer.dart` |
| Pose Smoothing | `pose_smoother.dart` |
| DI Setup | `service_locator.dart` |
| Config Presets | `pose_detection_config.dart` |
| Theme Constants | `playground_theme.dart` |
| Top Metrics Bar | `top_metrics_bar.dart` |
| Data Panel | `data_visualization_panel.dart` |
| Config Panel | `config_panel.dart` |

---

## 11. Build Status

```bash
flutter analyze  # ✅ No issues found
```

**Letzter erfolgreicher Build**: 2026-02-03
