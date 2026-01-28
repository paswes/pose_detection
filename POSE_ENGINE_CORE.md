# Pose Engine Core - Generic Pose Detection System

## Overview

The **Pose Engine Core** is a minimalist, plug-and-play pose detection foundation built with Flutter and ML Kit. It provides raw pose data (33 landmarks) without any exercise-specific logic, making it ready for custom analysis modules.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  DashboardPage                                          │    │
│  │  - Main entry point                                     │    │
│  │  - Shows last session stats                             │    │
│  │  - "Start New Capture" button                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                     │
│                            ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  CapturePage                                            │    │
│  │  - Fullscreen camera with pose overlay                  │    │
│  │  - Live session stats (duration, frames, poses)         │    │
│  │  - Toggle raw data view (33 landmarks table)            │    │
│  │  - "Stop" button to end session                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│           │                  │                  │                │
│           ▼                  ▼                  ▼                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐      │
│  │ CameraPreview│  │  PosePainter │  │  RawDataView     │      │
│  │   Widget     │  │  (All 33     │  │  (Scrollable     │      │
│  │              │  │  landmarks)  │  │   table)         │      │
│  └──────────────┘  └──────────────┘  └──────────────────┘      │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │            PoseDetectionBloc (State Manager)            │    │
│  │  Events: Initialize, StartCapture, StopCapture,         │    │
│  │          ProcessFrame, Dispose                          │    │
│  │  States: Initial, CameraReady, Detecting,               │    │
│  │          SessionSummary, Error                          │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                        DOMAIN LAYER                               │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │  PoseSession (Model)                                    │     │
│  │  - startTime, endTime, duration                         │     │
│  │  - capturedPoses: List<Pose>                            │     │
│  │  - totalFramesProcessed: int                            │     │
│  └─────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                         CORE LAYER                                │
│  ┌──────────────────────┐      ┌────────────────────────┐        │
│  │   CameraService      │      │ PoseDetectionService   │        │
│  │  - initialize()      │      │ - detectPoses()        │        │
│  │  - startImageStream()│      │ - _convertCameraImage()│        │
│  │  - stopImageStream() │      │ - dispose()            │        │
│  │  - dispose()         │      │                        │        │
│  └──────────────────────┘      └────────────────────────┘        │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │         CoordinateTranslator (Utility)                  │     │
│  │  - translatePoint(x, y, imageSize, widgetSize)          │     │
│  │    → Offset (for overlay alignment)                     │     │
│  └─────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                  EXTERNAL DEPENDENCIES                            │
│  ┌──────────────────┐  ┌──────────────────┐                      │
│  │  Camera Plugin   │  │  ML Kit Pose     │                      │
│  │  (camera)        │  │  Detection       │                      │
│  └──────────────────┘  └──────────────────┘                      │
└──────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
lib/
├── core/
│   ├── services/
│   │   ├── camera_service.dart           # Camera lifecycle management
│   │   └── pose_detection_service.dart   # ML Kit pose detection wrapper
│   └── utils/
│       └── coordinate_translator.dart    # Coordinate scaling for overlay
│
├── domain/
│   └── models/
│       └── pose_session.dart             # Session data model
│
├── presentation/
│   ├── bloc/
│   │   ├── pose_detection_bloc.dart      # Generic state management
│   │   ├── pose_detection_event.dart     # Events (Initialize, StartCapture, etc.)
│   │   └── pose_detection_state.dart     # States (CameraReady, Detecting, etc.)
│   │
│   ├── pages/
│   │   ├── dashboard_page.dart           # Main entry (Dashboard)
│   │   └── capture_page.dart             # Fullscreen capture with overlay
│   │
│   └── widgets/
│       ├── camera_preview_widget.dart    # Camera preview component
│       ├── pose_painter.dart             # Skeletal overlay (33 landmarks)
│       └── raw_data_view.dart            # Scrollable landmark table
│
└── main.dart                              # App entry point
```

---

## Key Features

### 1. **Generic Pose Detection**
- Captures all **33 ML Kit landmarks** in real-time
- No exercise-specific logic (squats, yoga, etc.)
- Pure data provider for downstream analysis

### 2. **Complete Landmark Coverage**
The `PosePainter` draws ALL 33 landmarks:
- **Face** (11 points): nose, eyes (inner/outer), ears, mouth
- **Torso** (4 points): shoulders, hips
- **Arms** (12 points): elbows, wrists, fingers (thumb, index, pinky)
- **Legs** (10 points): knees, ankles, heels, foot index

### 3. **Raw Data Access**
- Scrollable table showing X, Y, Z coordinates
- Confidence/likelihood percentage for each landmark
- Color-coded confidence indicators (green/orange)

### 4. **Session Management**
- Tracks duration, frames processed, poses captured
- Displays last session stats on dashboard
- Clean start/stop flow

---

## Data Flow

```
1. USER: Opens app
   └─> DashboardPage loads
       └─> BLoC initializes camera (InitializeEvent)

2. USER: Taps "Start New Capture"
   └─> BLoC creates PoseSession (StartCaptureEvent)
       └─> Navigate to CapturePage
       └─> Camera stream starts

3. FOR EACH FRAME:
   ProcessFrameEvent
   └─> PoseDetectionService.detectPoses()
       └─> Returns List<Pose>
       └─> BLoC updates PoseSession (add to capturedPoses[])
       └─> Emits Detecting state with current pose

4. UI UPDATES:
   Detecting state
   ├─> PosePainter draws 33 landmarks (cyan overlay)
   ├─> Stats bar shows duration, frames, poses count
   └─> (Optional) RawDataView shows landmark table

5. USER: Taps "Stop"
   └─> BLoC finalizes PoseSession (StopCaptureEvent)
       └─> Emits SessionSummary state
       └─> Navigate back to DashboardPage
       └─> Dashboard shows last session stats
```

---

## UI Breakdown

### **DashboardPage**
- **Header**: "Pose Engine Core" with icon
- **Last Session Card**: Duration, Frames, Poses count (if available)
- **Info Cards**:
  - Real-time Detection (33 landmarks)
  - Raw Data Access (X, Y, Z, confidence)
  - Plug & Play (ready for custom modules)
- **Start Button**: Gradient cyan button with glow effect

### **CapturePage**
- **Fullscreen Camera**: BoxFit.cover
- **Skeletal Overlay**: Cyan skeleton with all connections
- **Top Stats Bar**:
  - Timer (MM:SS)
  - Frames/Poses count
- **Bottom Controls**:
  - "Show/Hide Data" button (toggles raw data overlay)
  - "STOP" button (red, prominent)
- **Raw Data Overlay** (optional):
  - Draggable bottom sheet
  - Scrollable table (33 rows)
  - Columns: #, Landmark, X, Y, Z, Confidence

---

## State Management

### **Events**
| Event | Description |
|-------|-------------|
| `InitializeEvent` | Initialize camera and services |
| `StartCaptureEvent` | Begin new pose capture session |
| `StopCaptureEvent` | End current session |
| `ProcessFrameEvent` | Process single camera frame |
| `DisposeEvent` | Clean up resources |

### **States**
| State | Description |
|-------|-------------|
| `PoseDetectionInitial` | App just started |
| `CameraInitializing` | Camera is being set up |
| `CameraReady` | Ready to start capture |
| `Detecting` | Actively capturing poses |
| `SessionSummary` | Session ended with results |
| `PoseDetectionError` | Error occurred |

---

## Plug & Play Design

The core provides **raw pose data** with zero interpretation:

```dart
// Example: Custom analysis module
class SquatAnalyzer {
  void analyzePose(Pose pose) {
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    // Custom logic here...
    final kneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle);
    // ...
  }
}

class YogaPoseClassifier {
  String classifyPose(Pose pose) {
    // Custom classification logic
    // Return "Tree Pose", "Warrior II", etc.
  }
}
```

**Integration Points**:
1. **Read from `Detecting` state**: Access `currentPose` or `session.capturedPoses`
2. **Create custom analyzer**: Process `Pose` objects with your logic
3. **Build custom UI**: Display results in your own widgets

---

## Technical Highlights

### **Performance**
- Medium resolution (ResolutionPreset.medium) for balance
- Frame throttling (skip processing if previous frame not done)
- Efficient coordinate translation (cached scale calculations)

### **Robustness**
- Handles app lifecycle (pause/resume)
- Portrait orientation lock
- Camera permission handling
- Error states with retry functionality

### **Code Quality**
- **0 errors, 0 warnings** (Flutter analyze clean)
- Strict separation of concerns (Core/Domain/Presentation)
- Single responsibility per file
- Comprehensive documentation

---

## Build & Deploy

```bash
# Analyze code
flutter analyze
# ✓ No issues found!

# Build debug APK
flutter build apk --debug
# ✓ Built successfully

# Run on device
flutter run
```

---

## Future Extensions

The generic core enables easy addition of:

1. **Exercise Analyzers**
   - Squat detector (angle thresholds + state machine)
   - Push-up counter
   - Yoga pose classifier

2. **Data Export**
   - Export `PoseSession` to JSON/CSV
   - Send to backend for training

3. **Visualization**
   - 3D skeleton rendering (using Z coordinates)
   - Motion trails
   - Heatmaps

4. **Advanced Analysis**
   - Form correction feedback
   - Symmetry analysis
   - Range of motion measurements

---

## Key Differences from Original PoC

| Aspect | Original PoC | Pose Engine Core |
|--------|--------------|------------------|
| **Purpose** | Squat counting | Generic pose capture |
| **Logic** | Hardcoded squat state machine | No analysis logic |
| **UI** | Workout HUD (rep counter, feedback) | Dashboard + Raw data view |
| **Painter** | Selective landmarks (hip, knee, ankle) | All 33 landmarks |
| **Output** | Rep count, knee angle | Raw pose data + session stats |
| **Extensibility** | Squat-specific | Plug & play for any use case |

---

## Summary

The **Pose Engine Core** is a production-ready foundation for pose-based applications. It provides:

✅ **Complete landmark detection** (33 points)
✅ **Clean architecture** (Core/Domain/Presentation)
✅ **Minimal UI** (Dashboard + Capture + Raw data)
✅ **Zero analysis logic** (pure data provider)
✅ **Plug & play design** (ready for custom modules)

**Perfect for**: Fitness apps, physical therapy tools, gesture recognition, motion analysis research, and any project requiring human pose data.
