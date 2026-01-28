# Clean Architecture - Data Flow Diagram

## Layer Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              squat_detector_view.dart                  │  │
│  │  - Lifecycle management (WidgetsBindingObserver)      │  │
│  │  - BLoC provider setup                                │  │
│  │  - UI composition                                     │  │
│  └───────────────────────────────────────────────────────┘  │
│                            │                                 │
│                            ▼                                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │         PoseDetectionBloc (State Management)          │  │
│  │  Events: Initialize, StartCountdown, ProcessFrame,    │  │
│  │          CountdownTick, Reset, Dispose                │  │
│  │  States: Initial, Initializing, Ready, Countdown,     │  │
│  │          CountingActive, Error                        │  │
│  └───────────────────────────────────────────────────────┘  │
│           │                 │                 │              │
│           ▼                 ▼                 ▼              │
│  ┌───────────────┐ ┌───────────────┐ ┌──────────────────┐  │
│  │ CameraPreview │ │  PosePainter  │ │   WorkoutHud     │  │
│  │    Widget     │ │   (Overlay)   │ │ (Rep Counter &   │  │
│  │               │ │               │ │   Controls)      │  │
│  └───────────────┘ └───────────────┘ └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                       DOMAIN LAYER                           │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              SquatAnalyzer (Business Logic)           │  │
│  │  - analyzePose(Pose) → SquatAnalysisResult           │  │
│  │  - _calculateAngle() → double [LAW OF COSINES]       │  │
│  │  - _updateSquatState() → SquatAnalysisResult         │  │
│  │                                                       │  │
│  │  THRESHOLDS (PRESERVED):                             │  │
│  │    UP: 160° | DOWN: 100° | HYSTERESIS: 5°           │  │
│  │                                                       │  │
│  │  STATE MACHINE:                                       │  │
│  │    standing → goingDown → down → goingUp → standing  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                      Models                            │  │
│  │  - SquatState (enum)                                  │  │
│  │  - SquatAnalysisResult (data class)                   │  │
│  │  - FeedbackColor (enum)                               │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        CORE LAYER                            │
│  ┌──────────────────────┐      ┌────────────────────────┐   │
│  │   CameraService      │      │ PoseDetectionService   │   │
│  │  - initialize()      │      │ - detectPoses()        │   │
│  │  - startImageStream()│      │ - _convertCameraImage()│   │
│  │  - stopImageStream() │      │ - dispose()            │   │
│  │  - dispose()         │      │                        │   │
│  └──────────────────────┘      └────────────────────────┘   │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           CoordinateTranslator (Utils)                │  │
│  │  - translatePoint(x, y, imageSize, widgetSize)        │  │
│  │    → Offset                                           │  │
│  │                                                       │  │
│  │  SCALING LOGIC (PRESERVED):                          │  │
│  │    scaleX = widgetW / imageW                         │  │
│  │    scaleY = widgetH / imageH                         │  │
│  │    scale = max(scaleX, scaleY)  [BoxFit.cover]       │  │
│  │    offset = center alignment calculation             │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   EXTERNAL DEPENDENCIES                      │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │  Camera Plugin   │  │  ML Kit Pose     │                 │
│  │  (camera)        │  │  Detection       │                 │
│  └──────────────────┘  └──────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow (Rep Counting Sequence)

```
1. USER ACTION: Taps "Start" button
   └─> WorkoutHud.onStart()
       └─> Bloc.add(StartCountdownEvent())

2. COUNTDOWN: 5, 4, 3, 2, 1, GO!
   └─> Timer.periodic (1 second intervals)
       └─> Bloc.add(CountdownTickEvent(seconds))
       └─> State: CountdownActive(secondsRemaining)
       └─> After 0: _startCounting()

3. START COUNTING:
   └─> CameraService.startImageStream(onImage)
       └─> For each CameraImage frame:
           └─> Bloc.add(ProcessFrameEvent(image))

4. FRAME PROCESSING:
   ProcessFrameEvent
   └─> PoseDetectionService.detectPoses(image)
       └─> Returns List<Pose>
       └─> If pose detected:
           └─> SquatAnalyzer.analyzePose(pose)

5. SQUAT ANALYSIS:
   SquatAnalyzer.analyzePose(Pose)
   ├─> Extract landmarks: leftHip, leftKnee, leftAnkle,
   │                       rightHip, rightKnee, rightAnkle
   ├─> Check confidence (likelihood > 0.5)
   ├─> Calculate angles:
   │   ├─> leftKneeAngle = _calculateAngle(hip, knee, ankle)
   │   └─> rightKneeAngle = _calculateAngle(hip, knee, ankle)
   ├─> Average: (leftKneeAngle + rightKneeAngle) / 2
   └─> _updateSquatState(averageKneeAngle)

6. STATE MACHINE:
   _updateSquatState(kneeAngle)
   ├─> Current: standing
   │   └─> If kneeAngle < 155° (160° - 5°)
   │       └─> Transition to: goingDown
   │           └─> Feedback: "Go Down!" (orange)
   │
   ├─> Current: goingDown
   │   ├─> If kneeAngle < 100°
   │   │   └─> Transition to: down
   │   │       └─> Feedback: "Stand Up!" (red)
   │   └─> If kneeAngle > 165° (160° + 5°)
   │       └─> Transition to: standing (incomplete rep)
   │
   ├─> Current: down
   │   └─> If kneeAngle > 105° (100° + 5°)
   │       └─> Transition to: goingUp
   │           └─> Feedback: "Keep Going!" (orange)
   │
   └─> Current: goingUp
       ├─> If kneeAngle > 160°
       │   └─> Transition to: standing
       │       └─> ✅ REP COMPLETED!
       │       └─> repCount++
       │       └─> Feedback: "Rep Complete!" (green)
       └─> If kneeAngle < 95° (100° - 5°)
           └─> Transition to: down (went back down)

7. STATE UPDATE:
   Bloc emits: CountingActive(
     repCount: updated count,
     kneeAngle: current angle,
     squatState: new state,
     feedbackText: "...",
     feedbackColor: ...,
     currentPose: pose,
     imageSize: Size(...)
   )

8. UI UPDATE:
   BlocBuilder rebuilds UI with new state
   ├─> WorkoutHud shows updated rep count
   ├─> PosePainter draws skeletal overlay
   │   └─> Uses CoordinateTranslator for coordinate mapping
   └─> Debug info shows knee angle and state

9. REPEAT: Steps 3-8 for each frame until user taps "Reset"
```

## Critical Code Mappings

### Original PoC → New Architecture

| Original Location | New Location | Preserved Logic |
|-------------------|--------------|-----------------|
| Lines 101-172 | `CameraService` | Camera initialization, stream control |
| Lines 178-249 | `PoseDetectionService` | Image conversion, pose detection |
| Lines 255-313 | `SquatAnalyzer.analyzePose()` | Landmark extraction, angle calculation |
| Lines 315-341 | `SquatAnalyzer._calculateAngle()` | **Law of Cosines** (EXACT) |
| Lines 343-420 | `SquatAnalyzer._updateSquatState()` | **State machine** (EXACT) |
| Lines 444-484 | `PoseDetectionBloc` (countdown/counting) | **5-second timer** (EXACT) |
| Lines 818-945 | `PosePainter` | Skeletal overlay rendering |
| Lines 915-939 | `CoordinateTranslator` | **Coordinate scaling** (EXACT) |
| Lines 595-791 | `WorkoutHud` | UI components (rep counter, buttons) |

## Dependencies Between Layers

```
Presentation → Domain → Core
     ↓           ↓        ↓
   BLoC      Analyzer  Services
     ↓           ↓        ↓
  Widgets    Models    Utils
```

**Dependency Rule**: Outer layers depend on inner layers, never the reverse.
- Presentation can import Domain and Core
- Domain can import Core
- Core has no dependencies on other layers
