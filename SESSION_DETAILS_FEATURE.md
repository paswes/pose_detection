# Session Details Feature

## Overview
Added ability to view detailed landmark data from previously captured sessions.

## New Components

### 1. SessionDetailsPage
**Location**: `lib/presentation/pages/session_details_page.dart`

**Features**:
- **Session Summary Header**: Shows completion status, duration, frames, and poses count
- **Pose Navigator**: Browse through all captured poses with prev/next buttons
- **Progress Indicator**: Visual progress bar showing current pose position
- **Raw Data View**: Full landmark table (same as live capture) for each pose
- **Responsive UI**: Handles sessions with no poses gracefully

### 2. Updated DashboardPage
**Location**: `lib/presentation/pages/dashboard_page.dart`

**Changes**:
- Last Session card is now **clickable**
- Shows "View Details →" indicator on the card
- Navigates to SessionDetailsPage when tapped

---

## User Flow

```
Dashboard
└─> [Tap "Last Session" card]
    └─> Session Details Page
        ├─> Session summary (duration, frames, poses)
        ├─> Pose navigator (1 of X)
        │   ├─> [Previous] button
        │   ├─> Progress bar
        │   └─> [Next] button
        └─> Raw data table
            └─> All 33 landmarks with X, Y, Z, Likelihood
```

---

## UI Screenshots (Description)

### Dashboard - Last Session Card
```
┌─────────────────────────────────────┐
│ 📜 Last Session    View Details → │
│                                     │
│  Duration    Frames    Poses        │
│    2m 15s      134       98         │
└─────────────────────────────────────┘
       ↑
   [Clickable]
```

### Session Details Page
```
┌─────────────────────────────────────┐
│ ← Session Details                   │
├─────────────────────────────────────┤
│ ✓ Session Completed                 │
│  ⏱ Duration  📹 Frames  🚶 Poses   │
│    2m 15s      134        98        │
├─────────────────────────────────────┤
│ ◀  Viewing Pose: 1 of 98  ▶        │
│     [════════░░░░░░░░░]             │
├─────────────────────────────────────┤
│ Landmark Data (33 Points)           │
│                                     │
│ #  Landmark        X    Y    Z  Conf│
│ 1  nose         250  180 -15 0.9982│
│ 2  left Eye... 235  175 -18 0.9947│
│ ...                                 │
│ [Scrollable]                        │
└─────────────────────────────────────┘
```

---

## Code Example

### Navigating to Session Details
```dart
// From anywhere with a PoseSession object
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => SessionDetailsPage(session: mySession),
  ),
);
```

### Accessing Session Data
```dart
// SessionDetailsPage automatically handles:
final poses = session.capturedPoses;  // List<Pose>
final currentPose = poses[_currentPoseIndex];  // Single Pose

// Display in RawDataView
RawDataView(pose: currentPose)
```

---

## Features in Detail

### 1. Session Summary
- **Status Badge**: "✓ Session Completed" with green checkmark
- **Stats Display**:
  - ⏱ Duration (minutes and seconds)
  - 📹 Total frames processed
  - 🚶 Total poses captured
- **Gradient Background**: Cyan gradient for visual appeal

### 2. Pose Navigator
- **Current Position**: "Viewing Pose: X of Y"
- **Navigation Buttons**:
  - `◀` Previous (disabled at first pose)
  - `▶` Next (disabled at last pose)
- **Progress Bar**: Visual indicator of position in sequence
- **Real-time Update**: Raw data table updates instantly when changing poses

### 3. Raw Data Table
- **Same as Live Capture**: Uses identical `RawDataView` widget
- **All 33 Landmarks**: Complete ML Kit pose data
- **Columns**: #, Landmark, X, Y, Z, Likelihood (4 decimals)
- **Scrollable**: Can browse all landmarks
- **Color-coded Confidence**: Green (>0.7), Orange (≤0.7)

### 4. Error Handling
- **No Poses**: Shows friendly message "No poses captured in this session"
- **Navigation Bounds**: Buttons automatically disable at list boundaries
- **Back Navigation**: AppBar back button returns to dashboard

---

## Technical Implementation

### State Management
```dart
class _SessionDetailsPageState extends State<SessionDetailsPage> {
  int _currentPoseIndex = 0;  // Track which pose is displayed

  void _goToNextPose() {
    setState(() => _currentPoseIndex++);
  }

  void _goToPreviousPose() {
    setState(() => _currentPoseIndex--);
  }
}
```

### Data Flow
```
PoseSession (from BLoC)
  └─> capturedPoses: List<Pose>
      └─> [Pose at index N]
          └─> landmarks: Map<PoseLandmarkType, PoseLandmark>
              └─> RawDataView displays 33 landmarks
```

---

## Benefits

### For Users
- **Retrospective Analysis**: Review captured poses after session ends
- **Frame-by-frame Inspection**: Navigate through each captured pose
- **Data Validation**: Verify ML Kit detection quality
- **Research**: Export/analyze specific frames

### For Developers
- **Debugging**: Inspect landmark data from past sessions
- **Quality Assurance**: Verify pose detection accuracy
- **Training Data**: Review captured data for ML improvements
- **User Support**: Investigate user-reported issues with session data

---

## Use Cases

1. **Fitness Analysis**
   - Review form across entire workout
   - Find poses with incorrect form
   - Export problematic frames for coaching

2. **Research**
   - Collect pose data samples
   - Analyze landmark precision (jitter)
   - Study confidence distributions

3. **Debugging**
   - Investigate why certain poses weren't detected
   - Check landmark confidence levels
   - Verify coordinate ranges

4. **Quality Control**
   - Ensure all 33 landmarks were captured
   - Check for missing/low-confidence landmarks
   - Validate session completeness

---

## Future Enhancements

Potential additions:

1. **Export Functionality**
   - Export session to JSON/CSV
   - Share specific poses
   - Email session report

2. **Visualization**
   - Overlay pose skeleton on each frame
   - Show motion trails across poses
   - 3D visualization of landmarks

3. **Analysis Tools**
   - Calculate angles between landmarks
   - Detect patterns across poses
   - Generate statistics (avg confidence, etc.)

4. **Filtering**
   - Show only high-confidence poses
   - Filter by landmark type
   - Search by coordinate range

5. **Comparison**
   - Compare two poses side-by-side
   - Diff between consecutive frames
   - Overlay multiple poses

---

## Testing Checklist

- [x] Code compiles without errors
- [x] Flutter analyze passes
- [ ] Dashboard shows "View Details →" on last session card
- [ ] Tapping card navigates to SessionDetailsPage
- [ ] Session summary displays correct stats
- [ ] Pose navigator shows "1 of X" correctly
- [ ] Previous/Next buttons work
- [ ] Progress bar updates when navigating
- [ ] Raw data table shows all 33 landmarks
- [ ] Likelihood values show 4 decimal places
- [ ] Back button returns to dashboard
- [ ] Handles sessions with 0 poses gracefully

---

## Summary

✅ **Added**: Session details page with pose navigation
✅ **Enhanced**: Dashboard last session card is now interactive
✅ **Reused**: RawDataView widget for consistency
✅ **UX**: Intuitive navigation with visual feedback
✅ **Code Quality**: 0 errors, clean architecture

Users can now **review captured session data** in detail, making the Pose Engine Core even more powerful for analysis and validation! 🎯
