# Quick Start Guide - Pose Engine Core

## Installation & Setup

### 1. Dependencies
All dependencies are already configured in `pubspec.yaml`:
```yaml
dependencies:
  flutter_bloc: ^9.1.1      # State management
  camera: ^0.11.3           # Camera access
  google_mlkit_pose_detection: ^0.14.0  # ML Kit pose detection
```

### 2. Build & Run
```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Or build APK
flutter build apk --debug
```

---

## User Journey

### Step 1: Dashboard
<img src="docs/dashboard_mockup.png" alt="Dashboard" width="300" />

- App opens to clean dashboard
- Shows "Pose Engine Core" header
- Displays last session stats (if available)
- Three info cards explain features
- **Action**: Tap "Start New Capture" button

### Step 2: Capture Session
<img src="docs/capture_mockup.png" alt="Capture" width="300" />

- Fullscreen camera activates
- Cyan skeletal overlay appears on detected person
- Top bar shows:
  - Timer (MM:SS)
  - Frames processed
  - Poses captured
- Bottom controls:
  - **"Show Data"**: Opens raw landmark table
  - **"STOP"**: Ends session

### Step 3: Raw Data View (Optional)
<img src="docs/rawdata_mockup.png" alt="Raw Data" width="300" />

- Draggable bottom sheet
- Scrollable table with 33 rows
- Columns: #, Landmark Name, X, Y, Z, Confidence %
- Color-coded confidence (green = high, orange = medium)
- **Action**: Tap "Hide Data" to collapse

### Step 4: Back to Dashboard
- After stopping, returns to dashboard
- "Last Session" card now shows:
  - Duration
  - Total frames processed
  - Total poses captured

---

## Code Examples

### Accessing Pose Data

```dart
// From BLoC state
BlocBuilder<PoseDetectionBloc, PoseDetectionState>(
  builder: (context, state) {
    if (state is Detecting) {
      final currentPose = state.currentPose;  // Current frame's pose
      final allPoses = state.session.capturedPoses;  // All captured poses

      if (currentPose != null) {
        // Access specific landmarks
        final nose = currentPose.landmarks[PoseLandmarkType.nose];
        final leftKnee = currentPose.landmarks[PoseLandmarkType.leftKnee];

        print('Nose: (${nose?.x}, ${nose?.y}, ${nose?.z}) - ${nose?.likelihood}');
      }
    }
    return Container();
  },
)
```

### Creating a Custom Analyzer

```dart
// Example: Simple squat detector
class SimpleSquatAnalyzer {
  int repCount = 0;
  bool isDown = false;

  void analyzePose(Pose pose) {
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (leftKnee == null || leftHip == null || leftAnkle == null) return;

    // Simple threshold-based detection
    final kneeY = leftKnee.y;
    final hipY = leftHip.y;

    if (!isDown && kneeY > hipY + 50) {  // Going down
      isDown = true;
    } else if (isDown && kneeY < hipY + 20) {  // Standing up
      isDown = false;
      repCount++;
      print('Rep completed! Total: $repCount');
    }
  }
}

// Usage in CapturePage
final analyzer = SimpleSquatAnalyzer();

BlocListener<PoseDetectionBloc, PoseDetectionState>(
  listener: (context, state) {
    if (state is Detecting && state.currentPose != null) {
      analyzer.analyzePose(state.currentPose!);
    }
  },
  child: ...,
)
```

### Exporting Session Data

```dart
// Convert PoseSession to JSON
Map<String, dynamic> sessionToJson(PoseSession session) {
  return {
    'startTime': session.startTime.toIso8601String(),
    'endTime': session.endTime?.toIso8601String(),
    'duration': session.duration.inSeconds,
    'totalFrames': session.totalFramesProcessed,
    'poses': session.capturedPoses.map((pose) => {
      'landmarks': pose.landmarks.entries.map((entry) => {
        'type': entry.key.name,
        'x': entry.value.x,
        'y': entry.value.y,
        'z': entry.value.z,
        'likelihood': entry.value.likelihood,
      }).toList(),
    }).toList(),
  };
}

// Usage
if (state is SessionSummary) {
  final json = sessionToJson(state.session);
  final jsonString = jsonEncode(json);

  // Save to file, send to API, etc.
  File('session_data.json').writeAsString(jsonString);
}
```

---

## Customization Guide

### 1. Changing Colors

**Dashboard Theme:**
```dart
// lib/main.dart
theme: ThemeData.dark().copyWith(
  scaffoldBackgroundColor: const Color(0xFF0A0E21),  // Dark blue
  primaryColor: Colors.cyan,  // Change to your brand color
),
```

**Skeletal Overlay:**
```dart
// lib/presentation/widgets/pose_painter.dart
final Paint landmarkPaint = Paint()
  ..color = Colors.cyan  // Change landmark color
  ..strokeWidth = 5;

final Paint linePaint = Paint()
  ..color = Colors.cyan  // Change skeleton line color
  ..strokeWidth = 3;
```

### 2. Adding Custom Stats

**In DashboardPage:**
```dart
// Add to _buildLastSessionCard()
_buildStatColumn('Avg FPS', '${session.totalFramesProcessed / session.duration.inSeconds}'),
```

**In CapturePage:**
```dart
// Add to _buildTopBar()
Text('FPS: ${(state.session.totalFramesProcessed / state.session.duration.inSeconds).toStringAsFixed(1)}'),
```

### 3. Filtering Landmarks

**Show only upper body:**
```dart
// In pose_painter.dart
final upperBodyLandmarks = [
  PoseLandmarkType.nose,
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftElbow,
  PoseLandmarkType.rightElbow,
  // ... etc
];

for (final type in upperBodyLandmarks) {
  final landmark = pose.landmarks[type];
  if (landmark != null) {
    // Draw only these landmarks
  }
}
```

---

## Integration Patterns

### Pattern 1: Real-time Analysis
Process each pose as it arrives:

```dart
// In custom widget/page
BlocListener<PoseDetectionBloc, PoseDetectionState>(
  listener: (context, state) {
    if (state is Detecting && state.currentPose != null) {
      // Your real-time analysis
      myAnalyzer.process(state.currentPose!);
    }
  },
)
```

### Pattern 2: Batch Analysis
Analyze all poses after session ends:

```dart
// In custom widget/page
BlocListener<PoseDetectionBloc, PoseDetectionState>(
  listener: (context, state) {
    if (state is SessionSummary) {
      // Batch analysis
      final allPoses = state.session.capturedPoses;
      for (final pose in allPoses) {
        myAnalyzer.process(pose);
      }
      final results = myAnalyzer.getResults();
    }
  },
)
```

### Pattern 3: Custom Dashboard Widget
Create a new page that uses the core:

```dart
class CustomAnalysisPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PoseDetectionBloc(
        cameraService: CameraService(),
        poseDetectionService: PoseDetectionService(),
      )..add(InitializeEvent()),
      child: YourCustomUI(),
    );
  }
}
```

---

## Troubleshooting

### Camera Not Initializing
**Error**: "Failed to initialize camera"

**Solutions**:
1. Check camera permissions in `AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   ```
2. Grant camera permission in device settings
3. Try restarting the app

### No Pose Detected
**Issue**: Skeletal overlay not appearing

**Solutions**:
1. Ensure good lighting
2. Stand fully in frame (head to feet visible)
3. Face camera directly
4. Check ML Kit model is downloaded (automatic on first run)

### Low Performance
**Issue**: Laggy camera preview or pose detection

**Solutions**:
1. Reduce camera resolution in `camera_service.dart`:
   ```dart
   ResolutionPreset.low  // Instead of .medium
   ```
2. Skip frames in `pose_detection_bloc.dart`:
   ```dart
   if (!_isProcessingFrame && frameCount % 2 == 0) {  // Process every 2nd frame
     add(ProcessFrameEvent(...));
   }
   ```

---

## File Locations Reference

| Feature | File Path |
|---------|-----------|
| App entry | `lib/main.dart` |
| Dashboard UI | `lib/presentation/pages/dashboard_page.dart` |
| Capture UI | `lib/presentation/pages/capture_page.dart` |
| Raw data table | `lib/presentation/widgets/raw_data_view.dart` |
| Skeletal overlay | `lib/presentation/widgets/pose_painter.dart` |
| State management | `lib/presentation/bloc/pose_detection_bloc.dart` |
| Camera logic | `lib/core/services/camera_service.dart` |
| ML Kit logic | `lib/core/services/pose_detection_service.dart` |
| Data model | `lib/domain/models/pose_session.dart` |

---

## Next Steps

1. **Test the app**: Run on device and try a capture session
2. **Review documentation**: Read `POSE_ENGINE_CORE.md` for architecture details
3. **Build an analyzer**: Create custom analysis logic (squat, yoga, etc.)
4. **Customize UI**: Adjust colors, add stats, modify layouts
5. **Export data**: Implement JSON/CSV export for training/analysis

**Happy coding! 🚀**
